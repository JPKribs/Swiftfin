//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import SwiftUI

enum ActionButtonType: String, Codable, CaseIterable, Identifiable {

    case play
    case played
    case favorite
    case versions
    case trailers
    case subtitles
    case refresh
    case edit
    case delete

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .play:
            L10n.play
        case .played:
            L10n.played
        case .favorite:
            L10n.favorite
        case .versions:
            L10n.version
        case .trailers:
            L10n.trailer
        case .subtitles:
            L10n.subtitles
        case .refresh:
            L10n.refreshMetadata
        case .edit:
            L10n.edit
        case .delete:
            L10n.delete
        }
    }

    var systemImage: String {
        switch self {
        case .play:
            "play.fill"
        case .played:
            "checkmark"
        case .favorite:
            "heart"
        case .versions:
            "list.dash"
        case .trailers:
            "movieclapper"
        case .subtitles:
            "captions.bubble"
        case .refresh:
            "arrow.clockwise"
        case .edit:
            "pencil"
        case .delete:
            "trash"
        }
    }

    static var defaultOrder: [ActionButtonType] {
        [.play, .played, .favorite, .versions, .trailers, .subtitles, .refresh, .edit, .delete]
    }

    #if os(iOS)
    static let supportedCases: Set<ActionButtonType> = Set(allCases)
    #else
    static let supportedCases: Set<ActionButtonType> = Set(allCases).subtracting([.edit])
    #endif
}
