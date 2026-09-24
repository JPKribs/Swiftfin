//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

extension VideoPlayer {

    struct PlaybackControls: View {

        enum FocusTarget {
            case playbackProgress
            case mediaSegmentButton
        }

        @Default(.VideoPlayer.jumpBackwardInterval)
        var jumpBackwardInterval
        @Default(.VideoPlayer.jumpForwardInterval)
        var jumpForwardInterval

        @EnvironmentObject
        var containerState: VideoPlayerContainerState
        @EnvironmentObject
        var manager: MediaPlayerManager

        @Toaster
        var toaster: ToastProxy

        @FocusState
        var focusTarget: FocusTarget?

        @State
        var speedBoostTimer: Timer?
        @State
        var isSpeedBoosting: Bool = false
        @State
        var pendingJumpWork: DispatchWorkItem?
        private let spacing: CGFloat = 30

        @State
        var mediaSegmentDismissEdge: Edge = .trailing

        @State
        private var progressFrame: CGRect = .zero

        var body: some View {
            VStack(spacing: spacing) {

                Toolbar()
                    .isVisible(
                        containerState.isPresentingOverlay &&
                            !containerState.isScrubbing &&
                            !containerState.isPresentingSupplement
                    )
                    .disabled(containerState.isPresentingSupplement)

                PlaybackProgress()
                    .focused($focusTarget, equals: .playbackProgress)
                    .fixedSize(horizontal: false, vertical: true)
                    .trackingFrame($progressFrame)
                    .isVisible(
                        (containerState.isPresentingOverlay || containerState.isScrubbing) &&
                            !containerState.isPresentingSupplement
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .overlay(alignment: .bottomTrailing) {
                if let prompt = manager.mediaSegmentPrompt, !containerState.isScrubbing, !containerState.isPresentingSupplement {
                    MediaSegmentButton(prompt: prompt)
                        .focused($focusTarget, equals: .mediaSegmentButton)
                        .padding(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .focusSection()
                        .offset(
                            y: containerState.isPresentingOverlay
                                ? -progressFrame.height - Toolbar.buttonSize - spacing * 2
                                : EdgeInsets.edgePadding
                        )
                        .task {
                            mediaSegmentDismissEdge = .trailing

                            if !containerState.isPresentingOverlay {
                                focusTarget = .mediaSegmentButton
                            }
                        }
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: mediaSegmentDismissEdge)
                            )
                            .combined(with: .opacity)
                        )
                }
            }
            .edgePadding(.horizontal)
            .focusSection()
            .animation(.easeInOut(duration: 0.25), value: containerState.isPresentingSupplement)
            .animation(.easeInOut(duration: 0.25), value: containerState.isPresentingOverlay)
            .animation(.linear(duration: 0.1), value: containerState.isScrubbing)
            .animation(.easeInOut(duration: 0.25), value: manager.mediaSegmentPrompt)
            .alert(L10n.closePlayer, isPresented: $containerState.isPresentingCloseConfirmation) {
                Button(L10n.cancel, role: .cancel) {}

                Button(L10n.ok, role: .destructive) {
                    manager.stop()
                }
            } message: {
                Text(L10n.closePlayerWarning)
            }
            .onChange(of: containerState.isPresentingOverlay) {
                if focusTarget != .mediaSegmentButton {
                    focusTarget = .playbackProgress
                }
            }
            .onChange(of: manager.playbackRequestStatus) {
                if manager.playbackRequestStatus == .paused, !containerState.isPresentingOverlay {
                    containerState.isPresentingOverlay = true
                }
            }
            .onReceive(containerState.containerView?.onPressEvent ?? .init()) { press in
                handlePressEvent(press)
            }
            .onChange(of: containerState.isProgressBarFocused) {
                if !containerState.isProgressBarFocused {
                    containerState.cancelScrub()

                    if isSpeedBoosting {
                        stopSpeedBoost()
                    }
                }
            }
        }
    }
}
