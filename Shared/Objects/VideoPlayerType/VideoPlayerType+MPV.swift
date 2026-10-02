//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI
import Libmpv

extension VideoPlayerType {

    // MARK: - Direct Play

    @ArrayBuilder<DirectPlayProfile>
    static var _mpvDirectPlayProfiles: [DirectPlayProfile] {
        DirectPlayProfile(
            type: .video,
            audioCodecs: AudioCodec.allCases.filter(decodes),
            videoCodecs: VideoCodec.allCases.filter(decodes),
            containers: MediaContainer.allCases.filter { demuxers.contains($0.ffmpegName) }
        )
    }

    // MARK: - Transcoding

    @ArrayBuilder<TranscodingProfile>
    static var _mpvTranscodingProfiles: [TranscodingProfile] {
        TranscodingProfile(
            isBreakOnNonKeyFrames: true,
            context: .streaming,
            maxAudioChannels: "8",
            minSegments: 2,
            protocol: MediaStreamProtocol.hls,
            type: .video
        ) {
            AudioCodec.allCases.filter(decodes)
        } videoCodecs: {

            /// - Note: Transcode Profiles prioritizes codecs by order:
            /// - .av1
            /// - .hevc
            /// - .h264

            if decodes(.av1) {
                VideoCodec.av1
            }
            if PlaybackCapabilities.supportsHEVC, decodes(.hevc) {
                VideoCodec.hevc
            }
            if decodes(.h264) {
                VideoCodec.h264
            }

            VideoCodec.allCases.filter { ![.av1, .hevc, .h264, .vc1].contains($0) && decodes($0) }
        } containers: {
            MediaContainer.mp4
        }

        /// Create a separate profile to allow VC1 to DirectStream
        /// Necessary to avoid server-imposed HLS video restrictions in StreamBuilder _supportedHlsVideoCodecs
        if decodes(.vc1) {
            TranscodingProfile(
                isBreakOnNonKeyFrames: true,
                context: .streaming,
                maxAudioChannels: "8",
                minSegments: 2,
                protocol: MediaStreamProtocol.hls,
                type: .video
            ) {
                AudioCodec.allCases.filter(decodes)
            } videoCodecs: {
                VideoCodec.vc1
            } containers: {
                MediaContainer.mp4
            }
        }
    }

    // MARK: - Subtitle

    /// - Note: MPV does not list subtitle decoders so this is manually maintained
    @ArrayBuilder<SubtitleProfile>
    static var _mpvSubtitleProfiles: [SubtitleProfile] {

        SubtitleProfile.build(method: .embed) {
            SubtitleFormat.allCases
        }

        /// - Note: Unmatched text subtitles are converted to the first option
        SubtitleProfile.build(method: .external) {
            SubtitleFormat.subrip
            SubtitleFormat.allCases.filter { $0 != .subrip && demuxers.contains($0.ffmpegName) }
        }

        SubtitleProfile.build(method: .encode) {
            SubtitleFormat.dvbsub
            SubtitleFormat.dvdsub
            SubtitleFormat.pgssub
            SubtitleFormat.vtt
            SubtitleFormat.xsub
        }
    }

    // MARK: - Codec Profiles

    /// - Note: MPVUI hands HDR and Dolby Vision to Apple's display path, so AVPlayer's HDR support applies
    @ArrayBuilder<CodecProfile>
    static var _mpvCodecProfiles: [CodecProfile] {
        CodecProfile(
            codec: VideoCodec.h264.rawValue,
            type: .video,
            conditions: {
                _h264BaseConditions
                ProfileCondition(
                    condition: .equalsAny,
                    isRequired: true,
                    property: .videoRangeType
                ) {
                    VideoRangeType.sdr
                    VideoRangeType.doviWithSDR
                }
            }
        )

        CodecProfile(
            codec: VideoCodec.hevc.rawValue,
            type: .video,
            conditions: {
                ProfileCondition(
                    condition: .notEquals,
                    isRequired: false,
                    property: .isAnamorphic,
                    value: "true"
                )
                ProfileCondition(
                    condition: .equalsAny,
                    isRequired: false,
                    property: .videoProfile
                ) {
                    HEVCProfile.main
                    HEVCProfile.main10
                }
                ProfileCondition(
                    condition: .notEquals,
                    isRequired: false,
                    property: .isInterlaced,
                    value: "true"
                )
                ProfileCondition(
                    condition: .equalsAny,
                    isRequired: true,
                    property: .videoRangeType
                ) {
                    _nativeHDRProfiles
                }
            }
        )

        CodecProfile(
            codec: VideoCodec.av1.rawValue,
            type: .video,
            conditions: {
                ProfileCondition(
                    condition: .notEquals,
                    isRequired: false,
                    property: .isAnamorphic,
                    value: "true"
                )
                ProfileCondition(
                    condition: .notEquals,
                    isRequired: false,
                    property: .isInterlaced,
                    value: "true"
                )
                ProfileCondition(
                    condition: .equalsAny,
                    isRequired: true,
                    property: .videoRangeType
                ) {
                    _nativeHDRProfiles
                }
            }
        )

        CodecProfile(
            codec: VideoCodec.vp9.rawValue,
            type: .video,
            conditions: {
                ProfileCondition(
                    condition: .notEquals,
                    isRequired: false,
                    property: .isAnamorphic,
                    value: "true"
                )
                ProfileCondition(
                    condition: .notEquals,
                    isRequired: false,
                    property: .isInterlaced,
                    value: "true"
                )
                ProfileCondition(
                    condition: .equalsAny,
                    isRequired: true,
                    property: .videoRangeType
                ) {
                    _nativeHDRProfiles
                }
            }
        )
    }

    // MARK: - libMPV Querying

    /// AV1 is possible with non-AV1 supported devices but the FPS is poor on older devices
    ///  - Defaulting to disabled but can be enabled in custom profiles if desired.
    private static func decodes(_ codec: VideoCodec) -> Bool {
        (codec != .av1 || PlaybackCapabilities.supportsAV1) && decoders.contains(codec.ffmpegName)
    }

    private static func decodes(_ codec: AudioCodec) -> Bool {
        decoders.contains(codec.ffmpegName)
    }

    private static let decoders = lists.decoders
    private static let demuxers = lists.demuxers

    private static let lists: (decoders: Set<String>, demuxers: Set<String>) = {
        guard let handle = mpv_create() else {
            return ([], [])
        }

        defer { mpv_terminate_destroy(handle) }

        mpv_set_option_string(handle, "vo", "null")
        mpv_set_option_string(handle, "ao", "null")

        guard mpv_initialize(handle) >= 0 else {
            return ([], [])
        }

        func property(_ name: String) -> String? {
            guard let value = mpv_get_property_string(handle, name) else {
                return nil
            }

            defer { mpv_free(value) }

            return String(cString: value)
        }

        let count = property("decoder-list/count").flatMap(Int.init) ?? 0
        let decoders = (0 ..< count).compactMap { property("decoder-list/\($0)/codec") }
        let demuxers = property("demuxer-lavf-list")?.components(separatedBy: ",") ?? []

        return (Set(decoders), Set(demuxers))
    }()
}
