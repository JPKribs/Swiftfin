//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

extension GuideView {

    struct ChannelColumnView: View {

        let channels: [ChannelProgram]

        var body: some View {
            VStack(spacing: GuideTimeScale.rowSpacing) {
                ForEach(channels, id: \.id) { channelProgram in
                    channelRow(for: channelProgram)
                }
            }
            .allowsHitTesting(false)
        }

        @ViewBuilder
        private func channelRow(for channelProgram: ChannelProgram) -> some View {
            HStack(alignment: .center) {
                if let number = channelProgram.channel.number {
                    Text(number)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                PosterImage(
                    item: channelProgram.channel,
                    type: channelProgram.channel.preferredPosterDisplayType
                )
            }
            .frame(
                width: GuideTimeScale.channelColumnWidth,
                height: GuideTimeScale.rowHeight
            )
        }
    }
}
