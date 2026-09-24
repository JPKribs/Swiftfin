//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct DurationPicker: View {

    @State
    private var customSeconds: Int = 0
    @State
    private var isPresentingCustomDuration: Bool = false

    let title: String
    let selection: Binding<Duration?>
    let noneTitle: String
    var options: [Duration] = []

    private var selectionTitle: String {
        selection.wrappedValue?.formatted(.minuteSecondsNarrow) ?? noneTitle
    }

    @ViewBuilder
    private var picker: some View {
        Picker(
            title,
            selection: selection
                .map(
                    getter: { value -> Duration? in
                        if let value, !options.contains(value) {
                            .zero
                        } else {
                            value
                        }
                    },
                    setter: { newValue in
                        if newValue == .zero {
                            customSeconds = Int(selection.wrappedValue?.seconds ?? 30)
                            isPresentingCustomDuration = true
                            return selection.wrappedValue
                        }
                        return newValue
                    }
                )
        ) {
            Text(noneTitle)
                .tag(nil as Duration?)

            ForEach(options, id: \.self) { duration in
                Text(duration, format: .minuteSecondsNarrow)
                    .tag(duration as Duration?)
            }

            Divider()

            Text(L10n.custom)
                .tag(Duration.zero as Duration?)
        } currentValueLabel: {
            Text(selectionTitle)
        }
    }

    @ViewBuilder
    private var content: some View {
        #if os(tvOS)
        ListRowMenu(title, subtitle: Text(selectionTitle)) {
            picker
        }
        #else
        picker
        #endif
    }

    var body: some View {
        content
            .alert(title, isPresented: $isPresentingCustomDuration) {
                TextField(L10n.duration, value: $customSeconds.clamp(min: 1, max: 600), format: .number)
                    .keyboardType(.numberPad)

                Button(L10n.ok) {
                    selection.wrappedValue = .seconds(customSeconds)
                }
            } message: {
                Text(L10n.enterCustomDuration)
            }
    }
}
