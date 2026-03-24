//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import CoreStore
import Factory
import Get
import JellyfinAPI
import OrderedCollections

final class HomeViewModel: ViewModel, Stateful {

    // MARK: Action

    enum Action: Equatable {
        case backgroundRefresh
        case error(ErrorMessage)
        case setIsPlayed(Bool, BaseItemDto)
        case refresh
    }

    // MARK: BackgroundState

    enum BackgroundState: Hashable {
        case refresh
    }

    // MARK: State

    enum State: Hashable {
        case content
        case error(ErrorMessage)
        case initial
        case refreshing
    }

    @Published
    private(set) var libraries: [LatestInLibraryViewModel] = []
    @Published
    var resumeItems: OrderedSet<BaseItemDto> = []

    @Published
    var backgroundStates: Set<BackgroundState> = []
    @Published
    var state: State = .initial

    // TODO: replace with views checking what notifications were
    //       posted since last disappear
    @Published
    var notificationsReceived: NotificationSet = .init()

    private var backgroundRefreshTask: AnyCancellable?
    private var refreshTask: AnyCancellable?

    var nextUpViewModel: NextUpLibraryViewModel = .init()
    var recentlyAddedViewModel: RecentlyAddedLibraryViewModel = .init()

    override init() {
        super.init()

        Notifications[.itemMetadataDidChange]
            .publisher
            .sink { _ in
                // Necessary because when this notification is posted, even with asyncAfter,
                // the view will cause layout issues since it will redraw while in landscape.
                // TODO: look for better solution
                DispatchQueue.main.async {
                    self.notificationsReceived.insert(.itemMetadataDidChange)
                }
            }
            .store(in: &cancellables)
    }

    func respond(to action: Action) -> State {
        switch action {
        case .backgroundRefresh:

            backgroundRefreshTask?.cancel()
            backgroundStates.insert(.refresh)

            backgroundRefreshTask = Task { [weak self] in
                do {
                    self?.nextUpViewModel.send(.refresh)
                    self?.recentlyAddedViewModel.send(.refresh)

                    let resumeItems = try await self?.getResumeItems() ?? []

                    guard !Task.isCancelled else { return }

                    await MainActor.run {
                        guard let self else { return }
                        self.resumeItems.elements = resumeItems
                        self.backgroundStates.remove(.refresh)
                    }

                    #if os(tvOS)
                    self?.storeTopShelfData(resumeItems: resumeItems)
                    #endif
                } catch is CancellationError {
                    // cancelled
                } catch {
                    guard !Task.isCancelled else { return }

                    await MainActor.run {
                        guard let self else { return }
                        self.backgroundStates.remove(.refresh)
                        self.send(.error(.init(error.localizedDescription)))
                    }
                }
            }
            .asAnyCancellable()

            return state
        case let .error(error):
            return .error(error)
        case let .setIsPlayed(isPlayed, item): ()
            Task {
                try await setIsPlayed(isPlayed, for: item)

                self.send(.backgroundRefresh)
            }
            .store(in: &cancellables)

            return state
        case .refresh:
            backgroundRefreshTask?.cancel()
            refreshTask?.cancel()

            refreshTask = Task { [weak self] in
                do {
                    try await self?.refresh()

                    guard !Task.isCancelled else { return }

                    await MainActor.run {
                        guard let self else { return }
                        self.state = .content
                    }
                } catch is CancellationError {
                    // cancelled
                } catch {
                    guard !Task.isCancelled else { return }

                    await MainActor.run {
                        guard let self else { return }
                        self.send(.error(.init(error.localizedDescription)))
                    }
                }
            }
            .asAnyCancellable()

            return .refreshing
        }
    }

    private func refresh() async throws {

        await nextUpViewModel.send(.refresh)
        await recentlyAddedViewModel.send(.refresh)

        let resumeItems = try await getResumeItems()
        let libraries = try await getLibraries()

        for library in libraries {
            await library.send(.refresh)
        }

        await MainActor.run {
            self.resumeItems.elements = resumeItems
            self.libraries = libraries
        }

        #if os(tvOS)
        storeTopShelfData(resumeItems: resumeItems)
        #endif
    }

    private func getResumeItems() async throws -> [BaseItemDto] {
        var parameters = Paths.GetResumeItemsParameters()
        parameters.userID = userSession.user.id
        parameters.enableUserData = true
        parameters.fields = .MinimumFields
        parameters.mediaTypes = [.video]
        parameters.limit = 20

        let request = Paths.getResumeItems(parameters: parameters)
        let response = try await userSession.client.send(request)

        return response.value.items ?? []
    }

    private func getLibraries() async throws -> [LatestInLibraryViewModel] {

        let parameters = Paths.GetUserViewsParameters(userID: userSession.user.id)
        let userViewsPath = Paths.getUserViews(parameters: parameters)
        async let userViews = userSession.client.send(userViewsPath)

        async let excludedLibraryIDs = getExcludedLibraries()

        return try await (userViews.value.items ?? [])
            .intersecting(
                [
                    .homevideos,
                    .movies,
                    .musicvideos,
                    .tvshows,
                ],
                using: \.collectionType
            )
            .subtracting(excludedLibraryIDs, using: \.id)
            .map { LatestInLibraryViewModel(parent: $0) }
    }

    // TODO: use the more updated server/user data when implemented
    private func getExcludedLibraries() async throws -> [String] {
        let currentUserPath = Paths.getCurrentUser
        let response = try await userSession.client.send(currentUserPath)

        return response.value.configuration?.latestItemsExcludes ?? []
    }

    private func setIsPlayed(_ isPlayed: Bool, for item: BaseItemDto) async throws {
        let request: Request<UserItemDataDto> = if isPlayed {
            Paths.markPlayedItem(
                itemID: item.id!,
                userID: userSession.user.id
            )
        } else {
            Paths.markUnplayedItem(
                itemID: item.id!,
                userID: userSession.user.id
            )
        }

        _ = try await userSession.client.send(request)
    }

    #if os(tvOS)
    private func storeTopShelfData(resumeItems: [BaseItemDto]) {
        guard let defaults = UserDefaults(suiteName: "group.org.jellyfin.swiftfin") else { return }

        let serverURL = userSession.server.currentURL.absoluteString.trimmingCharacters(in: ["/"])
        let accessToken = userSession.user.accessToken

        defaults.set(serverURL, forKey: "topShelfServerURL")
        defaults.set(topShelfDicts(from: resumeItems, serverURL: serverURL, accessToken: accessToken), forKey: "topShelfResumeItems")
        defaults.set(
            topShelfDicts(from: Array(nextUpViewModel.elements.prefix(10)), serverURL: serverURL, accessToken: accessToken),
            forKey: "topShelfNextUpItems"
        )
        defaults.set(
            topShelfDicts(from: Array(recentlyAddedViewModel.elements.prefix(10)), serverURL: serverURL, accessToken: accessToken),
            forKey: "topShelfRecentlyAddedItems"
        )
    }

    private func topShelfDicts(
        from items: [BaseItemDto],
        serverURL: String,
        accessToken: String
    ) -> [[String: String]] {
        items.prefix(10).compactMap { item in
            guard let id = item.id else { return [:] }
            var dict: [String: String] = [
                "id": id,
                "name": item.name ?? "",
            ]
            if let imageURL = item.portraitImageSources().first?.url {
                dict["imageURL"] = imageURL.absoluteString
            }
            if let positionTicks = item.userData?.playbackPositionTicks {
                dict["playbackPositionTicks"] = String(positionTicks)
            }
            if let runTimeTicks = item.runTimeTicks {
                dict["runTimeTicks"] = String(runTimeTicks)
            }
            return dict
        }
    }
    #endif
}
