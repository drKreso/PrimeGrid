//
//  PrimeGrid.swift
//  PrimeGrid
//
//  Created by Sean Swezey on 9/29/16.
//  Copyright © 2016 stable/kernel. All rights reserved.
//

import UIKit

protocol GridLayoutDelegate: class {
    func scaleForItem(inCollectionView collectionView: UICollectionView, withLayout layout: UICollectionViewLayout, atIndexPath indexPath: IndexPath) -> UInt
    func itemFlexibleDimension(inCollectionView collectionView: UICollectionView, withLayout layout: UICollectionViewLayout, fixedDimension: CGFloat) -> CGFloat
    func headerFlexibleDimension(inCollectionView collectionView: UICollectionView, withLayout layout: UICollectionViewLayout, fixedDimension: CGFloat) -> CGFloat
}

extension GridLayoutDelegate {
    func scaleForItem(inCollectionView collectionView: UICollectionView, withLayout layout: UICollectionViewLayout, atIndexPath indexPath: IndexPath) -> UInt {
        return 1
    }

    func itemFlexibleDimension(inCollectionView collectionView: UICollectionView, withLayout layout: UICollectionViewLayout, fixedDimension: CGFloat) -> CGFloat {
        return fixedDimension
    }

    func headerFlexibleDimension(inCollectionView collectionView: UICollectionView, withLayout layout: UICollectionViewLayout, fixedDimension: CGFloat) -> CGFloat {
        return 0
    }
}

class GridLayout: UICollectionViewLayout, GridLayoutDelegate {
    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: contentHeight)
    }

    var scrollDirection: UICollectionViewScrollDirection = .vertical
    var itemSpacing: CGFloat = 0
    var fixedDivisionCount: UInt {
        get {
            return UInt(intFixedDivisionCount)
        }
        set {
            intFixedDivisionCount = newValue == 0 ? 1 : Int(newValue)
        }
    }

    weak var delegate: GridLayoutDelegate?

    private var intFixedDivisionCount = 1
    private var contentWidth: CGFloat = 0
    private var contentHeight: CGFloat = 0
    private var itemFixedDimension: CGFloat = 0
    private var itemFlexibleDimension: CGFloat = 0

    private var sectionedItemGrid: Array<Array<Array<Bool>>> = []
    private var headerAttributesCache: Array<UICollectionViewLayoutAttributes> = []
    private var itemAttributesCache: Array<UICollectionViewLayoutAttributes> = []

    private typealias ItemFrame = (section: Int, flexibleIndex: Int, fixedIndex: Int, scale: Int)

    // MARK: - UICollectionView Layout

    override func prepare() {
        guard let collectionView = collectionView else { return }

        let fixedDimension: CGFloat
        if scrollDirection == .vertical {
            fixedDimension = collectionView.frame.width - (collectionView.contentInset.left + collectionView.contentInset.right)
            contentWidth = fixedDimension
        } else {
            fixedDimension = collectionView.frame.height - (collectionView.contentInset.top + collectionView.contentInset.bottom)
            contentHeight = fixedDimension
        }

        var additionalSectionSpacing: CGFloat = 0
        let headerFlexibleDimension = (delegate ?? self).headerFlexibleDimension(inCollectionView: collectionView, withLayout: self, fixedDimension: fixedDimension)

        itemFixedDimension = (fixedDimension - (CGFloat(fixedDivisionCount) * itemSpacing) + itemSpacing) / CGFloat(fixedDivisionCount)
        itemFlexibleDimension = (delegate ?? self).itemFlexibleDimension(inCollectionView: collectionView, withLayout: self, fixedDimension: itemFixedDimension)

        for section in 0 ..< collectionView.numberOfSections {
            let itemCount = collectionView.numberOfItems(inSection: section)

            // Calculate header attributes
            if headerFlexibleDimension > 0.0 && itemCount > 0 {
                if headerAttributesCache.count > 0 {
                    additionalSectionSpacing += itemSpacing
                }

                let frame: CGRect
                if scrollDirection == .vertical {
                    frame = CGRect(x: 0, y: additionalSectionSpacing, width: fixedDimension, height: headerFlexibleDimension)
                } else {
                    frame = CGRect(x: additionalSectionSpacing, y: 0, width: headerFlexibleDimension, height: fixedDimension)
                }
                let headerLayoutAttributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, with: IndexPath(item: 0, section: section))
                headerLayoutAttributes.frame = frame

                headerAttributesCache.append(headerLayoutAttributes)
                additionalSectionSpacing += headerFlexibleDimension + itemSpacing
            }

            // Calculate item attributes
            let sectionOffset = additionalSectionSpacing
            sectionedItemGrid.append([])

            var flexibleIndex = 0, fixedIndex = 0
            for item in 0 ..< itemCount {
                if fixedIndex == intFixedDivisionCount {
                    // Reached end of row in .vertical or column in .horizontal
                    fixedIndex = 0
                    flexibleIndex += 1
                }

                let itemIndexPath = IndexPath(item: item, section: section)
                let itemScale = indexableScale(forItemAt: itemIndexPath)
                let intendedFrame = ItemFrame(section, flexibleIndex, fixedIndex, itemScale)
                let (itemFrame, didFitInOriginalFrame) = nextAvailableFrame(startingAt: intendedFrame)

                reserveItemGrid(frame: itemFrame)
                let itemAttributes = layoutAttributes(for: itemIndexPath, at: itemFrame, with: sectionOffset)

                itemAttributesCache.append(itemAttributes)

                // Update variable dimension
                if scrollDirection == .vertical {
                    if itemAttributes.frame.maxY > contentHeight {
                        contentHeight = itemAttributes.frame.maxY
                    }
                    if itemAttributes.frame.maxY > additionalSectionSpacing {
                        additionalSectionSpacing = itemAttributes.frame.maxY
                    }
                } else {
                    // .horizontal
                    if itemAttributes.frame.maxX > contentWidth {
                        contentWidth = itemAttributes.frame.maxX
                    }
                    if itemAttributes.frame.maxX > additionalSectionSpacing {
                        additionalSectionSpacing = itemAttributes.frame.maxX
                    }
                }

                if (didFitInOriginalFrame) {
                    fixedIndex += 1
                }
            }
        }
        sectionedItemGrid = [] // Only used during prepare, free up some memory
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let headerAttributes = headerAttributesCache.filter {
            $0.frame.intersects(rect)
        }
        let itemAttributes = itemAttributesCache.filter {
            $0.frame.intersects(rect)
        }

        return headerAttributes + itemAttributes
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return itemAttributesCache.first {
            $0.indexPath == indexPath
        }
    }

    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard elementKind == UICollectionElementKindSectionHeader else { return nil }

        return headerAttributesCache.first {
            $0.indexPath == indexPath
        }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        if scrollDirection == .vertical, let oldWidth = collectionView?.bounds.width {
            return oldWidth != newBounds.width
        } else if scrollDirection == .horizontal, let oldHeight = collectionView?.bounds.height {
            return oldHeight != newBounds.height
        }

        return false
    }

    override func invalidateLayout() {
        super.invalidateLayout()

        itemAttributesCache = []
        headerAttributesCache = []
        contentWidth = 0
        contentHeight = 0
    }

    // MARK: - Private

    private func indexableScale(forItemAt indexPath: IndexPath) -> Int {
        var itemScale = (delegate ?? self).scaleForItem(inCollectionView: collectionView!, withLayout: self, atIndexPath: indexPath)
        if itemScale > fixedDivisionCount {
            itemScale = fixedDivisionCount
        }
        return Int(itemScale - 1) // Using with indices, want 0-based
    }

    private func nextAvailableFrame(startingAt originalFrame: ItemFrame) -> (frame: ItemFrame, fitInOriginalFrame: Bool) {
        var flexibleIndex = originalFrame.flexibleIndex, fixedIndex = originalFrame.fixedIndex
        var newFrame = ItemFrame(originalFrame.section, flexibleIndex, fixedIndex, originalFrame.scale)
        while !isSpaceAvailable(for: newFrame) {
            fixedIndex += 1

            // Reached end of fixedIndex, restart on next flexibleIndex
            if fixedIndex == intFixedDivisionCount || fixedIndex + originalFrame.scale == intFixedDivisionCount {
                fixedIndex = 0
                flexibleIndex += 1
            }

            newFrame = ItemFrame(originalFrame.section, flexibleIndex, fixedIndex, originalFrame.scale)
        }

        return (newFrame, flexibleIndex == originalFrame.flexibleIndex && fixedIndex == originalFrame.fixedIndex)
    }

    private func isSpaceAvailable(for frame: ItemFrame) -> Bool {
        for flexibleIndex in frame.flexibleIndex ... frame.flexibleIndex + frame.scale {
            // Ensure we won't get off the end of the array
            while sectionedItemGrid[frame.section].count <= flexibleIndex {
                sectionedItemGrid[frame.section].append(Array(repeating: false, count: intFixedDivisionCount))
            }

            for fixedIndex in frame.fixedIndex ... frame.fixedIndex + frame.scale {
                if fixedIndex >= intFixedDivisionCount || sectionedItemGrid[frame.section][flexibleIndex][fixedIndex] {
                    return false
                }
            }
        }

        return true
    }

    private func reserveItemGrid(frame: ItemFrame) {
        for flexibleIndex in frame.flexibleIndex ... frame.flexibleIndex + frame.scale {
            for fixedIndex in frame.fixedIndex ... frame.fixedIndex + frame.scale {
                sectionedItemGrid[frame.section][flexibleIndex][fixedIndex] = true
            }
        }
    }

    private func layoutAttributes(for indexPath: IndexPath, at itemFrame: ItemFrame, with sectionOffset: CGFloat) -> UICollectionViewLayoutAttributes {
        let layoutAttributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)

        let fixedIndexOffset = CGFloat(itemFrame.fixedIndex) * (itemSpacing + itemFixedDimension)
        let longitudinalOffset = CGFloat(itemFrame.flexibleIndex) * (itemSpacing + itemFlexibleDimension) + sectionOffset
        let itemScaledTransverseDimension = itemFixedDimension + (CGFloat(itemFrame.scale) * (itemSpacing + itemFixedDimension))
        let itemScaledLongitudinalDimension = itemFlexibleDimension + (CGFloat(itemFrame.scale) * (itemSpacing + itemFlexibleDimension))

        if scrollDirection == .vertical {
            layoutAttributes.frame = CGRect(x: fixedIndexOffset, y: longitudinalOffset, width: itemScaledTransverseDimension, height: itemScaledLongitudinalDimension)
        } else {
            layoutAttributes.frame = CGRect(x: longitudinalOffset, y: fixedIndexOffset, width: itemScaledLongitudinalDimension, height: itemScaledTransverseDimension)
        }

        return layoutAttributes
    }
}
