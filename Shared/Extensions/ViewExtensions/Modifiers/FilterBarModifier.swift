//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

struct FilterBarModifier: ViewModifier {

    @Default(.isLiquidGlassEnabled)
    private var isLiquidGlassEnabled

    @Default(.Customization.Library.letterPickerOrientation)
    private var letterPickerOrientation

    let viewModel: FilterViewModel
    let types: [ItemFilterType]

    private var edge: HorizontalEdge {
        letterPickerOrientation.edge == .leading ? .trailing : .leading
    }

    private var unoccupiedEdges: Edge.Set {
        var edges: Edge.Set = .horizontal

        for occupied in [letterPickerOrientation.edge, types.isEmpty ? nil : edge] {
            switch occupied {
            case .leading:
                edges.remove(.leading)
            case .trailing:
                edges.remove(.trailing)
            case nil:
                break
            }
        }

        return edges
    }

    private var bar: some View {
        FilterBar(
            viewModel: viewModel,
            types: types,
            edge: edge
        )
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(tvOS)
        if types.isEmpty {
            content
                .ignoresSafeArea(.all, edges: unoccupiedEdges)
        } else {
            content
                .ignoresSafeArea(.all, edges: unoccupiedEdges)
                .safeAreaInset(edge: edge, alignment: .center, spacing: 0) {
                    bar
                }
        }
        #else
        if types.isEmpty {
            content
        } else if #available(iOS 26, *), isLiquidGlassEnabled {
            content
                .safeAreaBar(edge: .top, spacing: 0) {
                    bar
                }
                .preference(key: IsSafeAreaBarApplied.self, value: true)
        } else {
            NavigationBarDrawerView {
                bar
                    .ignoresSafeArea()
            } content: {
                content
            }
            .ignoresSafeArea()
        }
        #endif
    }
}
