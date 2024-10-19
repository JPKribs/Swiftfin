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
    struct RemoteControlSection: View {
        @Binding
        var tempPolicy: UserPolicy

        @Environment(\.isEnabled)
        var isEnabled

        var body: some View {
            Section("Remote control") {
                Toggle("Control other users", isOn: Binding(
                    get: { tempPolicy.enableRemoteControlOfOtherUsers ?? false },
                    set: { tempPolicy.enableRemoteControlOfOtherUsers = $0 }
                ))
                .disabled(!isEnabled)

                Toggle("Control shared devices", isOn: Binding(
                    get: { tempPolicy.enableSharedDeviceControl ?? false },
                    set: { tempPolicy.enableSharedDeviceControl = $0 }
                ))
                .disabled(!isEnabled)
            }
        }
    }
}
