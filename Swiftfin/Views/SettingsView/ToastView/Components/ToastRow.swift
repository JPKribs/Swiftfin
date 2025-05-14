//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Foundation
import SwiftUI

struct ToastRow: View {

    // MARK: - Environment Variables

    @Environment(\.isEditing)
    private var isEditing
    @Environment(\.isSelected)
    private var isSelected

    // MARK: - Properties

    let toast: Toast
    let onSelect: () -> Void
    let onDelete: () -> Void

    // MARK: - Body

    var body: some View {
        ListRow {
            Image(systemName: toast.type.systemImage)
                .foregroundStyle(toast.type.color)

        } content: {
            VStack(alignment: .leading, spacing: 4) {
                Text(toast.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isEditing && !isSelected ? .secondary : .primary)

                Text(toast.body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                Text(toast.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            ListRowCheckbox()
        }
        .onSelect(perform: onSelect)
        .isSeparatorVisible(false)
        .swipeActions {
            Button(
                L10n.delete,
                systemImage: "trash",
                action: onDelete
            )
            .tint(.red)
        }
    }
}
