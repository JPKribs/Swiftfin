//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Foundation

struct Toast: Identifiable, Equatable, Codable {
    var id = UUID()
    let title: String
    let body: String
    let type: ToastType
    let timestamp: Date
    var isRead: Bool = false
    var duration: Double = 5.0

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
