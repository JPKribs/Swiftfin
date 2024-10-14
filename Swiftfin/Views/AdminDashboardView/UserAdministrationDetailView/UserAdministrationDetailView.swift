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

struct UserAdministrationDetailView: View {

    @EnvironmentObject
    private var router: AdminDashboardCoordinator.Router

    @ObservedObject
    var observer: UserAdministrationObserver

    var body: some View {
        List {
            ChevronButton(L10n.profile)
                .onSelect {
                    router.route(to: \.userPolicy, observer)
                }
            ChevronButton(L10n.password)
                .onSelect {
                    router.route(to: \.userPassword, observer)
                }
        }
        .navigationTitle(L10n.user)
    }
}
