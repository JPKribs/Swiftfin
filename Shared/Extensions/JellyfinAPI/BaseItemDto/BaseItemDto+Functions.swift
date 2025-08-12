//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Factory
import Get
import JellyfinAPI

extension BaseItemDto {

    private var userSession: UserSession? {
        @Injected(\.currentUserSession)
        var userSession

        return userSession
    }

    mutating func refresh() async throws {

        guard let itemID = id, let userSession else {
            return
        }
        let request = Paths.getItem(itemID: itemID, userID: userSession.user.id)
        let response = try await userSession.client.send(request)
        self = response.value
    }

    mutating func refreshUserData() async throws {

        guard let itemID = id, let userSession else {
            return
        }
        let request = Paths.getItemUserData(itemID: itemID, userID: userSession.user.id)
        let response = try await userSession.client.send(request)
        userData = response.value
    }

    // mutating func toggleIsPlayed() async throws {
    func toggleIsPlayed() async throws {

        guard let itemID = id, let userSession else {
            return
        }

        if userData?.isPlayed == true {
            let request = Paths.markUnplayedItem(itemID: itemID, userID: userSession.user.id)
            let response = try await userSession.client.send(request)

            // userData = response.value
        } else {
            let request = Paths.markPlayedItem(itemID: itemID, userID: userSession.user.id)
            let response = try await userSession.client.send(request)

            // userData = response.value
        }

        Notifications[.itemShouldRefreshMetadata].post(itemID)
    }

    // mutating func toggleIsFavorite() async throws {
    func toggleIsFavorite() async throws {

        guard let itemID = id, let userSession else {
            return
        }

        if userData?.isFavorite == true {
            let request = Paths.unmarkFavoriteItem(itemID: itemID, userID: userSession.user.id)
            let response = try await userSession.client.send(request)

            // userData = response.value
        } else {
            let request = Paths.markFavoriteItem(itemID: itemID, userID: userSession.user.id)
            let response = try await userSession.client.send(request)

            // userData = response.value
        }

        Notifications[.itemShouldRefreshMetadata].post(itemID)
    }
}
