//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct PosterHStackLibrarySection<Library: PagingLibrary>: View
    where Library.Element: LibraryElement, Library.Element: Poster
{

    private enum FocusSection {
        case header
        case content
    }

    @FocusState
    private var focusedSection: FocusSection?

    @ObservedObject
    var viewModel: PagingLibraryViewModel<Library>

    @Router
    private var router

    let group: PosterGroup<Library>

    var body: some View {
        if viewModel.elements.isNotEmpty {
            ContentGroupSection {
                PosterHStack(
                    elements: viewModel.elements.elements,
                    displayType: group.posterDisplayType,
                    size: group.posterSize
                ) { element, namespace in
                    element.libraryDidSelectElement(router: router, in: namespace)
                }
                .withViewContext(.isThumb)
                .focusSection()
                .focused($focusedSection, equals: .content)
            } header: {
                LibraryHeaderButton(
                    library: viewModel.library,
                    isEnabled: group.environment.isHeaderButtonEnabled
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .if(group.environment.isHeaderButtonEnabled) { header in
                    header
                        .focusSection()
                        .focused($focusedSection, equals: .header)
                }
            }
            .focusSection()
            .defaultFocus(
                $focusedSection,
                .content,
                priority: .userInitiated
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(viewModel.library.parent.displayTitle)
        }
    }
}
