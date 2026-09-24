//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI

struct MediaSegmentConfiguration: Hashable, Storable, WithDefaultValue {

    enum Behavior: String, CaseIterable, Displayable, Storable {

        case disabled
        case ask
        case skip

        var displayTitle: String {
            switch self {
            case .disabled:
                L10n.disabled
            case .ask:
                L10n.ask
            case .skip:
                L10n.skip
            }
        }
    }

    var nextEpisode: Duration?
    var promptDuration: Duration?
    var segments: [MediaSegmentType: Behavior]

    static let `default`: MediaSegmentConfiguration = .init(
        nextEpisode: .seconds(30),
        promptDuration: nil,
        segments: [:]
    )

    subscript(type: MediaSegmentType) -> Behavior {
        get { type.isSupported ? segments[type] ?? .ask : .disabled }
        set { segments[type] = newValue }
    }
}
