//
//  PitchProgressView.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 07/09/2026.
//

import SwiftUI
import UIKit

struct PitchProgressView: View {
    @ObservedObject var viewModel: PlanViewModel
    /// Selected sport ("Futbol" / "Basquet"). Drives background + ball art.
    var sport: String = "Futbol"

    private var isBasket: Bool { sport == "Basquet" }
    private var backgroundName: String { isBasket ? "basketball_court_background" : "soccer_pitch_background" }
    private var ballImageName: String { isBasket ? "ic_basquetball_ball" : "ic_football_ball" }

    // MARK: - Tunables
    // These are guesses at reasonable spacing/sizes — tune against the real background art.
    private let flagSpacing: CGFloat = 220
    private let horizontalPadding: CGFloat = 90
    private let flagSize: CGFloat = 44
    private let characterSize: CGFloat = 96
    private let ballSize: CGFloat = 28
    private let ballLeadOffset: CGFloat = 26   // how far ahead of the character the ball sits
    private let characterBackOffset: CGFloat = 44 // character stands slightly left of the flag
    private let groundInset: CGFloat = 120     // distance from bottom of the pitch area to the "ground line"
    private let flagYStagger: CGFloat = 90     // odd flags sit this much higher, like the reference image
    private let transitionDuration: Double = 0.6

    // MARK: - Scroll state
    @State private var scrollOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var hasCenteredInitially = false

    var body: some View {
        GeometryReader { outerGeo in
            let viewportWidth = outerGeo.size.width
            let viewportHeight = outerGeo.size.height
            let stageCount = max(viewModel.stages.count, 1)

            let contentWidth = max(
                viewportWidth * 1.4,
                horizontalPadding * 2 + CGFloat(max(stageCount - 1, 0)) * flagSpacing
            )
            let flagXPositions: [CGFloat] = (0..<stageCount).map {
                horizontalPadding + CGFloat($0) * flagSpacing
            }
            let groundY = viewportHeight - groundInset
            let minOffset = min(0, viewportWidth - contentWidth)
            let maxOffset: CGFloat = 0
            let currentIndex = min(viewModel.currentStageIndex, max(flagXPositions.count - 1, 0))
            let characterX = flagXPositions.isEmpty ? 0 : flagXPositions[currentIndex]
            // Zigzag depth: even flags low, odd flags higher — like the reference image.
            let flagYPositions: [CGFloat] = (0..<stageCount).map {
                groundY - CGFloat($0 % 2) * flagYStagger
            }
            let currentFlagY = flagYPositions.isEmpty ? groundY : flagYPositions[currentIndex]
            let characterCenterX = characterX - characterBackOffset

            ZStack(alignment: .topLeading) {
                courtBackground(width: contentWidth, height: viewportHeight)

                ForEach(Array(flagXPositions.enumerated()), id: \.offset) { index, x in
                    Image(flagImageName(for: index))
                        .resizable()
                        .scaledToFit()
                        .frame(width: flagSize, height: flagSize)
                        .position(x: x, y: flagYPositions[index])
                }

                if !flagXPositions.isEmpty {
                    Image(ballImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: ballSize, height: ballSize)
                        .position(x: characterCenterX + ballLeadOffset, y: currentFlagY + characterSize / 2 - ballSize / 2)
                        .animation(.easeInOut(duration: transitionDuration), value: viewModel.currentStageIndex)
                        // Swap ball art when the sport changes
                        .animation(.easeInOut(duration: transitionDuration), value: ballImageName)

                    Image("ic_character")
                        .resizable()
                        .scaledToFit()
                        .frame(width: characterSize, height: characterSize)
                        .position(x: characterCenterX, y: currentFlagY)
                        .animation(.easeInOut(duration: transitionDuration), value: viewModel.currentStageIndex)
                }
            }
            .frame(width: contentWidth, height: viewportHeight, alignment: .topLeading)
            .offset(x: scrollOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        scrollOffset = clamp(dragStartOffset + value.translation.width, minOffset, maxOffset)
                    }
                    .onEnded { _ in
                        dragStartOffset = scrollOffset
                    }
            )
            .onAppear {
                guard !hasCenteredInitially else { return }
                hasCenteredInitially = true
                scrollOffset = targetOffset(
                    for: characterX - characterBackOffset, viewportWidth: viewportWidth, minOffset: minOffset, maxOffset: maxOffset
                )
                dragStartOffset = scrollOffset
            }
            .onChange(of: viewModel.currentStageIndex) { _, newIndex in
                // Recompute from newIndex: the `characterX` let above is captured
                // from the pre-change render (stale), which made the camera jump
                // back toward the previous flag — i.e. opposite to the character.
                let clampedIndex = min(max(newIndex, 0), max(stageCount - 1, 0))
                let newCharacterX = horizontalPadding + CGFloat(clampedIndex) * flagSpacing - characterBackOffset
                withAnimation(.easeInOut(duration: transitionDuration)) {
                    scrollOffset = targetOffset(
                        for: newCharacterX, viewportWidth: viewportWidth, minOffset: minOffset, maxOffset: maxOffset
                    )
                }
                dragStartOffset = scrollOffset
            }
            .clipped()
        }
    }

    // MARK: - Helpers

    /// Court background. `soccer_pitch_background` is a regular imageset while
    /// `basketball_court_background` is a .dataset (webp), which SwiftUI's
    /// Image(named:) cannot see — so resolve through UIImage / NSDataAsset first.
    private func courtBackground(width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let uiImage = courtUIImage() {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(backgroundName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private func courtUIImage() -> UIImage? {
        if let img = UIImage(named: backgroundName) {
            return img
        }
        let base = backgroundName.hasSuffix(".webp")
            ? String(backgroundName.dropLast(".webp".count))
            : backgroundName
        if let asset = NSDataAsset(name: base), let img = UIImage(data: asset.data) {
            return img
        }
        if let asset = NSDataAsset(name: backgroundName), let img = UIImage(data: asset.data) {
            return img
        }
        return nil
    }

    /// `ic_flag` for the current stage and anything already completed, `ic_flag_disabled` for the rest.
    /// If you later want a distinct "current" look, swap this for a third asset name.
    private func flagImageName(for index: Int) -> String {
        let isCurrentOrDone = viewModel.completedStages.contains(index) || index == viewModel.currentStageIndex
        return isCurrentOrDone ? "ic_flag" : "ic_flag_disabled"
    }

    private func targetOffset(for characterX: CGFloat, viewportWidth: CGFloat, minOffset: CGFloat, maxOffset: CGFloat) -> CGFloat {
        clamp(viewportWidth / 2 - characterX, minOffset, maxOffset)
    }

    private func clamp(_ value: CGFloat, _ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minValue), maxValue)
    }
}
