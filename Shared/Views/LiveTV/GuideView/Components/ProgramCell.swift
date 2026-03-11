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

    struct ProgramCell: View {

        @Default(.accentColor)
        private var accentColor

        @FocusState
        private var isFocused: Bool

        private let program: BaseItemDto
        private let width: CGFloat
        private let action: () -> Void

        init(program: BaseItemDto, width: CGFloat, action: @escaping () -> Void) {
            self.program = program
            self.width = width
            self.action = action
        }

        // MARK: - Layout Constants

        private var imageHeight: CGFloat {
            UIDevice.isTV ? 60 : GuideTimeScale.rowHeight - 16
        }

        private var imagePadding: CGFloat {
            UIDevice.isTV ? 12 : 8
        }

        private var titleFont: Font {
            UIDevice.isTV ? .callout : .caption
        }

        private var timeFont: Font {
            UIDevice.isTV ? .footnote : .caption2
        }

        private var dividerWidth: CGFloat {
            UIDevice.isTV ? 2 : 1
        }

        private var showImage: Bool {
            width >= GuideTimeScale.pointsPerHour / 3
        }

        private var showText: Bool {
            width >= GuideTimeScale.pointsPerHour / 4
        }

        // MARK: - Body

        var body: some View {
            Button(action: action) {

                ZStack {

                    if program.isAiring {
                        accentColor.opacity(0.5)
                    } else {
                        Color.gray.opacity(0.3)
                    }

                    HStack(spacing: imagePadding) {

                        if showImage {
                            PosterImage(
                                item: program,
                                type: program.preferredPosterDisplayType,
                                contentMode: .fit
                            )
                            .frame(height: imageHeight)
                            .cornerRadius(UIDevice.isTV ? 6 : 8)
                            .posterShadow()
                            .padding(imagePadding)
                            #if os(tvOS)
                                .hoverEffectDisabled()
                            #endif
                        }

                        AlternateLayoutView {
                            Color.clear
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        } content: {
                            if showText {
                                VStack(alignment: .leading, spacing: UIDevice.isTV ? 4 : 2) {
                                    Text(program.displayTitle)
                                        .font(titleFont)
                                        .fontWeight(program.isAiring ? .bold : .regular)
                                        .lineLimit(1)

                                    HStack(spacing: 2) {
                                        if let startDate = program.startDate {
                                            Text(startDate, style: .time)
                                        }

                                        Text("-")

                                        if let endDate = program.endDate {
                                            Text(endDate, style: .time)
                                        }
                                    }
                                    .font(timeFont)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(Color.primary.opacity(0.2))
                            .frame(width: dividerWidth)
                    }
                }
                .frame(
                    width: width,
                    height: GuideTimeScale.rowHeight,
                    alignment: .leading
                )
                .overlay {
                    if isFocused {
                        Rectangle()
                            .strokeBorder(Color.primary, lineWidth: 4)
                    }
                }
                .clipped()
            }
            .focusedValue(\.focusedPoster, AnyPoster(program))
            #if os(iOS)
                .buttonStyle(.plain)
            #elseif os(tvOS)
                .buttonStyle(.borderless)
                .focused($isFocused)
            #endif
        }
    }
}
