//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

extension GuideView {

    struct NowIndicatorView: View {

        @Default(.accentColor)
        private var accentColor

        @State
        private var now: Date = .now

        let timeRangeStart: Date
        let gridHeight: CGFloat

        private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

        static let scrollID = "nowIndicator"

        var body: some View {
            Rectangle()
                .fill(accentColor)
                .frame(width: 2, height: gridHeight)
                .offset(x: GuideTimeScale.xPosition(for: now, relativeTo: timeRangeStart))
                .id(Self.scrollID)
                .allowsHitTesting(false)
                .onReceive(timer) { newValue in
                    now = newValue
                }
        }
    }
}
