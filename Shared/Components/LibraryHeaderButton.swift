//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct LibraryHeaderButton<Library: PagingLibrary>: View where Library.Element: LibraryElement {

    #if os(tvOS)
    private struct HeaderButtonStyle: ButtonStyle {

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .opacity(configuration.isPressed ? 0.8 : 1)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
        }
    }

    @FocusState
    private var isFocused: Bool
    #endif

    @Router
    private var router

    let library: Library
    var isEnabled: Bool = true

    private func routeToLibrary() {
        router.route(to: .library(library: library))
    }

    private var title: some View {
        Text(library.parent.displayTitle)
            .font(.title3)
            .fontWeight(.semibold)
            .lineLimit(1)
    }

    var body: some View {
        Group {
            if isEnabled {
                Button(action: routeToLibrary) {
                    #if os(tvOS)
                    HStack(spacing: 3) {
                        title

                        if isFocused {
                            Image(systemName: "chevron.forward")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .backport
                    .glassEffect(
                        isFocused ? .regular : .identity,
                        in: .capsule
                    )
                    .animation(.easeInOut(duration: 0.15), value: isFocused)
                    .offset(x: -16)
                    #else
                    HStack(spacing: 3) {
                        title

                        Image(systemName: "chevron.forward")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    #endif
                }
                .foregroundStyle(.primary, .secondary)
                .accessibilityAction(named: Text(L10n.openLibrary), routeToLibrary)
                #if os(tvOS)
                    .buttonStyle(HeaderButtonStyle())
                    .focused($isFocused)
                #endif
            } else {
                title
                    .foregroundStyle(.primary)
            }
        }
        .edgePadding(.horizontal)
        .accessibilityAddTraits(.isHeader)
    }
}
