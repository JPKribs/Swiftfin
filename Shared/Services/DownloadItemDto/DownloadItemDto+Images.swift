//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import BlurHashKit
import Defaults
import Foundation
import JellyfinAPI

extension DownloadItemDto {

    // MARK: - Item Images

    func imageURL(_ type: ImageType) -> URL? {
        imagePaths[type]
    }

    func blurHash(for type: ImageType) -> BlurHash? {
        guard let blurHashString = blurHashString(for: type) else {
            return nil
        }

        return BlurHash(string: blurHashString)
    }

    func blurHashString(for type: ImageType) -> String? {
        guard type != .logo else { return nil }

        if let firstHash = imageBlurHashes?[type]?.values.first {
            return firstHash
        }

        return nil
    }

    func imageSource(_ type: ImageType) -> ImageSource {
        let url = imagePaths[type]
        let blurHash = blurHashString(for: type)

        return ImageSource(url: url, blurHash: blurHash)
    }

    // MARK: - Parent Images

    func parentImageURL(_ type: ImageType, parentID: String?) -> URL? {
        guard let parentID,
              let parentItem = StoredValues[.Download.item(id: parentID)]
        else {
            return nil
        }

        return parentItem.imagePaths[type]
    }

    func parentImageSource(_ type: ImageType, parentID: String?) -> ImageSource {
        let url = parentImageURL(type, parentID: parentID)
        let blurHash = blurHashString(for: type)

        return ImageSource(url: url, blurHash: blurHash)
    }
}
