//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Defaults
import Factory
import SwiftUI

// TODO: should use environment refresh instead?
struct ErrorView<ErrorType: Error>: View {

    @Injected(\.currentUserSession)
    private var userSession

    @Default(.accentColor)
    private var accentColor

    @Router
    private var router

    private let error: ErrorType
    private var onRetry: (() -> Void)?

    #if os(tvOS)
    private let spacing: CGFloat = 40
    private let fontSize: CGFloat = 150
    private let maxWidth: CGFloat = 700
    #else
    private let spacing: CGFloat = 20
    private let fontSize: CGFloat = 72
    private let maxWidth: CGFloat = 300
    #endif

    var body: some View {
        VStack(spacing: spacing) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: fontSize))
                .foregroundColor(Color.red)

            Text(error.localizedDescription)
                .frame(maxWidth: maxWidth)
                .multilineTextAlignment(.center)

            if let onRetry {
                ListRowButton(L10n.retry) {
                    onRetry()
                }
                .frame(maxWidth: maxWidth)
                .foregroundStyle(accentColor.overlayColor, accentColor)
            }

            if error.localizedDescription.contains("401")
                || error.localizedDescription.contains("403") // TODO: Is there a way to purely get the code
            {
                ListRowButton(L10n.switchUser, role: .destructive) {
                    UIDevice.impact(.medium)

                    Defaults[.lastSignedInUserID] = .signedOut
                    Container.shared.currentUserSession.reset()
                    Notifications[.didSignOut].post()

                    router.dismiss()
                }
                .frame(maxWidth: maxWidth)

                Text(
                    "Error is often indicative that the session expired. Please sign into another user or replace your access token to continue."
                )
                .frame(maxWidth: maxWidth)
                .multilineTextAlignment(.center)
            }
        }
    }
}

extension ErrorView {

    init(error: ErrorType) {
        self.init(
            error: error,
            onRetry: nil
        )
    }

    func onRetry(_ action: @escaping () -> Void) -> Self {
        copy(modifying: \.onRetry, with: action)
    }
}
