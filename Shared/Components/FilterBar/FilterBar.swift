//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

struct FilterBar: PlatformView {

    @FocusState
    private var focusedRow: Row?

    @ObservedObject
    var viewModel: FilterViewModel

    @Router
    private var router

    @State
    private var iconSize: CGSize = .zero

    let types: [ItemFilterType]
    let edge: HorizontalEdge

    private enum Row: Hashable {
        case reset
        case filter(ItemFilterType)
    }

    private let resetSystemImage = "line.3.horizontal.decrease"

    private var isResetVisible: Bool {
        viewModel.currentFilters.isNotEmpty
    }

    private var rows: [Row] {
        (isResetVisible ? [.reset] : []) + types.map(Row.filter)
    }

    private var dimension: CGFloat {
        max(iconSize.width, iconSize.height) + 8
    }

    private func route(to type: ItemFilterType) {
        router.route(
            to: .filter(
                type: type,
                viewModel: viewModel
            )
        )
    }

    var iOSView: some View {
        ScrollView(.horizontal) {
            HStack {
                if isResetVisible {
                    Menu(L10n.reset, systemImage: resetSystemImage) {
                        Button(L10n.reset, role: .destructive) {
                            viewModel.reset(filterType: nil)
                        }
                    }
                    .foregroundStyle(.primary, .secondary)
                    .labelStyle(FilterBarLabelStyle(isIconOnly: true))
                }

                ForEach(types, id: \.self) { type in
                    Button(type.displayTitle, systemImage: "chevron.down") {
                        route(to: type)
                    }
                    .foregroundStyle(.primary, .secondary)
                    .isHighlighted(viewModel.isFilterSelected(type: type))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 5)
            .labelStyle(FilterBarLabelStyle())
        }
        .scrollIndicators(.hidden)
        .backport
        .scrollClipDisabled()
    }

    private var filterRail: some View {
        VStack(spacing: dimension * 0.1) {
            ForEach(rows, id: \.self) { row in
                switch row {
                case .reset:
                    FilterBarButton(
                        L10n.reset,
                        systemImage: resetSystemImage,
                        dimension: dimension,
                        edge: edge,
                        role: .destructive
                    ) {
                        viewModel.reset(filterType: nil)
                    }
                    .focused($focusedRow, equals: row)
                case let .filter(type):
                    FilterBarButton(
                        type.displayTitle,
                        systemImage: type.systemImage,
                        dimension: dimension,
                        edge: edge
                    ) {
                        route(to: type)
                    }
                    .isSelected(viewModel.isFilterSelected(type: type))
                    .focused($focusedRow, equals: row)
                }
            }
        }
        .frame(width: dimension)
        .background {
            ZStack {
                Image(systemName: resetSystemImage)

                ForEach(types, id: \.self) { type in
                    Image(systemName: type.systemImage)
                }
            }
            .hidden()
            .fixedSize()
            .trackingSize($iconSize)
        }
        .font(.system(size: 30, weight: .semibold))
    }

    var tvOSView: some View {
        filterRail
            .scrollIfLargerThanContainer()
            .frame(width: dimension)
            .focusSection()
            .backport
            .defaultFocus(
                $focusedRow,
                rows.first ?? .reset,
                priority: focusedRow == nil ? .userInitiated : .automatic
            )
            .offset(x: edge == .leading ? -EdgeInsets.edgePadding / 1.5 : EdgeInsets.edgePadding / 1.5)
    }
}
