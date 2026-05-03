//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

struct LibraryFiltersModifier: ViewModifier {

    @Default(.Customization.Library.letterPickerOrientation)
    private var letterPickerOrientation

    let viewModel: FilterViewModel?
    let filterTypes: [ItemFilterType]

    private var filterEdge: HorizontalEdge {
        switch letterPickerOrientation {
        case .leading:
            .trailing
        case .trailing, .disabled:
            .leading
        }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(tvOS)
        if let edge = letterPickerOrientation.edge, let viewModel {
            if filterTypes.isNotEmpty {
                content
                    .focusSection()
                    .safeAreaInset(edge: edge, alignment: .center, spacing: 0) {
                        LetterPickerBar(viewModel: viewModel)
                            .offset(x: edge == .leading ? -EdgeInsets.edgePadding / 1.5 : EdgeInsets.edgePadding / 1.5)
                            .padding(edge == .leading ? .trailing : .leading, -EdgeInsets.edgePadding / 2)
                            .focusSection()
                    }
                    .safeAreaInset(edge: filterEdge, alignment: .center, spacing: 0) {
                        NavigationBarFilterDrawer(viewModel: viewModel, types: filterTypes, edge: filterEdge)
                            .offset(x: filterEdge == .leading ? -EdgeInsets.edgePadding / 1.5 : EdgeInsets.edgePadding / 1.5)
                            .padding(filterEdge == .leading ? .trailing : .leading, -EdgeInsets.edgePadding / 2)
                            .focusSection()
                    }
            } else {
                content
                    .focusSection()
                    .ignoresSafeArea(.all, edges: edge == .leading ? .trailing : .leading)
                    .safeAreaInset(edge: edge, alignment: .center, spacing: 0) {
                        LetterPickerBar(viewModel: viewModel)
                            .offset(x: edge == .leading ? -EdgeInsets.edgePadding / 1.5 : EdgeInsets.edgePadding / 1.5)
                            .padding(edge == .leading ? .trailing : .leading, -EdgeInsets.edgePadding / 2)
                            .focusSection()
                    }
            }
        } else if filterTypes.isNotEmpty, let viewModel {
            content
                .focusSection()
                .ignoresSafeArea(.all, edges: filterEdge == .leading ? .trailing : .leading)
                .safeAreaInset(edge: filterEdge, alignment: .center, spacing: 0) {
                    NavigationBarFilterDrawer(viewModel: viewModel, types: filterTypes, edge: filterEdge)
                        .offset(x: filterEdge == .leading ? -EdgeInsets.edgePadding / 1.5 : EdgeInsets.edgePadding / 1.5)
                        .padding(filterEdge == .leading ? .trailing : .leading, -EdgeInsets.edgePadding / 2)
                        .focusSection()
                }
        } else {
            content
                .ignoresSafeArea(.all, edges: .horizontal)
        }
        #else
        if let edge = letterPickerOrientation.edge, let viewModel {
            content
                .focusSection()
                .ignoresSafeArea(.all, edges: edge == .leading ? .trailing : .leading)
                .safeAreaInset(edge: edge, alignment: .center, spacing: 0) {
                    LetterPickerBar(viewModel: viewModel)
                        .padding(.vertical, EdgeInsets.edgePadding / 2)
                        .padding(edge == .leading ? .leading : .trailing, EdgeInsets.edgePadding / 2)
                }
                .navigationBarFilterDrawer(viewModel: viewModel, types: filterTypes)
        } else if filterTypes.isNotEmpty, let viewModel {
            content
                .ignoresSafeArea(.all, edges: .horizontal)
                .navigationBarFilterDrawer(viewModel: viewModel, types: filterTypes)
        } else {
            content
                .ignoresSafeArea(.all, edges: .horizontal)
        }
        #endif
    }
}
