//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import SwiftUI

extension GuideView {

    struct ProgramDetails: View {

        @Default(.accentColor)
        private var accentColor

        @Environment(\.horizontalSizeClass)
        private var horizontalSizeClass

        private let program: BaseItemDto
        private let onPlay: () -> Void

        private var playButtonFocused: FocusState<Bool>.Binding

        init(program: BaseItemDto, onPlay: @escaping () -> Void, playButtonFocused: FocusState<Bool>.Binding) {
            self.program = program
            self.onPlay = onPlay
            self.playButtonFocused = playButtonFocused
        }

        private var isCompact: Bool {
            horizontalSizeClass == .compact
        }

        // MARK: - Shared Components

        @ViewBuilder
        private var timeInfo: some View {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    if let startDate = program.startDate {
                        Text(startDate, style: .time)
                    }
                    Text("-")
                    if let endDate = program.endDate {
                        Text(endDate, style: .time)
                    }
                }
                .font(isCompact ? .caption : .footnote)
                .monospacedDigit()

                if program.isAiring {
                    Text("LIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red, in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }

        @ViewBuilder
        private var descriptionView: some View {
            VStack(alignment: .leading, spacing: 4) {

                if let channelName = program.channelName {
                    Text(channelName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Marquee(program.displayTitle)
                    .font(.title3)

                timeInfo

                if let tagline = program.taglines?.first {
                    Text(tagline)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let overview = program.overview, overview.isNotEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }

        @ViewBuilder
        private var playButton: some View {
            Button(action: onPlay) {
                HStack(spacing: isCompact ? 8 : 15) {
                    Image(systemName: "play.fill")

                    Text(L10n.play)
                }
                .padding(.horizontal, isCompact ? 12 : 20)
            }
            .fontWeight(.semibold)
            .buttonStyle(
                .tintedMaterial(
                    tint: accentColor,
                    foregroundColor: accentColor.overlayColor
                )
            )
            .isSelected(true)
            .focused(playButtonFocused)
        }

        // MARK: - Compact View

        private let compactPosterWidth: CGFloat = 130
        private let compactButtonHeight: CGFloat = 40
        private let compactSpacing: CGFloat = 6

        @ViewBuilder
        private var compactView: some View {
            AlternateLayoutView(alignment: .topLeading) {
                // Hidden layout: measures poster + button height
                VStack(spacing: compactSpacing) {
                    Color.clear
                        .posterAspectRatio(program.preferredPosterDisplayType, contentMode: .fit)
                    Color.clear
                        .frame(height: compactButtonHeight)
                }
                .frame(width: compactPosterWidth)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets.edgePadding)
            } content: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: compactSpacing) {
                        PosterImage(
                            item: program,
                            type: program.preferredPosterDisplayType,
                            contentMode: .fit
                        )
                        .cornerRadius(6)

                        playButton
                            .frame(maxWidth: .infinity)
                            .frame(height: compactButtonHeight)
                    }
                    .frame(width: compactPosterWidth)

                    descriptionView
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(EdgeInsets.edgePadding)
            }
        }

        // MARK: - Regular View

        private var regularPosterWidth: CGFloat {
            UIDevice.isTV ? 250 : 180
        }

        private var regularButtonHeight: CGFloat {
            UIDevice.isTV ? 75 : 50
        }

        private let regularSpacing: CGFloat = 8

        @ViewBuilder
        private var regularView: some View {
            AlternateLayoutView(alignment: .topLeading) {
                VStack(spacing: regularSpacing) {
                    Color.clear
                        .posterAspectRatio(program.preferredPosterDisplayType, contentMode: .fit)
                    Color.clear
                        .frame(height: regularButtonHeight)
                }
                .frame(width: regularPosterWidth)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets.edgePadding)
            } content: {
                HStack(alignment: .top, spacing: EdgeInsets.edgePadding) {
                    VStack(spacing: regularSpacing) {
                        PosterImage(
                            item: program,
                            type: program.preferredPosterDisplayType,
                            contentMode: .fit
                        )
                        .cornerRadius(10)
                        #if os(tvOS)
                            .hoverEffectDisabled()
                        #endif

                        playButton
                            .frame(maxWidth: .infinity)
                            .frame(height: regularButtonHeight)
                    }
                    .frame(width: regularPosterWidth)

                    descriptionView
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(EdgeInsets.edgePadding)
            }
        }

        // MARK: - Body

        var body: some View {
            if isCompact {
                compactView
            } else {
                regularView
            }
        }
    }
}
