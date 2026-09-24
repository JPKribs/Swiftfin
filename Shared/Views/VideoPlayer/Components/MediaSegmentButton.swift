//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

extension VideoPlayer.PlaybackControls {

    struct MediaSegmentButton: View {

        @EnvironmentObject
        private var manager: MediaPlayerManager

        @State
        private var dragOffset: CGFloat = 0

        let prompt: MediaSegmentPrompt

        var body: some View {
            Button {
                manager.skipMediaSegment()
            } label: {
                Label(prompt.displayTitle, systemImage: prompt.systemImage)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .edgePadding(.horizontal)
            }
            .buttonStyle(.supplementAction)
            .frame(height: UIDevice.isTV ? 80 : 40)
            .fixedSize(horizontal: true, vertical: false)
            #if os(iOS)
            .offset(x: dragOffset)
            .highPriorityGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let isDismissing = abs(value.predictedEndTranslation.width) > 100

                        withAnimation(.bouncy) {
                            dragOffset = isDismissing ? value.predictedEndTranslation.width : 0
                        }

                        if isDismissing {
                            manager.dismissMediaSegmentPrompt()
                        }
                    }
            )
            #endif
        }
    }
}
