//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI

extension PackageInfo: @retroactive Identifiable {

    /// Plugin ID drops the hyphen in URLs
    public var id: String? {
        guid?.uppercased().replacing("-", with: "")
    }

    var pluginCategory: PluginCategory? {
        category.map { PluginCategory(rawValue: $0) ?? .other }
    }
}
