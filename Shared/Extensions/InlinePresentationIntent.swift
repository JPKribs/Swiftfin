//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

extension InlinePresentationIntent {

    /// Custom intents sit above Foundation's reserved range to avoid future collisions
    static let underlined = InlinePresentationIntent(rawValue: 1 << 20)
    static let superscripted = InlinePresentationIntent(rawValue: 1 << 21)
    static let subscripted = InlinePresentationIntent(rawValue: 1 << 22)

    static let custom: InlinePresentationIntent = [.underlined, .superscripted, .subscripted]

    /// Intents that produce characters rather than styling
    static let breaks: InlinePresentationIntent = [.lineBreak, .softBreak]

    var underlineStyle: Text.LineStyle? {
        contains(.underlined) ? .single : nil
    }

    var baselineOffset: CGFloat? {
        if contains(.superscripted) {
            5
        } else if contains(.subscripted) {
            -3
        } else {
            nil
        }
    }

    /// Characters that represent this break
    var text: String {
        if contains(.lineBreak) {
            .newParagraph
        } else if contains(.softBreak) {
            .newLine
        } else {
            .empty
        }
    }

    /// List items are single spaced
    var inListItem: InlinePresentationIntent {
        contains(.lineBreak) ? .softBreak : self
    }
}
