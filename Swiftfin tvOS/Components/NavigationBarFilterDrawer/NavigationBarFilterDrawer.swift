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

struct NavigationBarFilterDrawer: View {

    @Default(.accentColor)
    private var accentColor

    @ObservedObject
    private var viewModel: FilterViewModel

    @Router
    private var router

    private let filterTypes: [ItemFilterType]
    private let edge: HorizontalEdge

    static var font: Font {
        .system(size: 38, weight: .semibold)
    }

    static let dimension: CGFloat = 80
    private static let buttonSpacing: CGFloat = 16

    init(
        viewModel: FilterViewModel,
        types: [ItemFilterType],
        edge: HorizontalEdge
    ) {
        self.viewModel = viewModel
        self.filterTypes = types
        self.edge = edge
    }

    var body: some View {
        VStack(alignment: .center, spacing: Self.buttonSpacing) {
            if viewModel.currentFilters.isNotEmpty {
                FilterDrawerButton(
                    title: L10n.reset,
                    systemImage: "line.3.horizontal.decrease",
                    edge: edge,
                    action: { viewModel.reset(filterType: nil) }
                )
            }

            ForEach(filterTypes, id: \.self) { type in
                FilterDrawerButton(
                    title: type.displayTitle,
                    systemImage: type.systemImage,
                    edge: edge,
                    action: { router.route(to: .filter(type: type, viewModel: viewModel)) }
                )
                .isHighlighted(viewModel.isFilterSelected(type: type))
            }
        }
        .scrollIfLargerThanContainer()
        .frame(width: Self.dimension)
        .focusSection()
    }
}

extension NavigationBarFilterDrawer {

    struct FilterDrawerButton: View {

        @Default(.accentColor)
        private var accentColor

        @Environment(\.isHighlighted)
        private var isSelected

        @FocusState
        private var isFocused: Bool

        let title: String
        let systemImage: String
        let edge: HorizontalEdge
        let action: () -> Void

        private var foregroundStyle: Color {
            if isFocused {
                Color.primary.overlayColor
            } else if isSelected {
                accentColor.overlayColor
            } else {
                Color.primary
            }
        }

        private var backgroundStyle: Color {
            if isFocused {
                Color.primary
            } else if isSelected {
                accentColor
            } else {
                Color.secondarySystemFill
            }
        }

        var body: some View {
            Button {
                action()
            } label: {
                HStack(spacing: 0) {
                    if edge == .trailing, isFocused {
                        Text(title)
                            .font(.system(size: 26, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 24)
                            .transition(.move(edge: edge == .leading ? .leading : .trailing).combined(with: .opacity))
                    }

                    Image(systemName: systemImage)
                        .font(NavigationBarFilterDrawer.font)
                        .frame(
                            width: NavigationBarFilterDrawer.dimension,
                            height: NavigationBarFilterDrawer.dimension
                        )

                    if edge == .leading, isFocused {
                        Text(title)
                            .font(.system(size: 26, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 24)
                            .transition(.move(edge: edge == .leading ? .leading : .trailing).combined(with: .opacity))
                    }
                }
                .foregroundStyle(foregroundStyle)
                .background {
                    Capsule()
                        .foregroundStyle(backgroundStyle)
                        .shadow(radius: (isFocused || isSelected) ? 4 : 0, y: (isFocused || isSelected) ? 2 : 0)
                }
                .frame(
                    width: NavigationBarFilterDrawer.dimension,
                    height: NavigationBarFilterDrawer.dimension,
                    alignment: edge == .leading ? .leading : .trailing
                )
            }
            .buttonStyle(.borderless)
            .hoverEffectDisabled()
            .focusEffectDisabled()
            .focused($isFocused)
            .animation(.easeInOut(duration: 0.45), value: isFocused)
        }
    }
}
