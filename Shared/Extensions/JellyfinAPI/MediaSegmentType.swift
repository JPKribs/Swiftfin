//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI

extension MediaSegmentType: Displayable, SystemImageable {

    var displayTitle: String {
        switch self {
        case .commercial:
            L10n.commercial
        case .intro:
            L10n.intro
        case .outro:
            L10n.outro
        case .preview:
            L10n.preview
        case .recap:
            L10n.recap
        case .unknown:
            L10n.unknown
        }
    }

    var systemImage: String {
        switch self {
        case .commercial:
            "megaphone"
        case .intro:
            "forward.frame"
        case .outro, .unknown:
            "forward.end"
        case .preview:
            "film.stack"
        case .recap:
            "clock.arrow.circlepath"
        }
    }
}
