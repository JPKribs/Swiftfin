//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct HideSpoilersModifier: ViewModifier {

    // MARK: Spoiler Types

    enum SpoilerType {
        case image
        case text
    }

    // MARK: Spoiler Variables

    private let isPlayed: Bool?
    private let spoilerType: SpoilerType
    private let revealable: Bool

    // MARK: State

    @State
    private var isBlurred = true

    // MARK: - Initializer

    init(_ isPlayed: Bool?, spoilerType: SpoilerType, revealable: Bool) {
        self.isPlayed = isPlayed
        self.spoilerType = spoilerType
        self.revealable = revealable
    }

    // MARK: - Body

    func body(content: Content) -> some View {
        Group {
            if isPlayed == false && StoredValues[.User.hideSpoilers] {
                content
                    .environment(\.redactionReasons, isBlurred ? .privacy : [])
                    .blur(radius: spoilerType == .text && isBlurred ? 3 : 0)
                    .overlay {
                        if spoilerType == .image && isBlurred {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .allowsHitTesting(false)
                        }
                    }
                    .contentShape(Rectangle())
                    .onLongPressGesture(perform: revealable ? toggleBlur : {})
            } else {
                content
            }
        }
    }

    private func toggleBlur() {
        withAnimation(.smooth(duration: 0.5)) {
            isBlurred.toggle()
        }
    }
}
