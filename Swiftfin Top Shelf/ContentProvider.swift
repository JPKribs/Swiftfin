//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import TVServices

class ContentProvider: TVTopShelfContentProvider {

    private static let defaults = UserDefaults(suiteName: "group.org.jellyfin.swiftfin")

    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {

        guard let defaults = Self.defaults else { return nil }

        var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []

        if let section = loadSection(defaults: defaults, key: "topShelfResumeItems", title: "Resume") {
            sections.append(section)
        }

        if let section = loadSection(defaults: defaults, key: "topShelfNextUpItems", title: "Next Up") {
            sections.append(section)
        }

        if let section = loadSection(defaults: defaults, key: "topShelfRecentlyAddedItems", title: "Recently Added") {
            sections.append(section)
        }

        guard !sections.isEmpty else { return nil }

        return TVTopShelfSectionedContent(sections: sections)
    }

    // MARK: - Helpers

    private func loadSection(
        defaults: UserDefaults,
        key: String,
        title: String
    ) -> TVTopShelfItemCollection<TVTopShelfSectionedItem>? {
        guard let data = defaults.array(forKey: key) as? [[String: String]],
              !data.isEmpty
        else {
            return nil
        }

        let shelfItems: [TVTopShelfSectionedItem] = data.compactMap { dict in
            guard let id = dict["id"],
                  let name = dict["name"]
            else {
                return nil
            }

            let item = TVTopShelfSectionedItem(identifier: id)
            item.title = name
            item.imageShape = .poster

            if let imageURLString = dict["imageURL"],
               let imageURL = URL(string: imageURLString)
            {
                item.setImageURL(imageURL, for: .screenScale1x)
                item.setImageURL(imageURL, for: .screenScale2x)
            }

            if let positionString = dict["playbackPositionTicks"],
               let runTimeString = dict["runTimeTicks"],
               let position = Double(positionString),
               let runTime = Double(runTimeString),
               runTime > 0
            {
                item.playbackProgress = position / runTime
            }

            item.playAction = TVTopShelfAction(url: URL(string: "swiftfin://item/\(id)")!)
            item.displayAction = TVTopShelfAction(url: URL(string: "swiftfin://item/\(id)")!)

            return item
        }

        guard !shelfItems.isEmpty else { return nil }

        let section = TVTopShelfItemCollection(items: shelfItems)
        section.title = title
        return section
    }
}
