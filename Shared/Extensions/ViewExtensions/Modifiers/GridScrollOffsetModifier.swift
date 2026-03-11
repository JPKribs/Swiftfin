//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI
@_spi(Advanced) import SwiftUIIntrospect

/// Tracks both horizontal and vertical scroll offsets of a `ScrollView`.
/// Based on the existing `ScrollViewOffsetModifier` pattern.
struct GridScrollOffsetModifier: ViewModifier {

    @StateObject
    private var scrollViewDelegate: ScrollViewDelegate

    init(
        horizontalOffset: Binding<CGFloat>,
        verticalOffset: Binding<CGFloat>
    ) {
        self._scrollViewDelegate = StateObject(
            wrappedValue: ScrollViewDelegate(
                horizontalOffset: horizontalOffset,
                verticalOffset: verticalOffset
            )
        )
    }

    func body(content: Content) -> some View {
        content.introspect(
            .scrollView,
            on: .iOS(.v15...),
            .tvOS(.v15...)
        ) { scrollView in
            scrollView.delegate = scrollViewDelegate
        }
    }

    private class ScrollViewDelegate: NSObject, ObservableObject, UIScrollViewDelegate {

        let horizontalOffset: Binding<CGFloat>
        let verticalOffset: Binding<CGFloat>

        init(
            horizontalOffset: Binding<CGFloat>,
            verticalOffset: Binding<CGFloat>
        ) {
            self.horizontalOffset = horizontalOffset
            self.verticalOffset = verticalOffset
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            horizontalOffset.wrappedValue = scrollView.contentOffset.x
            verticalOffset.wrappedValue = scrollView.contentOffset.y
        }
    }
}
