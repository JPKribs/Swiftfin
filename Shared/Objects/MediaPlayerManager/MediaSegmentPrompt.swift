//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI

enum MediaSegmentPrompt: Displayable, Hashable, SystemImageable {

    case nextEpisode
    case segment(MediaSegmentDto)

    var displayTitle: String {
        switch self {
        case .nextEpisode:
            L10n.nextEpisode
        case let .segment(segment):
            L10n.skipSegment((segment.type ?? .unknown).displayTitle)
        }
    }

    var systemImage: String {
        switch self {
        case .nextEpisode:
            "forward.end.fill"
        case let .segment(segment):
            (segment.type ?? .unknown).systemImage
        }
    }
}
