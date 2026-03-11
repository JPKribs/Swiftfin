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

    struct GuideGridView: View {

        let channels: [ChannelProgram]
        let timeRange: ClosedRange<Date>
        let isToday: Bool
        let onProgramSelected: (BaseItemDto) -> Void
        let onReachedBottom: () -> Void

        private var totalWidth: CGFloat {
            GuideTimeScale.totalWidth(for: timeRange)
        }

        private var totalContentHeight: CGFloat {
            let spacingCount = max(CGFloat(channels.count) - 1, 0)
            let rowsHeight = channels.reduce(0) { $0 + rowHeight(for: $1) }
            return GuideTimeScale.timeHeaderHeight + rowsHeight + spacingCount * GuideTimeScale.rowSpacing
        }

        private var channelSpacing: CGFloat {
            UIDevice.isTV ? 16 : 8
        }

        var body: some View {
            ScrollView(.vertical, showsIndicators: false) {

                HStack(alignment: .top, spacing: channelSpacing) {

                    channelColumn

                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            ZStack(alignment: .topLeading) {
                                VStack(alignment: .leading, spacing: 0) {
                                    TimeHeaderView(timeRange: timeRange)
                                        .frame(height: GuideTimeScale.timeHeaderHeight)

                                    programRows
                                }

                                if isToday {
                                    NowIndicatorView(
                                        timeRangeStart: timeRange.lowerBound,
                                        gridHeight: totalContentHeight
                                    )
                                }
                            }
                        }
                        .onAppear {
                            if isToday {
                                proxy.scrollTo(NowIndicatorView.scrollID, anchor: .leading)
                            }
                        }
                    }
                }
            }
        }

        // MARK: - Row Height

        /// Computes the dynamic row height for a channel based on its poster type
        /// and the channel column width.
        private func rowHeight(for channelProgram: ChannelProgram) -> CGFloat {
            let posterType = channelProgram.channel.preferredPosterDisplayType
            let ratio: CGFloat = switch posterType {
            case .landscape: 1.77
            case .portrait: 2.0 / 3.0
            case .square: 1.0
            }
            let naturalHeight = GuideTimeScale.channelColumnWidth / ratio
            return min(naturalHeight, GuideTimeScale.channelColumnWidth)
        }

        // MARK: - Channel Column

        @ViewBuilder
        private var channelColumn: some View {
            VStack(spacing: 0) {

                Color.clear
                    .frame(height: GuideTimeScale.timeHeaderHeight)

                VStack(spacing: GuideTimeScale.rowSpacing) {
                    ForEach(Array(channels.enumerated()), id: \.element.id) { _, channelProgram in
                        ChannelCell(channelProgram: channelProgram)
                            .frame(height: rowHeight(for: channelProgram))
                    }
                }
            }
            .frame(width: GuideTimeScale.channelColumnWidth)
            .padding(.leading, channelSpacing)
        }

        // MARK: - Program Rows

        @ViewBuilder
        private var programRows: some View {
            VStack(spacing: GuideTimeScale.rowSpacing) {
                ForEach(Array(channels.enumerated()), id: \.element.id) { index, channelProgram in
                    programRow(for: channelProgram, index: index)
                }

                // Pagination sentinel
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        onReachedBottom()
                    }
            }
        }

        // MARK: - Program Row

        private var rowCornerRadius: CGFloat {
            UIDevice.isTV ? 10 : 8
        }

        @ViewBuilder
        private func programRow(for channelProgram: ChannelProgram, index: Int) -> some View {
            let height = rowHeight(for: channelProgram)

            ZStack(alignment: .topLeading) {
                ForEach(Array(channelProgram.programs.enumerated()), id: \.offset) { _, program in
                    let cellWidth = GuideTimeScale.width(for: program, in: timeRange)
                    let xPos = GuideTimeScale.xPosition(for: program, relativeTo: timeRange.lowerBound)

                    ProgramCell(
                        program: program,
                        width: cellWidth,
                        rowHeight: height,
                        action: { onProgramSelected(program) }
                    )
                    .offset(x: xPos)
                }
            }
            .frame(width: totalWidth, height: height, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: rowCornerRadius)
                    .fill(Color.secondarySystemFill)
            }
            .clipShape(RoundedRectangle(cornerRadius: rowCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: rowCornerRadius)
                    .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }

        // MARK: - Channel Cell

        struct ChannelCell: View {

            let channelProgram: ChannelProgram

            @State
            private var isPresentingInfo = false

            var body: some View {
                #if os(tvOS)
                PosterButton(
                    item: channelProgram.channel,
                    type: channelProgram.channel.preferredPosterDisplayType
                ) {
                    isPresentingInfo = true
                } label: {
                    EmptyView()
                }
                .alert(channelProgram.displayTitle, isPresented: $isPresentingInfo) {
                    Button(L10n.dismiss, role: .cancel) {}
                } message: {
                    LabeledContent(
                        L10n.channel,
                        value: channelProgram.channel.number?.description ?? .emptyDash
                    )
                }
                #else
                PosterButton(
                    item: channelProgram.channel,
                    type: channelProgram.channel.preferredPosterDisplayType
                ) { _ in
                    isPresentingInfo = true
                } label: {
                    EmptyView()
                }
                .popover(isPresented: $isPresentingInfo) {
                    VStack(spacing: 4) {
                        Text(channelProgram.displayTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if let number = channelProgram.channel.number {
                            Text(number)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .presentationCompactAdaptation(.popover)
                }
                #endif
            }
        }
    }
}
