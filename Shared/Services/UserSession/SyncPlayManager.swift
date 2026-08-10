//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import FactoryKit
import Foundation
import JellyfinAPI
import Logging

@MainActor
@Stateful
final class SyncPlayManager: ObservableObject {

    @CasePathable
    enum Action {
        case error
        case refreshGroups
        case createGroup
        case joinGroup(id: String)
        case leaveGroup

        case pause
        case unpause
        case seek(to: Duration)
        case stop

        var transition: Transition {
            switch self {
            case .error, .pause, .unpause, .seek, .stop:
                .none
            case .refreshGroups:
                .background(.refreshing)
            case .createGroup, .joinGroup, .leaveGroup:
                .background(.updating)
            }
        }
    }

    enum BackgroundState {
        case refreshing
        case updating
    }

    enum Event {
        case command(SendCommand)
        case didJoinGroup(GroupInfoDto)
        case didLeaveGroup
    }

    enum State {
        case initial
    }

    private struct GroupPlayback {
        var isPlaying = false
        var positionTicks = 0
        var at = Date.now
        var playlistItemID: String?

        func position(at serverTime: Date) -> Duration {
            let base = Duration.ticks(positionTicks)
            guard isPlaying else { return base }

            return base + .seconds(serverTime.timeIntervalSince(at))
        }
    }

    private enum Readiness {
        case buffering
        case ready
    }

    @Published
    private(set) var currentGroup: GroupInfoDto?

    @Published
    private(set) var groups: [GroupInfoDto] = []

    @Published
    private(set) var playingItemID: String?

    var groupPosition: Duration {
        groupPlayback.position(at: timeSync.serverTime(from: .now))
    }

    private let emptyPlaylistItemID = "00000000000000000000000000000000"
    private let tickInterval = Duration.milliseconds(500)
    private let bufferingTickThreshold = 4

    private let logger = Logger.swiftfin()
    private let timeSync = SyncPlayTimeSync()

    private weak var userSession: UserSession?
    private weak var mediaPlayerManager: MediaPlayerManager?
    private var cancellables = Set<AnyCancellable>()
    private var playerCancellables = Set<AnyCancellable>()
    private var commandTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?
    private var requestTask: Task<Void, Never>?
    private var groupPlayback = GroupPlayback()
    private var reportedReadiness: Readiness?
    private var lastCommand: SendCommand?
    private var bufferingTicks = 0
    private var lastSeconds: Duration?
    private var seekSuppressedUntil = Date.distantPast
    private var statusSuppressedUntil = Date.distantPast
    private var isCorrecting = false

    private var isBuffering: Bool {
        mediaPlayerManager?.proxy?.isBuffering.value ?? false
    }

    // the local player can be on something other than what the group is watching
    private var isPlayingGroupItem: Bool {
        guard let playingItemID, let mediaPlayerManager else { return true }

        return mediaPlayerManager.item.id == playingItemID
    }

    private var reportedPosition: Duration {
        // until an applied seek settles, the player still reads its old position, and reporting
        // that convinces the server we are out of sync and needs another correction
        if let mediaPlayerManager,
           mediaPlayerManager.playbackItem != nil,
           isPlayingGroupItem,
           Date.now >= seekSuppressedUntil
        {
            return mediaPlayerManager.seconds
        }

        return groupPlayback.position(at: timeSync.serverTime(from: .now))
    }

    // MARK: - Group

    @Function(\Action.Cases.refreshGroups)
    private func _refreshGroups() async throws {
        guard let userSession else { return }

        let response = try await userSession.client.send(Paths.syncPlayGetGroups)

        groups = response.value
    }

    @Function(\Action.Cases.createGroup)
    private func _createGroup() async throws {
        guard let userSession else { return }

        let parameters = NewGroupRequestDto(groupName: L10n.syncPlayGroupName(userSession.user.username).localizedCapitalized)
        let request = Paths.syncPlayCreateGroup(parameters)
        let response = try await userSession.client.send(request)

        setCurrentGroup(response.value)
    }

    @Function(\Action.Cases.joinGroup)
    private func _joinGroup(_ id: String) async throws {
        guard let userSession else { return }

        let request = Paths.syncPlayJoinGroup(JoinGroupRequestDto(groupID: id))
        try await userSession.client.send(request)

        guard currentGroup == nil else { return }

        // joining is only acknowledged over the socket, so fill in the group directly
        let response = try await userSession.client.send(Paths.syncPlayGetGroup(id: id))

        setCurrentGroup(response.value)
    }

    @Function(\Action.Cases.leaveGroup)
    private func _leaveGroup() async throws {
        guard let userSession else { return }

        try await userSession.client.send(Paths.syncPlayLeaveGroup)

        setCurrentGroup(nil)
    }

    // MARK: - Playback

    @Function(\Action.Cases.pause)
    private func _pause() async throws {
        enqueue { try await $0.client.send(Paths.syncPlayPause) }
    }

    @Function(\Action.Cases.unpause)
    private func _unpause() async throws {
        enqueue { try await $0.client.send(Paths.syncPlayUnpause) }
    }

    @Function(\Action.Cases.seek)
    private func _seek(_ position: Duration) async throws {
        let request = Paths.syncPlaySeek(SeekRequestDto(positionTicks: position.ticks))

        enqueue { try await $0.client.send(request) }
    }

    @Function(\Action.Cases.stop)
    private func _stop() async throws {
        enqueue { try await $0.client.send(Paths.syncPlayStop) }
    }

    // a single ordered chain: a seek and an unpause fired together must arrive in that order,
    // and a readiness report must never overtake the request it answers
    private func enqueue(_ send: @escaping @MainActor (UserSession) async throws -> Void) {
        guard let userSession else { return }

        let previous = requestTask

        requestTask = Task { @MainActor in
            if let previous {
                await previous.value
            }

            try? await send(userSession)
        }
    }

    // MARK: - Socket

    private func onReceive(groupUpdate: GroupUpdate) {
        switch groupUpdate {
        case let .syncPlayGroupJoinedUpdate(update):
            guard let group = update.data else { return }

            setCurrentGroup(group)
        case .syncPlayGroupLeftUpdate, .syncPlayNotInGroupUpdate:
            setCurrentGroup(nil)
        case let .syncPlayUserJoinedUpdate(update):
            guard let participant = update.data else { return }

            updateParticipants { participants in
                participants.appending(participant, if: !participants.contains(participant))
            }
        case let .syncPlayUserLeftUpdate(update):
            guard let participant = update.data else { return }

            updateParticipants { participants in
                participants.filter { $0 != participant }
            }
        case let .syncPlayGroupDoesNotExistUpdate(update):
            logger.warning("SyncPlay group does not exist", metadata: ["group": .string(update.groupID ?? "")])

            setCurrentGroup(nil)
        case let .syncPlayLibraryAccessDeniedUpdate(update):
            logger.warning("SyncPlay library access denied", metadata: ["group": .string(update.groupID ?? "")])

            setCurrentGroup(nil)
        case let .syncPlayPlayQueueUpdate(update):
            guard let queue = update.data else { return }

            onReceive(queueUpdate: queue)
        case let .syncPlayStateUpdate(update):
            guard let state = update.data?.state else { return }

            onReceive(groupState: state)
        }
    }

    // a waiting group holds playback for everyone until every member reports in
    private func onReceive(groupState: GroupStateType) {
        guard groupState == .waiting else { return }

        reportedReadiness = nil
    }

    private func onReceive(queueUpdate: PlayQueueUpdate) {
        let index = queueUpdate.playingItemIndex ?? 0
        let playing = queueUpdate.playlist?[safe: index]

        groupPlayback.playlistItemID = playing?.playlistItemID
        groupPlayback.isPlaying = queueUpdate.isPlaying ?? false
        groupPlayback.positionTicks = queueUpdate.startPositionTicks ?? 0
        groupPlayback.at = queueUpdate.lastUpdate ?? timeSync.serverTime(from: .now)
        playingItemID = playing?.itemID

        lastCommand = nil
        reportedReadiness = nil
    }

    private func onReceive(command: SendCommand) {
        guard let currentGroup, command.groupID == currentGroup.groupID else { return }

        // an idle group reports an empty playlist item, so its commands reference nothing to act on
        guard let playlistItemID = command.playlistItemID, playlistItemID != emptyPlaylistItemID else { return }

        // a settled group answers every readiness report with the command it is already on, so acting on
        // a repeat would report again and ping-pong with the server forever
        guard command.command != lastCommand?.command
            || command.when != lastCommand?.when
            || command.positionTicks != lastCommand?.positionTicks
        else { return }

        lastCommand = command

        // the server resends a seek to any member whose reported item was stale, so trust the command over the queue
        groupPlayback.playlistItemID = playlistItemID

        logger.trace(
            "SyncPlay command",
            metadata: [
                "command": .string(command.command?.rawValue ?? "none"),
                "positionTicks": .stringConvertible(command.positionTicks ?? 0),
            ]
        )

        apply(command)

        events.send(.command(command))
    }

    private func apply(_ command: SendCommand) {
        groupPlayback.positionTicks = command.positionTicks ?? 0
        groupPlayback.at = command.when ?? timeSync.serverTime(from: .now)
        groupPlayback.isPlaying = command.command == .unpause

        // a member with no player, or one on unrelated content, must still acknowledge so the group never waits on it
        guard let mediaPlayerManager, isPlayingGroupItem else {
            reportedReadiness = nil
            return
        }

        let position = Duration.ticks(command.positionTicks ?? 0)

        switch command.command {
        case .unpause:
            perform(at: command.when) { [weak self] in
                guard let self else { return }

                seekIfNeeded(to: position + elapsed(since: command.when))
                mediaPlayerManager.setPlaybackRequestStatus(status: .playing)
            }
        case .pause, .seek:
            perform(at: command.when) { [weak self] in
                guard let self else { return }

                mediaPlayerManager.setPlaybackRequestStatus(status: .paused)
                seekIfNeeded(to: position)
            }
        case .stop:
            commandTask?.cancel()
            commandTask = nil
            mediaPlayerManager.stop()
        case .none:
            return
        }
    }

    // a late command means the group has already played past the position it carries
    private func elapsed(since when: Date?) -> Duration {
        guard let when else { return .zero }

        return .seconds(max(0, Date.now.timeIntervalSince(timeSync.localTime(from: when))))
    }

    // seeking forces a rebuffer, which reports us as buffering and holds the whole group
    private func seekIfNeeded(to position: Duration) {
        guard let mediaPlayerManager else { return }

        let threshold = Duration.milliseconds(Defaults[.SyncPlay.skipToSyncMinimumDelay])

        guard abs(position - mediaPlayerManager.seconds) >= threshold else { return }

        applySeek(to: position)
    }

    // every seek the group asks of us goes through here so it is never mistaken for a local one
    private func applySeek(to position: Duration) {
        guard let proxy = mediaPlayerManager?.proxy else { return }

        seekSuppressedUntil = .now.addingTimeInterval(1)
        proxy.setSeconds(position)

        lastSeconds = position
    }

    private func perform(at when: Date?, _ action: @escaping @MainActor () -> Void) {
        commandTask?.cancel()

        let offset = Duration.milliseconds(Defaults[.SyncPlay.extraTimeOffset])
        let target = when.map { timeSync.localTime(from: $0) } ?? .now
        let delay = target.timeIntervalSinceNow - offset.seconds

        guard delay > 0 else {
            commandTask = nil
            statusSuppressedUntil = .now.addingTimeInterval(2)
            action()
            reportedReadiness = nil
            return
        }

        commandTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }

            statusSuppressedUntil = .now.addingTimeInterval(2)
            action()

            commandTask = nil
            reportedReadiness = nil
        }
    }

    // MARK: - Sync Correction

    // the proxy is attached after the manager is published and is not observable, so readiness is polled
    private func startSyncing() {
        syncTask?.cancel()

        syncTask = Task { @MainActor [weak self] in
            var tick = 0

            while !Task.isCancelled {
                try? await Task.sleep(for: tickInterval)
                guard !Task.isCancelled, let self else { return }

                tick += 1

                onTick()

                if tick.isMultiple(of: 2) {
                    correctDrift()
                }
            }
        }
    }

    private func onTick() {
        guard let mediaPlayerManager, mediaPlayerManager.playbackItem != nil else {
            lastSeconds = nil
            reconcileReadiness(isStalled: false)
            return
        }

        let current = mediaPlayerManager.seconds
        let previous = lastSeconds
        lastSeconds = current

        // VLC never clears its buffering flag while paused, so the flag alone cannot be trusted:
        // a real stall is a player that should be advancing and is not
        let isStalled = mediaPlayerManager.playbackRequestStatus == .playing
            && isBuffering
            && current == previous

        reconcileReadiness(isStalled: isStalled)
    }

    private func correctDrift() {
        guard Defaults[.SyncPlay.enableSyncCorrection],
              !isCorrecting,
              !isBuffering,
              isPlayingGroupItem,
              groupPlayback.isPlaying,
              commandTask == nil,
              Date.now >= seekSuppressedUntil,
              let mediaPlayerManager,
              mediaPlayerManager.playbackRequestStatus == .playing,
              let proxy = mediaPlayerManager.proxy
        else { return }

        let expected = groupPlayback.position(at: timeSync.serverTime(from: .now))
        let drift = expected - mediaPlayerManager.seconds
        let driftMilliseconds = abs(drift).seconds * 1000

        let speedMinimum = Double(Defaults[.SyncPlay.speedToSyncMinimumDelay])
        let speedMaximum = Double(Defaults[.SyncPlay.speedToSyncMaximumDelay])
        let skipMinimum = Double(Defaults[.SyncPlay.skipToSyncMinimumDelay])
        let speedDuration = Duration.milliseconds(Defaults[.SyncPlay.speedToSyncDuration])

        if Defaults[.SyncPlay.enableSpeedToSync],
           driftMilliseconds >= speedMinimum,
           driftMilliseconds < speedMaximum
        {
            speedToSync(drift: drift, over: speedDuration, proxy: proxy, rate: mediaPlayerManager.rate)
        } else if Defaults[.SyncPlay.enableSkipToSync], driftMilliseconds >= skipMinimum {
            applySeek(to: expected)
        }
    }

    private func speedToSync(
        drift: Duration,
        over duration: Duration,
        proxy: any MediaPlayerProxy,
        rate: Float
    ) {
        let corrected = Float(1 + drift.seconds / duration.seconds)
            .clamped(to: 0.25 ... 4.0)

        isCorrecting = true
        proxy.setRate(rate * corrected)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)

            proxy.setRate(rate)
            self?.isCorrecting = false
        }
    }

    // MARK: - Reporting

    // only sent on a change, never in reply to a command: the server answers a report with a command
    private func reconcileReadiness(isStalled: Bool) {
        // a pending command re-reports once it applies, and reporting before then carries the
        // position the command is about to correct
        guard currentGroup != nil, groupPlayback.playlistItemID != nil, commandTask == nil else { return }

        bufferingTicks = isStalled ? bufferingTicks + 1 : 0

        // a report of buffering pauses the entire group, and players rebuffer briefly all the time,
        // so only a sustained stall is worth holding everyone for
        let readiness: Readiness = bufferingTicks >= bufferingTickThreshold ? .buffering : .ready

        guard readiness != reportedReadiness else { return }

        reportedReadiness = readiness
        send(readiness)
    }

    // the server discards a report whose item does not match the group's, so these must never race
    private func send(_ readiness: Readiness) {
        guard let playlistItemID = groupPlayback.playlistItemID else { return }

        let info = PlaybackQueueStateInfo(
            isPlaying: mediaPlayerManager?.playbackRequestStatus == .playing,
            playlistItemID: playlistItemID,
            positionTicks: reportedPosition.ticks,
            when: timeSync.serverTime(from: .now)
        )

        let request = switch readiness {
        case .buffering:
            Paths.syncPlayBuffering(info)
        case .ready:
            Paths.syncPlayReady(info)
        }

        logger.trace(
            "SyncPlay report",
            metadata: [
                "readiness": .string("\(readiness)"),
                "positionTicks": .stringConvertible(info.positionTicks ?? 0),
                "isPlaying": .stringConvertible(info.isPlaying ?? false),
            ]
        )

        enqueue { try await $0.client.send(request) }
    }

    private func setCurrentGroup(_ group: GroupInfoDto?) {
        let previous = currentGroup
        currentGroup = group

        if let group, previous == nil {
            if let userSession {
                timeSync.start(userSession: userSession)
            }

            // group updates can be missed over the socket, so seed the model from the join itself:
            // an unseeded model mistakes the user's first pause for an echo and swallows it
            groupPlayback.isPlaying = group.state == .playing

            startSyncing()

            if group.state == .idle, let item = mediaPlayerManager?.playbackItem?.baseItem {
                setNewQueue(for: item)
            }

            events.send(.didJoinGroup(group))
        } else if group == nil, previous != nil {
            stopSyncing()
            events.send(.didLeaveGroup)
        }
    }

    private func stopSyncing() {
        commandTask?.cancel()
        syncTask?.cancel()
        requestTask?.cancel()
        commandTask = nil
        syncTask = nil
        requestTask = nil

        timeSync.stop()

        groupPlayback = GroupPlayback()
        playingItemID = nil
        reportedReadiness = nil
        lastCommand = nil
        bufferingTicks = 0
        lastSeconds = nil
        seekSuppressedUntil = .distantPast
        statusSuppressedUntil = .distantPast
        isCorrecting = false
    }

    // MARK: - Local Playback

    private func observe(mediaPlayerManager: MediaPlayerManager?) {
        self.mediaPlayerManager = mediaPlayerManager
        playerCancellables.removeAll()

        guard let mediaPlayerManager else { return }

        mediaPlayerManager.$playbackRequestStatus
            .dropFirst()
            .sink { [weak self] status in
                Task { @MainActor in
                    self?.onLocal(status: status)
                }
            }
            .store(in: &playerCancellables)

        mediaPlayerManager.didSeek
            .sink { [weak self] seconds in
                Task { @MainActor in
                    self?.onLocal(seek: seconds)
                }
            }
            .store(in: &playerCancellables)

        mediaPlayerManager.$playbackItem
            .compactMap { $0?.baseItem }
            .removeDuplicates { $0.id == $1.id }
            .sink { [weak self] item in
                Task { @MainActor in
                    // a new item resets the position, which is not a seek; re-reporting readiness
                    // prompts the server to send a corrective command for the group's state
                    self?.lastSeconds = nil
                    self?.reportedReadiness = nil
                    self?.setNewQueue(for: item)
                }
            }
            .store(in: &playerCancellables)
    }

    // starting the group's own item is joining in, while any other item deliberately replaces
    // what the group is watching
    private func setNewQueue(for item: BaseItemDto) {
        guard currentGroup != nil, let id = item.id else { return }
        guard id != playingItemID else { return }

        let position = mediaPlayerManager?.seconds ?? item.startSeconds ?? .zero

        let request = Paths.syncPlaySetNewQueue(
            PlayRequestDto(
                playingItemPosition: 0,
                playingQueue: [id],
                startPositionTicks: position.ticks
            )
        )

        reportedReadiness = nil

        logger.trace("SyncPlay new queue", metadata: ["itemID": .string(id)])

        enqueue { try await $0.client.send(request) }
    }

    // the group answers with its own seek command, so the local jump is only a head start
    private func onLocal(seek seconds: Duration) {
        guard currentGroup != nil,
              isPlayingGroupItem,
              mediaPlayerManager?.isStopping == false,
              Date.now >= seekSuppressedUntil
        else { return }

        // a scrub emits continuously while dragging, and each request is answered with a command
        seekSuppressedUntil = .now.addingTimeInterval(1)

        logger.trace("SyncPlay local seek", metadata: ["positionTicks": .stringConvertible(seconds.ticks)])

        seek(to: seconds)
    }

    // a change that already matches the group is an echo of an applied command
    private func onLocal(status: MediaPlayerManager.PlaybackRequestStatus) {
        // closing the player pauses the proxy on its way out, which would pause the whole group
        guard currentGroup != nil, mediaPlayerManager?.isStopping == false, isPlayingGroupItem else { return }

        // the player restates its status while settling an applied command, which is not intent
        guard Date.now >= statusSuppressedUntil else { return }

        let isPlaying = status == .playing
        guard isPlaying != groupPlayback.isPlaying else { return }

        logger.trace("SyncPlay local status", metadata: ["isPlaying": .stringConvertible(isPlaying)])

        if isPlaying {
            unpause()
        } else {
            pause()
        }
    }

    private func updateParticipants(_ transform: ([String]) -> [String]) {
        guard var group = currentGroup else { return }

        group.participants = transform(group.participants ?? [])

        currentGroup = group
    }
}

extension SyncPlayManager: UserSessionService {

    func willStart(userSession: UserSession) async {
        self.userSession = userSession
    }

    func didStart(userSession: UserSession) {
        userSession.serverSocketManager
            .syncPlayGroupUpdates
            .sink { [weak self] update in
                Task { @MainActor in
                    self?.onReceive(groupUpdate: update)
                }
            }
            .store(in: &cancellables)

        userSession.serverSocketManager
            .syncPlayCommands
            .sink { [weak self] command in
                Task { @MainActor in
                    self?.onReceive(command: command)
                }
            }
            .store(in: &cancellables)

        // the session recreates on foreground, and the publisher does not replay a player already running
        observe(mediaPlayerManager: Container.shared.userSessionManager().mediaPlayerManager)

        Container.shared.mediaPlayerManagerPublisher()
            .sink { [weak self] manager in
                Task { @MainActor in
                    self?.observe(mediaPlayerManager: manager)
                }
            }
            .store(in: &cancellables)
    }

    func willStop(userSession: UserSession) {
        cancel()
        cancellables.removeAll()
        playerCancellables.removeAll()

        stopSyncing()

        currentGroup = nil
        groups.removeAll()
    }
}
