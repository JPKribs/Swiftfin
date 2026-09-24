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

    enum NextEpisode: CaseIterable, Displayable, Hashable, Storable {

        case disabled
        case fromEnd(Duration)

        var displayTitle: String {
            switch self {
            case .disabled:
                L10n.disabled
            case let .fromEnd(duration):
                duration.formatted(.minuteSecondsNarrow)
            }
        }

        static var allCases: [NextEpisode] {
            [.disabled, .fromEnd(.seconds(15)), .fromEnd(.seconds(30)), .fromEnd(.seconds(45)), .fromEnd(.seconds(60))]
        }
    }

    enum PromptDuration: CaseIterable, Displayable, Hashable, Storable {

        case segment
        case fixed(Duration)

        var displayTitle: String {
            switch self {
            case .segment:
                L10n.segment
            case let .fixed(duration):
                duration.formatted(.minuteSecondsNarrow)
            }
        }

        static var allCases: [PromptDuration] {
            [.segment, .fixed(.seconds(5)), .fixed(.seconds(10)), .fixed(.seconds(15)), .fixed(.seconds(30))]
        }
    }

    var nextEpisode: NextEpisode
    var promptDuration: PromptDuration
    var segments: [MediaSegmentType: Behavior]

    static let `default`: MediaSegmentConfiguration = .init(
        nextEpisode: .fromEnd(.seconds(30)),
        promptDuration: .segment,
        segments: [:]
    )

    subscript(type: MediaSegmentType) -> Behavior {
        get { segments[type] ?? .ask }
        set { segments[type] = newValue }
    }
}
