//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

extension GuideView {

    /// A horizontal scrollable picker for selecting a day in the EPG guide.
    /// Shows "Today" followed by the next 6 days.
    struct DayPicker: View {

        @Default(.accentColor)
        private var accentColor

        @Binding
        var selectedDate: Date

        let onDateSelected: (Date) -> Void

        private let calendar = Calendar.current
        private let dayCount = 7

        private var days: [Date] {
            (0 ..< dayCount).compactMap { offset in
                calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: .now))
            }
        }

        private func label(for date: Date) -> String {
            if calendar.isDateInToday(date) {
                return L10n.today
            }
            let formatter = DateFormatter()
            formatter.setLocalizedDateFormatFromTemplate("MMMd")
            return formatter.string(from: date)
        }

        // MARK: - Layout

        private var pillPaddingH: CGFloat {
            UIDevice.isTV ? 24 : 14
        }

        private var pillPaddingV: CGFloat {
            UIDevice.isTV ? 12 : 8
        }

        private var pillCornerRadius: CGFloat {
            UIDevice.isTV ? 12 : 10
        }

        // MARK: - Body

        var body: some View {
            HStack(spacing: UIDevice.isTV ? 24 : 8) {
                ForEach(days, id: \.self) { date in
                    Button {
                        selectedDate = date
                        onDateSelected(date)
                    } label: {
                        Text(label(for: date))
                            .font(.callout)
                            .padding(.horizontal, pillPaddingH)
                            .padding(.vertical, pillPaddingV)
                    }
                    .buttonStyle(.tintedMaterial(
                        tint: accentColor,
                        foregroundColor: accentColor.overlayColor
                    ))
                    .isSelected(calendar.isDate(date, inSameDayAs: selectedDate))
                }
            }
            .scrollIfLargerThanContainer(axes: .horizontal)
            .edgePadding()
            .scrollClipDisabled()
        }
    }
}
