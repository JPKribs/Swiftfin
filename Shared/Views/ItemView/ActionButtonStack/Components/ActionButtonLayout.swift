//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import SwiftUI

extension ItemView {

    // MARK: - Layout Mode

    enum ActionButtonLayoutMode: Equatable {
        case horizontal
        case vertical
        case inline(alignment: InlineAlignment)

        enum InlineAlignment: Equatable {
            case leading
            case trailing
            case spaceBetween
        }
    }

    // MARK: - Button Size Constraints

    struct ButtonSizeConstraints: Equatable {
        var minWidth: CGFloat?
        var maxWidth: CGFloat?
        var preferredWidth: CGFloat?

        static let `default` = ButtonSizeConstraints()

        static func fixed(_ width: CGFloat) -> ButtonSizeConstraints {
            ButtonSizeConstraints(minWidth: width, maxWidth: width, preferredWidth: width)
        }

        static func flexible(min: CGFloat? = nil, max: CGFloat? = nil) -> ButtonSizeConstraints {
            ButtonSizeConstraints(minWidth: min, maxWidth: max)
        }

        static func preferred(_ width: CGFloat, min: CGFloat? = nil, max: CGFloat? = nil) -> ButtonSizeConstraints {
            ButtonSizeConstraints(minWidth: min, maxWidth: max, preferredWidth: width)
        }

        func resolve(availableWidth: CGFloat, fallback: CGFloat) -> CGFloat {
            var width = preferredWidth ?? fallback

            if let minWidth {
                width = max(width, minWidth)
            }

            if let maxWidth {
                width = min(width, maxWidth)
            }

            return min(width, availableWidth)
        }
    }

    // MARK: - Action Button Layout

    struct ActionButtonLayout: Layout {

        struct CacheData {
            let primaryIndices: [Int]
            let secondaryIndices: [Int]
            let overflowIndices: [Int]
            let primaryButtonSize: CGSize
            let secondaryButtonSize: CGSize
            let overflowButtonSize: CGSize
            let totalSize: CGSize
        }

        private let mode: ActionButtonLayoutMode
        private let buttonHeight: CGFloat
        private let horizontalSpacing: CGFloat
        private let verticalSpacing: CGFloat
        private let primaryButtonConstraints: ButtonSizeConstraints
        private let secondaryButtonConstraints: ButtonSizeConstraints

        private var overflowButtonWidth: CGFloat {
            buttonHeight * 0.6
        }

        // MARK: - Initializer

        init(
            mode: ActionButtonLayoutMode = .horizontal,
            buttonHeight: CGFloat = 50,
            horizontalSpacing: CGFloat = 10,
            verticalSpacing: CGFloat = 10,
            primaryButtonConstraints: ButtonSizeConstraints = .default,
            secondaryButtonConstraints: ButtonSizeConstraints = .default
        ) {
            self.mode = mode
            self.buttonHeight = buttonHeight
            self.horizontalSpacing = horizontalSpacing
            self.verticalSpacing = verticalSpacing
            self.primaryButtonConstraints = primaryButtonConstraints
            self.secondaryButtonConstraints = secondaryButtonConstraints
        }

        // MARK: - Make Cache

        func makeCache(subviews: Subviews) -> CacheData {
            CacheData(
                primaryIndices: [],
                secondaryIndices: [],
                overflowIndices: [],
                primaryButtonSize: .zero,
                secondaryButtonSize: .zero,
                overflowButtonSize: .zero,
                totalSize: .zero
            )
        }

        // MARK: - Size That Fits

        func sizeThatFits(
            proposal: ProposedViewSize,
            subviews: Subviews,
            cache: inout CacheData
        ) -> CGSize {
            guard !subviews.isEmpty else { return .zero }

            let availableWidth = proposal.width ?? .infinity
            let effectiveWidth = availableWidth.isFinite ? availableWidth : 1000

            switch mode {
            case .horizontal:
                cache = calculateHorizontalLayout(subviews: subviews, availableWidth: effectiveWidth)
            case .vertical:
                cache = calculateVerticalLayout(subviews: subviews, availableWidth: effectiveWidth)
            case let .inline(alignment):
                cache = calculateInlineLayout(subviews: subviews, availableWidth: effectiveWidth, alignment: alignment)
            }

            return cache.totalSize
        }

        // MARK: - Place Subviews

        func placeSubviews(
            in bounds: CGRect,
            proposal: ProposedViewSize,
            subviews: Subviews,
            cache: inout CacheData
        ) {
            guard !subviews.isEmpty else { return }

            if cache.totalSize == .zero {
                switch mode {
                case .horizontal:
                    cache = calculateHorizontalLayout(subviews: subviews, availableWidth: bounds.width)
                case .vertical:
                    cache = calculateVerticalLayout(subviews: subviews, availableWidth: bounds.width)
                case let .inline(alignment):
                    cache = calculateInlineLayout(subviews: subviews, availableWidth: bounds.width, alignment: alignment)
                }
            }

            switch mode {
            case .horizontal:
                placeHorizontalSubviews(in: bounds, subviews: subviews, cache: cache)
            case .vertical:
                placeVerticalSubviews(in: bounds, subviews: subviews, cache: cache)
            case let .inline(alignment):
                placeInlineSubviews(in: bounds, subviews: subviews, cache: cache, alignment: alignment)
            }
        }

        // MARK: - Calculate Inline Layout

        private func calculateInlineLayout(
            subviews: Subviews,
            availableWidth: CGFloat,
            alignment: ActionButtonLayoutMode.InlineAlignment
        ) -> CacheData {
            guard !subviews.isEmpty else {
                return emptyCacheData()
            }

            let totalCount = subviews.count
            let hasOverflowMenu = subviews.last?[OverflowMenuKey.self] == true
            let buttonCount = hasOverflowMenu ? totalCount - 1 : totalCount

            guard buttonCount > 0 else {
                return emptyCacheData()
            }

            let primaryMinWidth = primaryButtonConstraints.minWidth ?? 0
            let secondaryTargetWidth = secondaryButtonConstraints.resolve(
                availableWidth: availableWidth,
                fallback: buttonHeight
            )

            let primaryIndices = [0]
            var secondaryIndices: [Int] = []
            var overflowIndices: [Int] = []

            if buttonCount > 1 {
                let maxSecondary = buttonCount - 1
                let availableForSecondary = availableWidth - primaryMinWidth - horizontalSpacing

                for count in (0 ... maxSecondary).reversed() {
                    let needsOverflow = count < maxSecondary
                    let overflowReserved = needsOverflow ? (overflowButtonWidth + horizontalSpacing) : 0
                    let availableForButtons = availableForSecondary - overflowReserved

                    if count == 0 {
                        overflowIndices = Array(1 ..< buttonCount)
                        break
                    }

                    let neededWidth = secondaryTargetWidth * CGFloat(count) + CGFloat(count - 1) * horizontalSpacing

                    if neededWidth <= availableForButtons {
                        secondaryIndices = Array(1 ... count)
                        if count < maxSecondary {
                            overflowIndices = Array((count + 1) ..< buttonCount)
                        }
                        break
                    }
                }
            }

            let needsOverflow = !overflowIndices.isEmpty
            let overflowReserved = needsOverflow ? (overflowButtonWidth + horizontalSpacing) : 0

            let secondaryCount = secondaryIndices.count
            let secondaryButtonWidth = secondaryTargetWidth
            let secondaryTotalWidth = secondaryCount > 0
                ? (secondaryButtonWidth * CGFloat(secondaryCount) + CGFloat(secondaryCount - 1) * horizontalSpacing)
                : 0

            let spacingForPrimary = (secondaryCount > 0 || needsOverflow) ? horizontalSpacing : 0
            let remainingForPrimary = availableWidth - secondaryTotalWidth - overflowReserved - spacingForPrimary

            let primaryButtonWidth = primaryButtonConstraints.resolve(
                availableWidth: remainingForPrimary,
                fallback: remainingForPrimary
            )

            let primarySize = CGSize(width: primaryButtonWidth, height: buttonHeight)
            let secondarySize = CGSize(width: secondaryButtonWidth, height: buttonHeight)
            let overflowSize = CGSize(width: overflowButtonWidth, height: buttonHeight)

            return CacheData(
                primaryIndices: primaryIndices,
                secondaryIndices: secondaryIndices,
                overflowIndices: overflowIndices,
                primaryButtonSize: primarySize,
                secondaryButtonSize: secondarySize,
                overflowButtonSize: overflowSize,
                totalSize: CGSize(width: availableWidth, height: buttonHeight)
            )
        }

        // MARK: - Place Inline Subviews

        private func placeInlineSubviews(
            in bounds: CGRect,
            subviews: Subviews,
            cache: CacheData,
            alignment: ActionButtonLayoutMode.InlineAlignment
        ) {
            switch alignment {
            case .leading:
                placeInlineLeading(in: bounds, subviews: subviews, cache: cache)
            case .trailing:
                placeInlineTrailing(in: bounds, subviews: subviews, cache: cache)
            case .spaceBetween:
                placeInlineSpaceBetween(in: bounds, subviews: subviews, cache: cache)
            }
        }

        // MARK: - Place Inline Leading

        private func placeInlineLeading(
            in bounds: CGRect,
            subviews: Subviews,
            cache: CacheData
        ) {
            var xOffset = bounds.minX
            let yOffset = bounds.minY

            for index in cache.primaryIndices {
                subviews[index].place(
                    at: CGPoint(x: xOffset, y: yOffset),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(cache.primaryButtonSize)
                )
                xOffset += cache.primaryButtonSize.width + horizontalSpacing
            }

            for index in cache.secondaryIndices {
                subviews[index].place(
                    at: CGPoint(x: xOffset, y: yOffset),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(cache.secondaryButtonSize)
                )
                xOffset += cache.secondaryButtonSize.width + horizontalSpacing
            }

            if !cache.overflowIndices.isEmpty {
                placeOverflowMenu(in: bounds, subviews: subviews, cache: cache, xOffset: xOffset, yOffset: yOffset)
            } else {
                hideOverflowMenu(in: bounds, subviews: subviews)
            }

            hideOverflowItems(in: bounds, subviews: subviews, cache: cache)
        }

        // MARK: - Place Inline Trailing

        private func placeInlineTrailing(
            in bounds: CGRect,
            subviews: Subviews,
            cache: CacheData
        ) {
            var xOffset = bounds.maxX
            let yOffset = bounds.minY

            if !cache.overflowIndices.isEmpty {
                xOffset -= cache.overflowButtonSize.width
                placeOverflowMenu(in: bounds, subviews: subviews, cache: cache, xOffset: xOffset, yOffset: yOffset)
                xOffset -= horizontalSpacing
            } else {
                hideOverflowMenu(in: bounds, subviews: subviews)
            }

            for index in cache.secondaryIndices.reversed() {
                xOffset -= cache.secondaryButtonSize.width
                subviews[index].place(
                    at: CGPoint(x: xOffset, y: yOffset),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(cache.secondaryButtonSize)
                )
                xOffset -= horizontalSpacing
            }

            for index in cache.primaryIndices.reversed() {
                xOffset -= cache.primaryButtonSize.width
                subviews[index].place(
                    at: CGPoint(x: xOffset, y: yOffset),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(cache.primaryButtonSize)
                )
                xOffset -= horizontalSpacing
            }

            hideOverflowItems(in: bounds, subviews: subviews, cache: cache)
        }

        // MARK: - Place Inline Space Between

        private func placeInlineSpaceBetween(
            in bounds: CGRect,
            subviews: Subviews,
            cache: CacheData
        ) {
            let yOffset = bounds.minY

            var leadingX = bounds.minX
            for index in cache.primaryIndices {
                subviews[index].place(
                    at: CGPoint(x: leadingX, y: yOffset),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(cache.primaryButtonSize)
                )
                leadingX += cache.primaryButtonSize.width + horizontalSpacing
            }

            var trailingX = bounds.maxX

            if !cache.overflowIndices.isEmpty {
                trailingX -= cache.overflowButtonSize.width
                placeOverflowMenu(in: bounds, subviews: subviews, cache: cache, xOffset: trailingX, yOffset: yOffset)
                trailingX -= horizontalSpacing
            } else {
                hideOverflowMenu(in: bounds, subviews: subviews)
            }

            for index in cache.secondaryIndices.reversed() {
                trailingX -= cache.secondaryButtonSize.width
                subviews[index].place(
                    at: CGPoint(x: trailingX, y: yOffset),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(cache.secondaryButtonSize)
                )
                trailingX -= horizontalSpacing
            }

            hideOverflowItems(in: bounds, subviews: subviews, cache: cache)
        }

        // MARK: - Place Overflow Menu

        private func placeOverflowMenu(
            in bounds: CGRect,
            subviews: Subviews,
            cache: CacheData,
            xOffset: CGFloat,
            yOffset: CGFloat
        ) {
            guard !cache.overflowIndices.isEmpty,
                  let overflowIndex = subviews.indices.last,
                  subviews[overflowIndex][OverflowMenuKey.self]
            else { return }

            subviews[overflowIndex].place(
                at: CGPoint(x: xOffset, y: yOffset),
                anchor: .topLeading,
                proposal: ProposedViewSize(cache.overflowButtonSize)
            )
        }

        // MARK: - Hide Overflow Items

        private func hideOverflowItems(
            in bounds: CGRect,
            subviews: Subviews,
            cache: CacheData
        ) {
            for index in cache.overflowIndices {
                subviews[index].place(
                    at: CGPoint(x: -10000, y: -10000),
                    anchor: .topLeading,
                    proposal: .zero
                )
            }
        }

        // MARK: - Hide Overflow Menu

        private func hideOverflowMenu(in bounds: CGRect, subviews: Subviews) {
            guard let overflowIndex = subviews.indices.last,
                  subviews[overflowIndex][OverflowMenuKey.self]
            else { return }

            subviews[overflowIndex].place(
                at: CGPoint(x: -10000, y: -10000),
                anchor: .topLeading,
                proposal: .zero
            )
        }

        // MARK: - Place Horizontal Subviews

        private func placeHorizontalSubviews(
            in bounds: CGRect,
            subviews: Subviews,
            cache: CacheData
        ) {
            var yOffset = bounds.minY

            if !cache.primaryIndices.isEmpty {
                placeRow(
                    indices: cache.primaryIndices,
                    subviews: subviews,
                    buttonSize: cache.primaryButtonSize,
                    bounds: bounds,
                    yOffset: yOffset
                )
                yOffset += cache.primaryButtonSize.height + verticalSpacing
            }

            if !cache.secondaryIndices.isEmpty || !cache.overflowIndices.isEmpty {
                placeSecondaryRowWithOverflow(
                    secondaryIndices: cache.secondaryIndices,
                    subviews: subviews,
                    secondarySize: cache.secondaryButtonSize,
                    overflowSize: cache.overflowButtonSize,
                    bounds: bounds,
                    yOffset: yOffset,
                    hasOverflow: !cache.overflowIndices.isEmpty
                )
                hideOverflowItems(in: bounds, subviews: subviews, cache: cache)
            } else {
                hideOverflowMenu(in: bounds, subviews: subviews)
            }
        }

        // MARK: - Place Secondary Row With Overflow

        private func placeSecondaryRowWithOverflow(
            secondaryIndices: [Int],
            subviews: Subviews,
            secondarySize: CGSize,
            overflowSize: CGSize,
            bounds: CGRect,
            yOffset: CGFloat,
            hasOverflow: Bool
        ) {
            var xOffset = bounds.minX

            for index in secondaryIndices {
                subviews[index].place(
                    at: CGPoint(x: xOffset, y: yOffset),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(secondarySize)
                )
                xOffset += secondarySize.width + horizontalSpacing
            }

            if hasOverflow,
               let overflowMenuIndex = subviews.indices.last,
               subviews[overflowMenuIndex][OverflowMenuKey.self]
            {
                subviews[overflowMenuIndex].place(
                    at: CGPoint(x: xOffset, y: yOffset),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(overflowSize)
                )
            } else {
                hideOverflowMenu(in: bounds, subviews: subviews)
            }
        }

        // MARK: - Place Vertical Subviews

        private func placeVerticalSubviews(
            in bounds: CGRect,
            subviews: Subviews,
            cache: CacheData
        ) {
            var yOffset = bounds.minY

            let allVisible = cache.primaryIndices + cache.secondaryIndices
            for index in allVisible {
                let size: CGSize
                if cache.primaryIndices.contains(index) {
                    size = cache.primaryButtonSize
                } else {
                    size = cache.secondaryButtonSize
                }

                let xOffset = bounds.minX + (bounds.width - size.width) / 2

                subviews[index].place(
                    at: CGPoint(x: xOffset, y: yOffset),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )

                yOffset += size.height + verticalSpacing
            }

            if !cache.overflowIndices.isEmpty,
               let overflowMenuIndex = subviews.indices.last,
               subviews[overflowMenuIndex][OverflowMenuKey.self]
            {
                let xOffset = bounds.minX + (bounds.width - cache.overflowButtonSize.width) / 2
                subviews[overflowMenuIndex].place(
                    at: CGPoint(x: xOffset, y: yOffset),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(cache.overflowButtonSize)
                )
                hideOverflowItems(in: bounds, subviews: subviews, cache: cache)
            } else {
                hideOverflowMenu(in: bounds, subviews: subviews)
            }
        }

        // MARK: - Place Row

        private func placeRow(
            indices: [Int],
            subviews: Subviews,
            buttonSize: CGSize,
            bounds: CGRect,
            yOffset: CGFloat
        ) {
            var xOffset = bounds.minX

            for index in indices {
                subviews[index].place(
                    at: CGPoint(x: xOffset, y: yOffset),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(buttonSize)
                )
                xOffset += buttonSize.width + horizontalSpacing
            }
        }

        // MARK: - Calculate Horizontal Layout

        private func calculateHorizontalLayout(
            subviews: Subviews,
            availableWidth: CGFloat
        ) -> CacheData {
            guard !subviews.isEmpty else {
                return emptyCacheData()
            }

            let totalCount = subviews.count
            let hasOverflowMenu = subviews.last?[OverflowMenuKey.self] == true
            let buttonCount = hasOverflowMenu ? totalCount - 1 : totalCount

            guard buttonCount > 0 else {
                return emptyCacheData()
            }

            let minSecondaryWidth = secondaryButtonConstraints.minWidth ?? buttonHeight
            let secondaryCount = buttonCount - 1

            let primaryIndices: [Int] = [0]
            var secondaryIndices: [Int] = []
            var overflowIndices: [Int] = []

            let primaryWidth = primaryButtonConstraints.resolve(
                availableWidth: availableWidth,
                fallback: availableWidth
            )

            if secondaryCount == 0 {
                return CacheData(
                    primaryIndices: primaryIndices,
                    secondaryIndices: [],
                    overflowIndices: [],
                    primaryButtonSize: CGSize(width: primaryWidth, height: buttonHeight),
                    secondaryButtonSize: CGSize(width: minSecondaryWidth, height: buttonHeight),
                    overflowButtonSize: CGSize(width: overflowButtonWidth, height: buttonHeight),
                    totalSize: CGSize(width: availableWidth, height: buttonHeight)
                )
            }

            let row2FitsAll = canFitButtons(
                count: secondaryCount,
                availableWidth: availableWidth,
                minButtonWidth: minSecondaryWidth,
                reserveOverflow: false
            )

            if row2FitsAll {
                secondaryIndices = Array(1 ... secondaryCount)
                let secondaryButtonWidth = calculateExpandedButtonWidth(
                    count: secondaryCount,
                    availableWidth: availableWidth
                )

                return CacheData(
                    primaryIndices: primaryIndices,
                    secondaryIndices: secondaryIndices,
                    overflowIndices: [],
                    primaryButtonSize: CGSize(width: primaryWidth, height: buttonHeight),
                    secondaryButtonSize: CGSize(width: secondaryButtonWidth, height: buttonHeight),
                    overflowButtonSize: CGSize(width: overflowButtonWidth, height: buttonHeight),
                    totalSize: CGSize(width: availableWidth, height: buttonHeight + verticalSpacing + buttonHeight)
                )
            }

            let row2Fitting = calculateRow2Fitting(
                availableWidth: availableWidth,
                minButtonWidth: minSecondaryWidth,
                count: secondaryCount,
                reserveOverflow: true
            )

            if row2Fitting > 0 {
                secondaryIndices = Array(1 ... row2Fitting)
            }

            if row2Fitting < secondaryCount {
                overflowIndices = Array((row2Fitting + 1) ... secondaryCount)
            }

            let secondaryButtonWidth = calculateExpandedButtonWidth(
                count: row2Fitting,
                availableWidth: availableWidth - overflowButtonWidth - horizontalSpacing
            )

            return CacheData(
                primaryIndices: primaryIndices,
                secondaryIndices: secondaryIndices,
                overflowIndices: overflowIndices,
                primaryButtonSize: CGSize(width: primaryWidth, height: buttonHeight),
                secondaryButtonSize: CGSize(width: secondaryButtonWidth, height: buttonHeight),
                overflowButtonSize: CGSize(width: overflowButtonWidth, height: buttonHeight),
                totalSize: CGSize(width: availableWidth, height: buttonHeight + verticalSpacing + buttonHeight)
            )
        }

        // MARK: - Can Fit Buttons

        private func canFitButtons(
            count: Int,
            availableWidth: CGFloat,
            minButtonWidth: CGFloat,
            reserveOverflow: Bool
        ) -> Bool {
            guard count > 0 else { return true }

            let overflowReserved = reserveOverflow ? (overflowButtonWidth + horizontalSpacing) : 0
            let availableForButtons = availableWidth - overflowReserved
            let neededWidth = minButtonWidth * CGFloat(count) +
                horizontalSpacing * CGFloat(max(0, count - 1))

            return neededWidth <= availableForButtons
        }

        // MARK: - Calculate Expanded Button Width

        private func calculateExpandedButtonWidth(
            count: Int,
            availableWidth: CGFloat
        ) -> CGFloat {
            guard count > 0 else { return buttonHeight }
            let totalSpacing = horizontalSpacing * CGFloat(max(0, count - 1))
            return (availableWidth - totalSpacing) / CGFloat(count)
        }

        // MARK: - Calculate Row 2 Fitting

        private func calculateRow2Fitting(
            availableWidth: CGFloat,
            minButtonWidth: CGFloat,
            count: Int,
            reserveOverflow: Bool
        ) -> Int {
            guard count > 0 else { return 0 }

            let overflowReserved = reserveOverflow ? (overflowButtonWidth + horizontalSpacing) : 0
            let availableForButtons = availableWidth - overflowReserved

            for tryCount in (1 ... count).reversed() {
                let neededWidth = minButtonWidth * CGFloat(tryCount) +
                    horizontalSpacing * CGFloat(max(0, tryCount - 1))

                if neededWidth <= availableForButtons {
                    return tryCount
                }
            }

            return 0
        }

        // MARK: - Calculate Vertical Layout

        private func calculateVerticalLayout(
            subviews: Subviews,
            availableWidth: CGFloat
        ) -> CacheData {
            guard !subviews.isEmpty else {
                return emptyCacheData()
            }

            let totalCount = subviews.count
            let hasOverflowMenu = subviews.last?[OverflowMenuKey.self] == true
            let buttonCount = hasOverflowMenu ? totalCount - 1 : totalCount

            guard buttonCount > 0 else {
                return emptyCacheData()
            }

            let primaryIndices = [0]
            let secondaryIndices = buttonCount > 1 ? Array(1 ..< buttonCount) : []
            let overflowIndices: [Int] = []

            let primaryWidth = primaryButtonConstraints.resolve(
                availableWidth: availableWidth,
                fallback: availableWidth
            )
            let secondaryWidth = secondaryButtonConstraints.resolve(
                availableWidth: availableWidth,
                fallback: availableWidth
            )

            let primarySize = CGSize(width: primaryWidth, height: buttonHeight)
            let secondarySize = CGSize(width: secondaryWidth, height: buttonHeight)
            let overflowSize = CGSize(width: availableWidth, height: buttonHeight)

            let rowCount = primaryIndices.count + secondaryIndices.count
            let totalHeight = buttonHeight * CGFloat(rowCount) + verticalSpacing * CGFloat(max(0, rowCount - 1))

            return CacheData(
                primaryIndices: primaryIndices,
                secondaryIndices: secondaryIndices,
                overflowIndices: overflowIndices,
                primaryButtonSize: primarySize,
                secondaryButtonSize: secondarySize,
                overflowButtonSize: overflowSize,
                totalSize: CGSize(width: availableWidth, height: totalHeight)
            )
        }

        // MARK: - Empty Cache Data

        private func emptyCacheData() -> CacheData {
            CacheData(
                primaryIndices: [],
                secondaryIndices: [],
                overflowIndices: [],
                primaryButtonSize: .zero,
                secondaryButtonSize: .zero,
                overflowButtonSize: .zero,
                totalSize: .zero
            )
        }
    }

    // MARK: - Overflow Menu Key

    struct OverflowMenuKey: LayoutValueKey {
        static let defaultValue: Bool = false
    }
}

extension View {

    func isOverflowMenu(_ value: Bool = true) -> some View {
        layoutValue(key: ItemView.OverflowMenuKey.self, value: value)
    }
}
