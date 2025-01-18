//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Defaults
import Factory
import Foundation
import JellyfinAPI

extension StoredValues.Keys {

    enum Admin {

        /// Enable this user to edit Media Items
        static var enableItemEditing: Key<Bool> {
            CurrentUserKey(
                "enableItemEditing",
                domain: "enableItemEditing",
                default: false
            )
        }

        /// Enable this user to delete Media Items & Collections
        static var enableItemDeletion: Key<Bool> {
            CurrentUserKey(
                "enableItemDeletion",
                domain: "enableItemDeletion",
                default: false
            )
        }

        /// Enable this user to edit Collections
        static var enableCollectionManagement: Key<Bool> {
            CurrentUserKey(
                "enableCollectionManagement",
                domain: "enableCollectionManagement",
                default: false
            )
        }
    }
}
