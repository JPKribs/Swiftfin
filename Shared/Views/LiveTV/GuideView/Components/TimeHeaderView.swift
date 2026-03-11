//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

extension GuideView {

    struct TimeHeaderView: View {

        let timeRange: ClosedRange<Date>

        private var markers: [Date] {
            GuideTimeScale.timeMarkers(
                from: timeRange.lowerBound,
                to: timeRange.upperBound
            )
        }

        var body: some View {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(
                        width: GuideTimeScale.totalWidth(for: timeRange),
                        height: GuideTimeScale.timeHeaderHeight
                    )

                ForEach(markers, id: \.self) { marker in
                    VStack(spacing: 2) {
                        Text(marker, style: .time)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)

                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 1, height: 6)
                    }
                    .offset(x: GuideTimeScale.xPosition(for: marker, relativeTo: timeRange.lowerBound))
                }
            }
            .allowsHitTesting(false)
        }
    }
}
