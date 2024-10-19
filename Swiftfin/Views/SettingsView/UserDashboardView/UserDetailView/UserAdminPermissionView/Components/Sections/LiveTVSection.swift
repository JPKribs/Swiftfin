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
    struct LiveTVSection: View {
        @Binding
        var tempPolicy: UserPolicy

        @Environment(\.isEnabled)
        var isEnabled

        @ViewBuilder
        var body: some View {
            Section("Live TV") {
                Toggle("Live TV access", isOn: Binding(
                    get: { tempPolicy.enableLiveTvAccess ?? false },
                    set: { tempPolicy.enableLiveTvAccess = $0 }
                ))
                .disabled(!isEnabled)

                Toggle("Live TV recording management", isOn: Binding(
                    get: { tempPolicy.enableLiveTvManagement ?? false },
                    set: { tempPolicy.enableLiveTvManagement = $0 }
                ))
                .disabled(!isEnabled)
            }
        }
    }
}
