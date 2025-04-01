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
        case backdrop
        case image
        case text

        var blur: CGFloat {
            switch self {
            case .backdrop:
                return 40
            case .image:
                return 20
            case .text:
                return 5
            }
        }
    }

    // MARK: Initializer

    init(_ isPlayed: Bool?, spoilerType: SpoilerType, revealable: Bool) {
        self.isPlayed = isPlayed
        self.spoilerType = spoilerType
        self.revealable = revealable
    }

    // MARK: Spoiler Variables

    private let isPlayed: Bool?
    private let spoilerType: SpoilerType
    private let revealable: Bool

    // MARK: State

    @State
    private var isBlurred = true

    #if !tvOS
    private let blurRatio = 0.6
    #else
    private let blurRatio = 1.0
    #endif

    // MARK: - Body

    func body(content: Content) -> some View {
        Group {
            if isPlayed == false && StoredValues[.User.hideSpoilers] {
                content
                    .environment(\.redactionReasons, isBlurred ? .privacy : [])
                    .blur(radius: isBlurred ? spoilerType.blur * blurRatio : 0)
                #if !tvOS
                    .onLongPressGesture(perform: revealable ? toggleBlur : {})
                #endif
            } else {
                content
            }
        }
    }

    #if !tvOS
    private func toggleBlur() {
        withAnimation(.smooth(duration: 0.5)) {
            isBlurred.toggle()
        }
    }
    #endif
}
