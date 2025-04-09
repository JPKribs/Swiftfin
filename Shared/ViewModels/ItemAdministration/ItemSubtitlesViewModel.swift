//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Combine
import Foundation
import JellyfinAPI

final class ItemSubtitlesViewModel: ViewModel, Stateful, Eventful {

    // MARK: - Events

    enum Event: Equatable {
        case deleted
        case uploaded
        case error(JellyfinAPIError)
    }

    // MARK: - Action

    enum Action: Equatable {
        case search(language: String, isPerfectMatch: Bool? = nil)
        case set(subtitleID: String)
        case upload(UploadSubtitleDto)
        case delete(index: Int)
    }

    // MARK: - Background State

    enum BackgroundState: Hashable {
        case updating
    }

    // MARK: - State

    enum State: Hashable {
        case initial
        case error(JellyfinAPIError)
        case searching
    }

    @Published
    var state: State = .initial
    @Published
    var backgroundStates: Set<BackgroundState> = []

    // MARK: - Published Item

    @Published
    var item: BaseItemDto
    @Published
    var internalSubtitles: [MediaStream]
    @Published
    var externalSubtitles: [MediaStream]
    @Published
    var searchResults: [RemoteSubtitleInfo] = []

    // MARK: Event Variables

    private var subtitleTask: AnyCancellable?
    private var searchTask: AnyCancellable?
    private var searchQuery: CurrentValueSubject<(language: String, isPerfectMatch: Bool?), Never> = .init(("", nil))
    private var eventSubject: PassthroughSubject<Event, Never> = .init()

    var events: AnyPublisher<Event, Never> {
        eventSubject
            .eraseToAnyPublisher()
        // Causes issues with the Deleted Event unless this is removed
        // .receive(on: RunLoop.main)
    }

    // MARK: - Initializer

    init(item: BaseItemDto) {
        self.item = item
        self.internalSubtitles = []
        self.externalSubtitles = []

        super.init()

        // Extract subtitle streams from all media sources
        for mediaSource in item.mediaSources ?? [] {
            if let streams = mediaSource.subtitleStreams {
                self.internalSubtitles.append(contentsOf: streams.filter { $0.isExternal == false })
                self.externalSubtitles.append(contentsOf: streams.filter { $0.isExternal == true })
            }
        }

        // Setup debounced search
        searchQuery
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] searchParams in
                guard let self, searchParams.language.isNotEmpty else { return }

                self.searchTask?.cancel()
                self.search(language: searchParams.language, isPerfectMatch: searchParams.isPerfectMatch)
            }
            .store(in: &cancellables)
    }

    // MARK: - Respond

    func respond(to action: Action) -> State {
        switch action {
        case let .delete(index):
            subtitleTask?.cancel()

            subtitleTask = Task { [weak self] in
                guard let self = self else { return }
                do {
                    try await self.deleteSubtitle(index: index)
                    try await self.refreshItem()

                    await MainActor.run {
                        self.state = .initial
                        self.eventSubject.send(.deleted)
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self.state = .error(JellyfinAPIError(error.localizedDescription))
                        self.eventSubject.send(.error(JellyfinAPIError(error.localizedDescription)))
                    }
                }
            }
            .asAnyCancellable()

            return .initial

        case let .upload(subtitle):
            subtitleTask?.cancel()

            subtitleTask = Task { [weak self] in
                guard let self = self else { return }
                do {
                    try await self.uploadSubtitle(subtitle: subtitle)

                    /// Wait a tenth second to ensure that the upload completes
                    try await Task.sleep(nanoseconds: 100_000_000)

                    try await self.refreshItem()

                    await MainActor.run {
                        self.state = .initial
                        self.eventSubject.send(.uploaded)
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self.state = .error(JellyfinAPIError(error.localizedDescription))
                        self.eventSubject.send(.error(JellyfinAPIError(error.localizedDescription)))
                    }
                }
            }
            .asAnyCancellable()

            return .initial

        case let .search(language, isPerfectMatch):
            if language.isEmpty {
                searchTask?.cancel()
                searchTask = nil
                searchQuery.send((language: language, isPerfectMatch: isPerfectMatch))
                return .initial
            } else {
                searchQuery.send((language: language, isPerfectMatch: isPerfectMatch))
                return .searching
            }

        case let .set(subtitleID):
            subtitleTask?.cancel()

            subtitleTask = Task { [weak self] in
                guard let self = self else { return }
                do {
                    try await self.setSubtitle(subtitleID: subtitleID)
                    try await self.refreshItem()

                    await MainActor.run {
                        self.state = .initial
                        self.eventSubject.send(.uploaded)
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self.state = .error(JellyfinAPIError(error.localizedDescription))
                        self.eventSubject.send(.error(JellyfinAPIError(error.localizedDescription)))
                    }
                }
            }
            .asAnyCancellable()

            return .initial
        }
    }

    // MARK: - Search

    private func search(language: String, isPerfectMatch: Bool?) {
        searchTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                let results = try await self.searchSubtitles(
                    language: language,
                    isPerfectMatch: isPerfectMatch
                )

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.searchResults = results
                    self.state = .initial
                }
            } catch {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.state = .error(JellyfinAPIError(error.localizedDescription))
                    self.eventSubject.send(.error(JellyfinAPIError(error.localizedDescription)))
                }
            }
        }
        .asAnyCancellable()
    }

    // MARK: - Delete Subtitle

    private func deleteSubtitle(index: Int) async throws {
        guard let itemID = item.id else {
            throw JellyfinAPIError(L10n.unknownError)
        }

        let request = Paths.deleteSubtitle(itemID: itemID, index: index)
        _ = try await userSession.client.send(request)

        await MainActor.run {
            self.externalSubtitles.removeAll(where: { $0.index == index })
        }
    }

    // MARK: - Search for Subtitles

    private func searchSubtitles(language: String, isPerfectMatch: Bool? = nil) async throws -> [RemoteSubtitleInfo] {
        guard let itemID = item.id else {
            throw JellyfinAPIError(L10n.unknownError)
        }

        let request = Paths.searchRemoteSubtitles(
            itemID: itemID,
            language: language,
            isPerfectMatch: isPerfectMatch
        )
        let results = try await userSession.client.send(request)

        return results.value
    }

    // MARK: - Set Remote Subtitles

    private func setSubtitle(subtitleID: String) async throws {
        guard let itemID = item.id else {
            throw JellyfinAPIError(L10n.unknownError)
        }

        let request = Paths.downloadRemoteSubtitles(itemID: itemID, subtitleID: subtitleID)
        _ = try await userSession.client.send(request)
    }

    // MARK: - Subtitle Upload Logic

    private func uploadSubtitle(subtitle: UploadSubtitleDto) async throws {
        guard let itemID = item.id else {
            throw JellyfinAPIError(L10n.unknownError)
        }

        let request = Paths.uploadSubtitle(itemID: itemID, subtitle)
        _ = try await userSession.client.send(request)
    }

    // MARK: - Refresh Item

    private func refreshItem() async throws {
        guard let itemID = item.id else { return }

        await MainActor.run {
            _ = backgroundStates.insert(.updating)
        }

        let request = Paths.getItem(
            itemID: itemID,
            userID: userSession.user.id
        )

        let response = try await userSession.client.send(request)

        await MainActor.run {
            self.item = response.value
            self.internalSubtitles = []
            self.externalSubtitles = []

            // Extract subtitle streams from all media sources
            for mediaSource in item.mediaSources ?? [] {
                if let streams = mediaSource.subtitleStreams {
                    self.internalSubtitles.append(contentsOf: streams.filter { $0.isExternal == false })
                    self.externalSubtitles.append(contentsOf: streams.filter { $0.isExternal == true })
                }
            }

            _ = backgroundStates.remove(.updating)
            Notifications[.itemMetadataDidChange].post(item)
        }
    }
}
