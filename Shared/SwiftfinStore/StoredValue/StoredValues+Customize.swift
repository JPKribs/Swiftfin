//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Defaults
import Factory
import Foundation
import JellyfinAPI

/// User Customizations
extension StoredValues.Keys {

    enum Customize {

        // MARK: - Items

        enum Items {

            // MARK: - Items View

            enum View {

                /// Enable this user to edit Media Items
                static var itemViewType: Key<ItemViewType> {
                    CurrentUserKey(
                        "itemViewType",
                        domain: "customization-itemViewType",
                        default: .compactLogo
                    )
                }

                /// Use primary image instead of backdrop for cinematic view
                static var usePrimaryImage: Key<Bool> {
                    CurrentUserKey(
                        "cinematicItemViewTypeUsePrimaryImage",
                        domain: "customization-cinematicItemViewType",
                        default: false
                    )
                }
            }

            // MARK: - Items Series

            enum Series {

                /// Show seasons that are missing from the series
                static var shouldShowMissingSeasons: Key<Bool> {
                    CurrentUserKey(
                        "showMissingSeasons",
                        domain: "customizeItemsSeries",
                        default: true
                    )
                }
            }

            // MARK: - Items Seasons

            enum Seasons {

                /// Show episodes that are missing from seasons
                static var showMissingEpisodes: Key<Bool> {
                    CurrentUserKey(
                        "showMissingEpisodes",
                        domain: "customizeItemsSeasons",
                        default: true
                    )
                }
            }

            // MARK: - Items Episodes

            enum Episodes {

                /// Use series landscape backdrop for episode displays
                static var useSeriesLandscapeBackdrop: Key<Bool> {
                    CurrentUserKey(
                        "useSeriesLandscapeBackdrop",
                        domain: "customizeItemsEpisodes",
                        default: true
                    )
                }
            }
        }

        // MARK: - Posters

        enum Posters {

            /// Enable labels on posters showing titles and other information
            static var showPosterLabels: Key<Bool> {
                CurrentUserKey(
                    "showPosterLabels",
                    domain: "customizePosters",
                    default: true
                )
            }

            /// Select a poster display type for Next Up section
            static var nextUpPosterType: Key<PosterDisplayType> {
                CurrentUserKey(
                    "nextUpPosterType",
                    domain: "customizePosters",
                    default: .portrait
                )
            }

            /// Select a poster display type for Similar Items section
            static var similarPosterType: Key<PosterDisplayType> {
                CurrentUserKey(
                    "similarPosterType",
                    domain: "customizePosters",
                    default: .portrait
                )
            }

            /// Select a poster display type for Search results
            static var searchPosterType: Key<PosterDisplayType> {
                CurrentUserKey(
                    "searchPosterType",
                    domain: "customizePosters",
                    default: .portrait
                )
            }

            /// Select a poster display type for Recently Added section
            static var recentlyAddedPosterType: Key<PosterDisplayType> {
                CurrentUserKey(
                    "recentlyAddedPosterType",
                    domain: "customizePosters",
                    default: .portrait
                )
            }

            /// Select a poster display type for Latest In Library section
            static var latestInLibraryPosterType: Key<PosterDisplayType> {
                CurrentUserKey(
                    "latestInLibraryPosterType",
                    domain: "customizePosters",
                    default: .portrait
                )
            }
        }

        // MARK: - Library

        enum Library {

            /// [tvOS] Change the background using the blurhash of the focused library item
            static var cinematicBackground: Key<Bool> {
                CurrentUserKey(
                    "cinematicBackground",
                    domain: "customizeLibrary",
                    default: true
                )
            }

            // MARK: - Library Media

            enum Media {

                /// Enable the usage of random images instead of library posters in media
                static var randomImage: Key<Bool> {
                    CurrentUserKey(
                        "libraryRandomImage",
                        domain: "customizeLibraryMedia",
                        default: true
                    )
                }

                /// Enable the favorites library in media
                static var showFavorites: Key<Bool> {
                    CurrentUserKey(
                        "libraryShowFavorites",
                        domain: "customizeLibraryMedia",
                        default: true
                    )
                }
            }

            // MARK: - Library Filters

            enum Filters {

                // TODO: for now, only used for `sortBy` and `sortOrder`. Need to come up with
                //       rules for how stored filters work with libraries that should init
                //       with non-default filters (atow ex: favorites)
                /// Get library filters for a specific parent ID
                static func libraryFilters(parentID: String?) -> Key<ItemFilterCollection> {
                    CurrentUserKey(
                        parentID,
                        domain: "customizeLibraryFilters",
                        default: ItemFilterCollection.default
                    )
                }

                /// Select the filters that should exist in the filters drawer for libraries
                static var enabledDrawerFilters: Key<[ItemFilterType]> {
                    CurrentUserKey(
                        "enabledDrawerFilters",
                        domain: "customizeLibraryFilters",
                        default: ItemFilterType.allCases
                    )
                }

                /// Enable the letter picker bar for libraries
                static var letterPickerEnabled: Key<Bool> {
                    CurrentUserKey(
                        "letterPickerEnabled",
                        domain: "customizeLibraryFilters",
                        default: false
                    )
                }

                /// Select which side of the library the letter picker bar will be located
                static var letterPickerOrientation: Key<LetterPickerOrientation> {
                    CurrentUserKey(
                        "letterPickerOrientation",
                        domain: "customizeLibraryFilters",
                        default: .trailing
                    )
                }
            }

            // MARK: - Library Format

            enum Format {

                // MARK: - Library Format Display

                enum Display {

                    /// Default display type for all libraries
                    static var defaultDisplayType: Key<LibraryDisplayType> {
                        CurrentUserKey(
                            "defaultDisplayType",
                            domain: "customizeLibraryFormatDisplay",
                            default: .grid
                        )
                    }

                    /// Custom display type for a library
                    static func libraryDisplayType(parentID: String?) -> Key<LibraryDisplayType> {
                        CurrentUserKey(
                            parentID,
                            domain: "customizeLibraryFormatDisplay",
                            default: Defaults[.Customization.Library.displayType]
                        )
                    }
                }

                // MARK: - Library Format Posters

                enum Posters {

                    /// Default poster type for all libraries
                    static var defaultPosterType: Key<PosterDisplayType> {
                        CurrentUserKey(
                            "defaultPosterType",
                            domain: "customizeLibraryFormatPoster",
                            default: .portrait
                        )
                    }

                    /// Custom poster type for a library
                    static func libraryPosterType(parentID: String?) -> Key<PosterDisplayType> {
                        CurrentUserKey(
                            parentID,
                            domain: "customizeLibraryFormatPoster",
                            default: Defaults[.Customization.Library.posterType]
                        )
                    }
                }

                // MARK: - Library Format Columns

                enum Columns {

                    /// Default number of columns for all list views
                    static var defaultListColumnCount: Key<Int> {
                        CurrentUserKey(
                            "defaultListColumnCount",
                            domain: "customizeLibraryFormatColumns",
                            default: 1
                        )
                    }

                    /// Custom number of columns for a list view
                    static func libraryListColumnCount(parentID: String?) -> Key<Int> {
                        CurrentUserKey(
                            parentID,
                            domain: "customizeLibraryFormatColumns",
                            default: Defaults[.Customization.Library.listColumnCount]
                        )
                    }
                }

                // MARK: - Library Format History

                enum History {

                    /// Remember the last used layout for each library
                    static var rememberLayout: Key<Bool> {
                        CurrentUserKey(
                            "rememberLayout",
                            domain: "customizeLibraryFormatHistory",
                            default: false
                        )
                    }

                    /// Remember the last used sort order for each library
                    static var rememberSort: Key<Bool> {
                        CurrentUserKey(
                            "rememberSort",
                            domain: "customizeLibraryFormatHistory",
                            default: false
                        )
                    }
                }
            }
        }

        // MARK: - Indicators

        enum Indicators {

            /// Show indicator for favorited items
            static var showFavorited: Key<Bool> {
                CurrentUserKey(
                    "showFavorited",
                    domain: "customizeindicators",
                    default: true
                )
            }

            /// Show progress indicator on partially watched items
            static var showProgress: Key<Bool> {
                CurrentUserKey(
                    "showProgress",
                    domain: "customizeindicators",
                    default: true
                )
            }

            /// Show indicator for unwatched items
            static var showUnplayed: Key<Bool> {
                CurrentUserKey(
                    "showUnplayed",
                    domain: "customizeindicators",
                    default: true
                )
            }

            /// Show indicator for fully watched items
            static var showPlayed: Key<Bool> {
                CurrentUserKey(
                    "showPlayed",
                    domain: "customizeindicators",
                    default: true
                )
            }
        }

        // MARK: - Home

        enum Home {

            /// Enable the Recently Added section on the HomeView
            static var showRecentlyAdded: Key<Bool> {
                CurrentUserKey(
                    "showRecentlyAdded",
                    domain: "customizeHome",
                    default: true
                )
            }

            /// Enable content that is being rewatched in Next Up
            static var rewatchingNextUpEnabled: Key<Bool> {
                CurrentUserKey(
                    "rewatchingNextUpEnabled",
                    domain: "customizeHome",
                    default: false
                )
            }

            /// Set the maximum number of seconds an item can be in Next Up
            static var maxNextUp: Key<TimeInterval> {
                CurrentUserKey(
                    "maxNextUp",
                    domain: "customizeHome",
                    default: 366 * 86400
                )
            }
        }

        // MARK: - Search

        enum Search {
            enum Filters {

                /// Select the filters that should exist in the filters drawer for search
                static var enabledDrawerFilters: Key<[ItemFilterType]> {
                    CurrentUserKey(
                        "enabledDrawerFilters",
                        domain: "customizeSearchFilters",
                        default: ItemFilterType.allCases
                    )
                }
            }
        }

        // MARK: - Playback

        enum Playback {

            /// Select the custom device profiles that should be used for playback
            static var customDeviceProfiles: Key<[CustomDeviceProfile]> {
                CurrentUserKey(
                    "customDeviceProfiles",
                    domain: "customizePlayback",
                    default: []
                )
            }
        }
    }
}
