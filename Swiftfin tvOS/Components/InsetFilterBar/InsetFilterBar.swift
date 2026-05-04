//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

struct InsetFilterBar: View {

    @Router
    private var router

    @ObservedObject
    private var viewModel: FilterViewModel

    @FocusState
    private var focusedButton: String?

    private let filterTypes: [ItemFilterType]
    private let edge: HorizontalEdge

    @State
    private var buttonSize: CGSize = .zero

    private var dimension: CGFloat {
        max(buttonSize.width, buttonSize.height) + 8
    }

    private var buttonSpacing: CGFloat {
        dimension * 0.1
    }

    private var font: Font {
        .system(size: 30, weight: .semibold)
    }

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
        VStack(alignment: .center, spacing: 16) {
            if viewModel.currentFilters.isNotEmpty {
                InsetFilterBarButton(
                    L10n.reset,
                    systemImage: "line.3.horizontal.decrease",
                    edge: edge,
                    role: .destructive
                ) {
                    viewModel.reset(filterType: nil)
                }
                .focused($focusedButton, equals: "reset")
                .font(font)
                .frame(
                    width: dimension,
                    height: dimension,
                    alignment: edge == .leading ? .leading : .trailing
                )
            }

            ForEach(filterTypes, id: \.self) { type in
                InsetFilterBarButton(
                    type.displayTitle,
                    systemImage: type.systemImage,
                    edge: edge
                ) {
                    router.route(to: .filter(type: type, viewModel: viewModel))
                }
                .isHighlighted(viewModel.isFilterSelected(type: type))
                .focused($focusedButton, equals: type.id)
                .font(font)
                .frame(
                    width: dimension,
                    height: dimension,
                    alignment: edge == .leading ? .leading : .trailing
                )
            }
        }
        .environment(\.buttonDimension, dimension)
        .scrollIfLargerThanContainer()
        .frame(width: dimension)
        .background {
            ZStack {
                ForEach(filterTypes, id: \.self) { filter in
                    Image(systemName: filter.systemImage)
                        .font(font)
                }
            }
            .hidden()
            .allowsHitTesting(false)
            .fixedSize()
            .trackingSize($buttonSize)
        }
        .focusSection()
        .defaultFocus(
            $focusedButton,
            viewModel.currentFilters.isNotEmpty ? "reset" : filterTypes.first?.id,
            priority: focusedButton == nil ? .userInitiated : .automatic
        )
    }
}
