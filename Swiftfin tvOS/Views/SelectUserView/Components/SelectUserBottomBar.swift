//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import OrderedCollections
import SwiftUI

extension SelectUserView {

    struct SelectUserBottomBar: View {

        // MARK: - State & Environment Objects

        @Router
        private var router

        @Binding
        private var isEditing: Bool

        @Binding
        private var serverSelection: SelectUserServerSelection

        // MARK: - Variables

        private let areUsersSelected: Bool
        private let hasUsers: Bool
        private let selectedServer: ServerState?
        private let servers: OrderedSet<ServerState>

        private let onDelete: () -> Void
        private let toggleAllUsersSelected: () -> Void

        // MARK: - Initializer

        init(
            isEditing: Binding<Bool>,
            serverSelection: Binding<SelectUserServerSelection>,
            selectedServer: ServerState?,
            servers: OrderedSet<ServerState>,
            areUsersSelected: Bool,
            hasUsers: Bool,
            onDelete: @escaping () -> Void,
            toggleAllUsersSelected: @escaping () -> Void
        ) {
            self._isEditing = isEditing
            self._serverSelection = serverSelection
            self.areUsersSelected = areUsersSelected
            self.hasUsers = hasUsers
            self.selectedServer = selectedServer
            self.servers = servers
            self.onDelete = onDelete
            self.toggleAllUsersSelected = toggleAllUsersSelected
        }

        // MARK: - Advanced Menu

        @ViewBuilder
        private var advancedMenu: some View {
            Menu {
                Button(L10n.editUsers, systemImage: "person.crop.circle") {
                    isEditing.toggle()
                }

                Divider()

                Button(L10n.advanced, systemImage: "gearshape.fill") {
                    router.route(to: .appSettings)
                }
            } label: {
                Label(L10n.advanced, systemImage: "gearshape.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .labelStyle(.iconOnly)
                    .frame(width: 50, height: 50)
            }
        }

        // MARK: - Content View

        @ViewBuilder
        private var contentView: some View {
            HStack(alignment: .top, spacing: 20) {
                if isEditing {
                    Button(role: .destructive, action: onDelete) {
                        Text(L10n.delete)
                            .font(.body.weight(.semibold))
                            .frame(width: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(!areUsersSelected)

                    Button(action: toggleAllUsersSelected) {
                        Text(areUsersSelected ? L10n.removeAll : L10n.selectAll)
                            .foregroundStyle(Color.primary)
                            .font(.body.weight(.semibold))
                            .frame(width: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button {
                        isEditing = false
                    } label: {
                        Text(L10n.cancel)
                            .foregroundStyle(Color.primary)
                            .font(.body.weight(.semibold))
                            .frame(width: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                } else {
                    AddUserBottomButton(
                        selectedServer: selectedServer,
                        servers: servers
                    ) { server in
                        router.route(to: .userSignIn(server: server))
                    }
                    .hidden(!hasUsers)

                    ServerSelectionMenu(
                        selection: $serverSelection,
                        selectedServer: selectedServer,
                        servers: servers
                    )

                    advancedMenu
                }
            }
            .frame(height: 50)
        }

        // MARK: - Body

        var body: some View {
            // `Menu` with custom label has some weird additional
            // frame/padding that differs from default label style
            AlternateLayoutView(alignment: .top) {
                Color.clear
                    .frame(height: 100)
            } content: {
                contentView
            }
        }
    }
}
