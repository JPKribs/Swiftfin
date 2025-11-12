//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Foundation

enum DownloadState: Codable, Hashable {
    case queued
    case downloading(Double)
    case paused
    case complete
    case error(DownloadError)

    enum CodingKeys: String, CodingKey {
        case type
        case progress
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "queued":
            self = .queued
        case "downloading":
            let progress = try container.decode(Double.self, forKey: .progress)
            self = .downloading(progress)
        case "paused":
            self = .paused
        case "complete":
            self = .complete
        case "error":
            let error = try container.decode(DownloadError.self, forKey: .error)
            self = .error(error)
        default:
            self = .queued
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .queued:
            try container.encode("queued", forKey: .type)
        case let .downloading(progress):
            try container.encode("downloading", forKey: .type)
            try container.encode(progress, forKey: .progress)
        case .paused:
            try container.encode("paused", forKey: .type)
        case .complete:
            try container.encode("complete", forKey: .type)
        case let .error(error):
            try container.encode("error", forKey: .type)
            try container.encode(error, forKey: .error)
        }
    }
}
