//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2024 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

extension UserAdminDetailView.UserAdminPermissionsView {
    struct ManagementSection: View {
        @Binding
        var tempPolicy: UserPolicy

        @Environment(\.isEnabled)
        var isEnabled

        @ViewBuilder
        var body: some View {
            Section("Management Permissions") {
                Toggle("Adminstrator", isOn: Binding(
                    get: { tempPolicy.isAdministrator ?? false },
                    set: { tempPolicy.isAdministrator = $0 }
                ))
                .disabled(!isEnabled)

                // TODO: SDK Update Required!
                // TODO: Add the 'Allow user to manage collections'
                // TODO: Add the 'Allow user to edit subtitles'
            }
        }
    }
}
