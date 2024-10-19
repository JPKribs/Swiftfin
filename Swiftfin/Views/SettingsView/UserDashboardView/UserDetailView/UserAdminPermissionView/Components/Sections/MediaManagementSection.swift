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
    struct MediaManagementSection: View {
        @Binding
        var tempPolicy: UserPolicy

        @Environment(\.isEnabled)
        var isEnabled

        var body: some View {
            Section("Media management") {
                // TODO: Figure out what this does???
                Toggle("Allow public sharing", isOn: Binding(
                    get: { tempPolicy.enablePublicSharing ?? false },
                    set: { tempPolicy.enablePublicSharing = $0 }
                ))
                .disabled(!isEnabled)

                Toggle("Allow media downloads", isOn: Binding(
                    get: { tempPolicy.enableContentDownloading ?? false },
                    set: { tempPolicy.enableContentDownloading = $0 }
                ))
                .disabled(!isEnabled)

                Toggle("Allow media deletion from all Libraries", isOn: Binding(
                    get: { tempPolicy.enableContentDeletion ?? false },
                    set: { tempPolicy.enableContentDeletion = $0 }
                ))
                .disabled(!isEnabled)

                // TODO: Add the 'Allow media deletion from' Libaries
            }
        }
    }
}
