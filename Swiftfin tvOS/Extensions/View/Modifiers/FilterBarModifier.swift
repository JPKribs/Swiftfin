//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

struct FilterBarBarModifier: ViewModifier {

    @Default(.Customization.Library.letterPickerOrientation)
    private var letterPickerOrientation

    let viewModel: FilterViewModel?
    let filterTypes: [ItemFilterType]

    private var letterPickerEdge: HorizontalEdge? {
        guard viewModel != nil else { return nil }
        return letterPickerOrientation.edge
    }

    private var filterBarEdge: HorizontalEdge? {
        guard viewModel != nil, filterTypes.isNotEmpty else { return nil }
        if let letterEdge = letterPickerEdge {
            return letterEdge == .leading ? .trailing : .leading
        }
        return .leading
    }

    private var ignoredSafeAreaEdges: Edge.Set {
        var edges: Edge.Set = []
        if letterPickerEdge != .leading && filterBarEdge != .leading {
            edges.insert(.leading)
        }
        if letterPickerEdge != .trailing && filterBarEdge != .trailing {
            edges.insert(.trailing)
        }
        return edges
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if let edge = filterBarEdge, let viewModel {
            content
                .ignoresSafeArea(edges: ignoredSafeAreaEdges)
                .safeAreaInset(edge: edge, alignment: .center, spacing: 0) {
                    InsetFilterBar(viewModel: viewModel, types: filterTypes, edge: edge)
                        .offset(x: edge == .leading ? -EdgeInsets.edgePadding / 1.5 : EdgeInsets.edgePadding / 1.5)
                        .padding(edge == .leading ? .trailing : .leading, -EdgeInsets.edgePadding / 2)
                        .focusSection()
                }
        } else {
            content
                .ignoresSafeArea(edges: ignoredSafeAreaEdges)
        }
    }
}
