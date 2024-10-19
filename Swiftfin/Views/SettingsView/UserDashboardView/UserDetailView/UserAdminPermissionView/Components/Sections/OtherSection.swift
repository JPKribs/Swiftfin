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
    struct OtherSection: View {
        @Binding
        var tempPolicy: UserPolicy

        @Environment(\.isEnabled)
        var isEnabled

        var body: some View {
            Section("Other") {
                Toggle("Hide user from login screen", isOn: Binding(
                    get: { tempPolicy.isHidden ?? false },
                    set: { tempPolicy.isHidden = $0 }
                ))
                .disabled(!isEnabled)
            }
        }
    }
}
