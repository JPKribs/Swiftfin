//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI

// MARK: - ActionButtonAction

enum ActionButtonAction: Equatable {
    case play(fromBeginning: Bool = false)
    case togglePlayed
    case toggleFavorite
    case selectMediaSource(MediaSourceInfo)
    case playLocalTrailer(BaseItemDto)
    case playExternalTrailer(MediaURL)
    case searchSubtitles
    case refresh(RefreshAction)
    #if os(iOS)
    case edit
    #endif
    case delete
}

// MARK: - RefreshAction

enum RefreshAction {
    case findMissing
    case replaceMetadata
    case replaceImages
    case replaceAll
}
