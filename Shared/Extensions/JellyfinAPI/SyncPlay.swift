//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2024 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI

/// Enum SyncPlayUserAccessType.
extension SyncPlayUserAccessType: Displayable {

    var displayTitle: String {
        switch self {
        case .createAndJoinGroups:
            "Create & Join Groups"
        case .joinGroups:
            "Join Groups"
        case .none:
            L10n.disabled
        }
    }
}
