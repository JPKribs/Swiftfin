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

        private var glass: BackportGlass {
            switch (isFocused, isSelected, role) {
            case (true, _, .destructive):
                .regular.tint(.red).interactive()

            case (true, true, _):
                .regular.tint(accentColor).interactive(false)

            case (true, false, _):
                .regular.interactive()

            case (false, true, _):
                .regular.tint(accentColor).interactive(false)

            case (false, false, _):
                .regular.interactive(false)
            }
        }

        private var foregroundStyle: Color {
            if role == .destructive {
                .red.overlayColor
            } else {
                .primary
            }
        }

        @ViewBuilder
        private var titleLabel: some View {
            Text(title)
                .lineLimit(1)
                .fixedSize()
                .padding(edge == .leading ? .leading : .trailing, 12)
                .padding(edge == .leading ? .trailing : .leading, 24)
                .transition(.move(edge: edge == .leading ? .leading : .trailing).combined(with: .opacity))
        }

        private var buttonLabel: some View {
            HStack(spacing: 0) {
                if edge == .trailing, isFocused {
                    titleLabel
                }

                Image(systemName: systemImage)
                    .frame(width: dimension, height: dimension)

                if edge == .leading, isFocused {
                    titleLabel
                }
            }
            .foregroundStyle(foregroundStyle)
        }

        var body: some View {
            Button {
                action()
            } label: {
                buttonLabel
                    .backport
                    .glassEffect(glass, in: .capsule)
            }
            .buttonStyle(.borderless)
            .focused($isFocused)
            .frame(
                width: dimension,
                height: dimension,
                alignment: edge == .leading ? .leading : .trailing
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .hoverEffectDisabled()
            .focusEffectDisabled()
        }
    }
}
