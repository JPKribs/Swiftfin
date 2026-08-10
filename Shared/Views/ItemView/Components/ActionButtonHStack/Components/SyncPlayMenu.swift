//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import FactoryKit
import JellyfinAPI
import SwiftUI

extension ItemView {

    struct SyncPlayMenu<LabelContent: View>: View {

        @InjectedObject(\.userSessionManager)
        private var userSessionManager

        @ViewBuilder
        var label: (Bool) -> LabelContent

        private var syncPlayAccess: SyncPlayUserAccessType? {
            userSessionManager.currentSession?.user.data.policy?.syncPlayAccess
        }

        var body: some View {
            if let syncPlayAccess,
               syncPlayAccess != .none,
               let session = userSessionManager.currentSession
            {
                GroupMenu(
                    manager: session.syncPlayManager,
                    userSession: session,
                    canCreateGroups: syncPlayAccess == .createAndJoinGroups,
                    label: label
                )
            }
        }
    }
}

extension ItemView.SyncPlayMenu {

    private struct GroupMenu: View {

        @ObservedObject
        var manager: SyncPlayManager

        @Router
        private var router

        let userSession: UserSession
        let canCreateGroups: Bool
        let label: (Bool) -> LabelContent

        var body: some View {
            Menu {
                if let currentGroup = manager.currentGroup {
                    Section(currentGroup.groupName ?? L10n.syncPlay) {
                        if manager.playingItemID != nil {
                            Button(L10n.watchWithGroup, systemImage: "play.circle") {
                                playGroupItem()
                            }
                        }

                        Button(L10n.settings, systemImage: "gearshape") {
                            router.route(to: .syncPlaySettings)
                        }

                        Button(L10n.leaveGroup, systemImage: "rectangle.portrait.and.arrow.right") {
                            manager.leaveGroup()
                        }
                    }
                } else {
                    if canCreateGroups {
                        Button(L10n.newGroup, systemImage: "plus") {
                            manager.createGroup()
                        }
                    }

                    if manager.groups.isNotEmpty {
                        Section(L10n.joinGroups) {
                            ForEach(manager.groups, id: \.self) { group in
                                Button(group.groupName ?? L10n.syncPlay, systemImage: "person.2") {
                                    guard let id = group.groupID else { return }

                                    manager.joinGroup(id: id)
                                }
                            }
                        }
                    }
                }
            } label: {
                label(manager.currentGroup != nil)
            }
            .foregroundStyle(.primary, .secondary)
            .symbolRenderingMode(.monochrome)
            .onAppear {
                guard manager.currentGroup == nil else { return }

                manager.refreshGroups()
            }
        }

        private func playGroupItem() {
            guard let itemID = manager.playingItemID else { return }

            Task { @MainActor in
                let item = try await BaseItemDto(id: itemID).getFullItem(userSession: userSession)
                let position = manager.groupPosition

                guard let provider = item.getPlaybackItemProvider(userSession: userSession)?
                    .modifyingItem({ item in
                        if item.userData == nil {
                            item.userData = UserItemDataDto(key: "")
                        }
                        item.userData?.playbackPositionTicks = position.ticks
                    })
                else { return }

                router.route(to: .videoPlayer(provider: provider))
            }
        }
    }
}
