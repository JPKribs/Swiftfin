//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Algorithms
import AVKit
import Factory
import Foundation
import JellyfinAPI
import MediaPlayer
import Nuke
import SwiftUI

struct DownloadItemDto: Codable, Hashable, Identifiable {

    // Identity
    let id: String?
    let name: String?
    let baseItem: BaseItemDto

    // UserData for offline changes
    var offlineUserData: UserItemDataDto?

    // Downloaded file locations
    let mediaPath: URL?
    let chapterImagePaths: [URL]
    let imagePaths: [ImageType: URL]
    let imageBlurHashes: BaseItemDto.ImageBlurHashes?

    // Downloaded file metadata
    let downloadedDate: Date
    let fileSize: Int64

    init(
        from item: BaseItemDto,
        fileSize: Int64,
        downloadedDate: Date = Date(),
        mediaPath: URL? = nil,
        chapterImagePaths: [URL] = [],
        imagePaths: [ImageType: URL] = [:],
    ) {
        self.id = item.id
        self.name = item.name
        self.baseItem = item
        self.offlineUserData = item.userData
        self.mediaPath = mediaPath
        self.chapterImagePaths = chapterImagePaths
        self.imagePaths = imagePaths
        self.imageBlurHashes = item.imageBlurHashes
        self.downloadedDate = downloadedDate
        self.fileSize = fileSize
    }
}
