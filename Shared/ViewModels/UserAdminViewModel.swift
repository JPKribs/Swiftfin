//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2024 Jellyfin & Jellyfin Contributors
//

import Combine
import Foundation
import JellyfinAPI
import OrderedCollections
import SwiftUI

final class UserAdminViewModel: ViewModel, Stateful {

    // MARK: - Action

    enum Action: Equatable {
        case getUsers
        case getUserByID(String)
    }

    // MARK: - BackgroundState

    enum BackgroundState: Hashable {
        case gettingUsers
        case gettingUserByID
    }

    // MARK: - State

    enum State: Hashable {
        case content
        case error(JellyfinAPIError)
        case initial
    }

    @Published
    final var user: UserDto? = nil
    @Published
    final var users: OrderedDictionary<String, BindingBox<UserDto?>> = [:]
    @Published
    final var state: State = .initial
    @Published
    final var backgroundStates: OrderedSet<BackgroundState> = []

    private var userTask: AnyCancellable?

    // MARK: - Respond to Action

    func respond(to action: Action) -> State {
        switch action {
        case .getUsers:
            userTask?.cancel()

            backgroundStates.append(.gettingUsers)

            userTask = Task { [weak self] in
                do {
                    try await self?.loadUsers()
                    await MainActor.run {
                        self?.state = .content
                    }
                } catch {
                    guard let self else { return }
                    await MainActor.run {
                        self.state = .error(.init(error.localizedDescription))
                    }
                }

                await MainActor.run {
                    self?.backgroundStates.remove(.gettingUsers)
                }
            }
            .asAnyCancellable()

            return state

        case let .getUserByID(userID):
            userTask?.cancel()

            backgroundStates.append(.gettingUserByID)

            userTask = Task { [weak self] in
                do {
                    try await self?.loadUserByID(userID: userID)
                    await MainActor.run {
                        self?.state = .content
                    }
                } catch {
                    guard let self else { return }
                    await MainActor.run {
                        self.state = .error(.init(error.localizedDescription))
                    }
                }

                await MainActor.run {
                    self?.backgroundStates.remove(.gettingUserByID)
                }
            }
            .asAnyCancellable()

            return state
        }
    }

    // MARK: - Load Users

    private func loadUsers() async throws {
        let request = Paths.getUsers()
        let response = try await userSession.client.send(request)

        await MainActor.run {
            for user in response.value {
                guard let id = user.id else { continue }

                if let existingUser = self.users[id] {
                    existingUser.value = user
                } else {
                    self.users[id] = BindingBox<UserDto?>(
                        source: .init(get: { user }, set: { _ in })
                    )
                }
            }

            self.users.sort { x, y in
                let user0 = x.value.value
                let user1 = y.value.value
                return (user0?.name ?? "") < (user1?.name ?? "")
            }
        }
    }

    // MARK: - Load User by ID

    private func loadUserByID(userID: String) async throws {
        let request = Paths.getUserByID(userID: userID)
        let response = try await userSession.client.send(request)

        await MainActor.run {
            guard let id = response.value.id else { return }

            self.user = response.value
        }
    }
}
