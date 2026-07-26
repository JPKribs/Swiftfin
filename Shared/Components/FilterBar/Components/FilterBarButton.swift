//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

extension FilterBar {

    struct FilterBarButton: View {

        @Default(.accentColor)
        private var accentColor

        @Environment(\.isSelected)
        private var isSelected

        @FocusState
        private var isFocused: Bool

        private let title: String
        private let systemImage: String
        private let dimension: CGFloat
        private let edge: HorizontalEdge
        private let role: ButtonRole?
        private let action: () -> Void

        init(
            _ title: String,
            systemImage: String,
            dimension: CGFloat,
            edge: HorizontalEdge,
            role: ButtonRole? = nil,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.systemImage = systemImage
            self.dimension = dimension
            self.edge = edge
            self.role = role
            self.action = action
        }

        private var isGlassVisible: Bool {
            isFocused || isSelected
        }

        private var glassTint: Color {
            if role == .destructive {
                .red
            } else if isFocused {
                .primary
            } else {
                accentColor
            }
        }

        private var foregroundStyle: Color {
            if isGlassVisible {
                glassTint.overlayColor
            } else if role == .destructive {
                .red
            } else {
                .primary
            }
        }

        @ViewBuilder
        private var titleLabel: some View {
            if isFocused {
                Text(title)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, dimension / 2)
            }
        }

        private var label: some View {
            HStack(spacing: 0) {
                if edge == .trailing {
                    titleLabel
                }

                Image(systemName: systemImage)
                    .frame(width: dimension, height: dimension)

                if edge == .leading {
                    titleLabel
                }
            }
            .foregroundStyle(foregroundStyle)
        }

        var body: some View {
            Button(action: action) {
                label
                    .backport
                    .glassEffect(
                        isGlassVisible ? .regular.selection(
                            tint: glassTint,
                            foregroundColor: glassTint.overlayColor
                        ) : .identity,
                        in: .capsule
                    )
                    .isSelected(isGlassVisible)
            }
            .buttonStyle(.borderless)
            .backport
            .buttonBorderShape(.capsule)
            .focused($isFocused)
            .frame(
                width: dimension,
                height: dimension,
                alignment: edge == .leading ? .leading : .trailing
            )
            .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
    }
}
