//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2024 Jellyfin & Jellyfin Contributors
//

import CollectionVGrid
import Defaults
import JellyfinAPI
import SwiftUI

struct UserAdminDetailView: View {

    @EnvironmentObject
    private var router: SettingsCoordinator.Router

    @ObservedObject
    var observer: UserAdminObserver

    var body: some View {
        List {
            Section("Profile") {
                SettingsView.UserProfileRow(user: observer.user) /* {
                     // TODO: Profile
                 } */
                if let invalidLoginAttemptCount = observer.user.policy?.invalidLoginAttemptCount,
                   invalidLoginAttemptCount > 0
                {
                    TextPairView(
                        "Invalid Logins",
                        value: Text(invalidLoginAttemptCount.description)
                    )
                }
            }

            Section(L10n.advanced) {

                // TODO: Access
                // TODO: Parental Controls

                ChevronButton("Devices") // L10n.devices)
                    .onSelect {
                        if let userId = observer.user.id {

                            router.route(to: \.userDevices, userId)
                        }
                    }

                ChevronButton(L10n.password)
                    .onSelect {
                        router.route(to: \.userPassword, observer)
                    }

                ChevronButton("Permissions") // L10n.password)
                    .onSelect {
                        router.route(to: \.userPermissions, observer)
                    }
            }
        }
        .navigationTitle(L10n.user)
    }
}
