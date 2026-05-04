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

    @ViewBuilder
    func body(content: Content) -> some View {
        if let edge = letterPickerOrientation.edge,
           let viewModel
        {
            content
                .safeAreaInset(edge: edge == .trailing ? .leading : .trailing, alignment: .center, spacing: 0) {
                    InsetFilterBar(viewModel: viewModel, types: filterTypes, edge: edge == .leading ? .trailing : .leading)
                        .offset(x: edge == .trailing ? -EdgeInsets.edgePadding / 1.5 : EdgeInsets.edgePadding / 1.5)
                        .padding(edge == .trailing ? .trailing : .leading, -EdgeInsets.edgePadding / 2)
                        .focusSection()
                }
        } else {
            content
        }
    }
}
