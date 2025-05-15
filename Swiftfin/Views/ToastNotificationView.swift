//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Factory
import Foundation
import SwiftUI

struct ToastView: View {

    // MARK: - Toast Details

    let toast: Toast
    let onDismiss: () -> Void

    // MARK: - Focus State

    @AccessibilityFocusState
    private var isFocused: Bool

    // MARK: - Display Timer Progress

    @State
    private var progress: CGFloat = 1.0
    @State
    private var timer: Timer? = nil

    // MARK: - Body

    var body: some View {
        contentView
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .onFirstAppear {
                startTimer()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
            .accessibilityFocused($isFocused)
    }

    // MARK: - Content View

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: toast.type.systemImage)
                        .foregroundStyle(toast.type.color)

                    Text(toast.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Spacer()

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(L10n.dismiss)
                }

                Text(toast.body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(height: 3)

                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: UIScreen.main.bounds.width * progress, height: 3)
            }
        }
        .background(Color.secondarySystemBackground)
        .cornerRadius(10)
        .shadow(radius: 5)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onTapGesture(perform: onDismiss)
    }

    // MARK: - Start the Lifespan Timer

    private func startTimer() {
        progress = 1.0

        let interval = toast.duration / 60.0

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            withAnimation(.linear(duration: interval)) {
                progress = max(0, progress - 0.01666667)
            }
        }
    }
}
