//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Factory
import Foundation
import JellyfinAPI

extension DownloadItemDto {

    // MARK: - Delete Full DownloadItemDto

    func delete() throws {
        guard let downloadFolder = baseItem.downloadFolder else {
            throw JellyfinAPIError("No download folder to delete")
        }

        // Delete the entire download folder including all subfolders
        try FileManager.default.removeItem(at: downloadFolder)

        deleteStorage()
    }

    // MARK: - Delete Download Images

    func deleteImage(_ imageType: ImageType, clearStore: Bool = true) throws {
        guard let imageURL = imageURL(imageType) else {
            return
        }

        try FileManager.default.removeItem(at: imageURL)

        if clearStore {
            updateStorage()
        }
    }

    // MARK: - Delete Download Media

    func deleteMedia(clearStore: Bool = true) throws {
        guard let mediaPath else {
            throw JellyfinAPIError("No media to delete")
        }

        try FileManager.default.removeItem(at: mediaPath)

        if clearStore {
            deleteStorage()
        }
    }

    // MARK: - Validate Download URLs

    func validate() -> Bool {

        // Only validate media if a Media File is expected AND one was downloaded
        if baseItem.canBePlayed, let mediaPath {
            let exists = FileManager.default.fileExists(atPath: mediaPath.path)
            if !exists {
                print("❌ Validation failed: Media file missing at \(mediaPath.path)")
                return false
            }
            print("✅ Media file exists at \(mediaPath.path)")
        }

        for image in imagePaths {
            let exists = FileManager.default.fileExists(atPath: image.value.path)
            if !exists {
                print("❌ Validation failed: Image \(image.key) missing at \(image.value.path)")
                return false
            }
        }

        print("✅ Validation passed for item: \(baseItem.id ?? "unknown")")

        return true
    }

    // MARK: - Update StoredValue for Download

    private func updateStorage() {
        guard let id else { return }

        StoredValues[.Download.item(id: id)] = self
    }

    // MARK: - Delete StoredValue for Download

    private func deleteStorage() {
        guard let id else { return }

        StoredValues[.Download.item(id: id)] = nil
    }
}
