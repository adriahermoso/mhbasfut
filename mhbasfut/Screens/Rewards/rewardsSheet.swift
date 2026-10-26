//
//  RewardsSheetView.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import SwiftUI

struct RewardsSheetView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: RewardsViewModel

    init(viewModel: RewardsViewModel) {
        self.viewModel = viewModel
    }

    @State private var selectedCategory: RewardShopCategory = .pelo

    // MARK: - Colors
    private let backgroundColor = Color(red: 28/255, green: 38/255, blue: 43/255)
    private let textColor = Color(red: 230/255, green: 235/255, blue: 238/255)
    private let skyBlue = Color(red: 52/255, green: 172/255, blue: 231/255)
    private let grassGreen = Color(red: 46/255, green: 158/255, blue: 30/255)
    private let levelGreen = Color(red: 0.55, green: 0.82, blue: 0.18)
    private let coinYellow = Color(red: 0.97, green: 0.72, blue: 0.0)

    var body: some View {
        ZStack(alignment: .top) {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                
                // MARK: - 1. Top Banners
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 0) {
                        skyBlue
                            .frame(height: 220)
                        grassGreen
                            .frame(height: 32)
                    }

                    // Close button
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel("Cerrar")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                }

                // MARK: - 2. Character Info
                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.characterName)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    // Chips
                    HStack(spacing: 16) {
                        Text("Nivel \(viewModel.level)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(levelGreen)
                            .clipShape(Capsule())

                        Text("\(viewModel.coins) Monedas")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(coinYellow)
                            .clipShape(Capsule())
                    }

                    // Owned / equipped summary (derived, always in sync)
                    Text("\(viewModel.ownedItemIDs.count) objetos · \(viewModel.equippedItems.count) equipados")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // MARK: - 3. Tab Selector (Horizontal Scroll with uniform sizing)
                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        ScrollViewReader { scrollProxy in
                            HStack(spacing: 0) {
                                ForEach(RewardShopCategory.allCases) { category in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.22)) {
                                            selectedCategory = category
                                        }
                                        // Auto-scrolls to center the tab if it's partially hidden
                                        withAnimation(.easeInOut) {
                                            scrollProxy.scrollTo(category.id, anchor: .center)
                                        }
                                    }) {
                                        VStack(spacing: 0) {
                                            Text(category.title.uppercased())
                                                .font(.system(size: 13, weight: selectedCategory == category ? .heavy : .semibold))
                                                .kerning(0.6)
                                                .fixedSize(horizontal: true, vertical: false) // Forces text to never shrink
                                                .foregroundColor(selectedCategory == category ? .white : Color.white.opacity(0.45))
                                                .padding(.horizontal, 18)
                                                .padding(.top, 18) // Keeps the top breathing room
                                                .padding(.bottom, 8) // Reduces the gap before the indicator line
                                            
                                            // Selected indicator
                                            Rectangle()
                                                .fill(selectedCategory == category ? Color.white : Color.clear)
                                                .frame(height: 3)
                                                .padding(.horizontal, 8)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .id(category.id)
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                    }

                    // Baseline – thin line across the whole screen
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 1)
                }
                .padding(.top, 16)

                // MARK: - 4. Grid Content
                ScrollView(showsIndicators: false) {
                    categoryContent(for: selectedCategory)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                }
            }
        }
    }

    @ViewBuilder
    private func categoryContent(for category: RewardShopCategory) -> some View {
        let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(RewardShopItem.items(for: category)) { item in
                let owned = viewModel.isOwned(item)
                let equipped = viewModel.isEquipped(item)
                let affordable = viewModel.canAfford(item)

                Button(action: {
                    viewModel.buyOrEquip(item)
                }) {
                    VStack(spacing: 16) {
                        // Item Icon Container (gold ring when equipped)
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 72, height: 72)

                            Circle()
                                .stroke(equipped ? coinYellow : Color.clear, lineWidth: 3)
                                .frame(width: 72, height: 72)

                            Image(systemName: category.iconName)
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)

                        // Item Details + state
                        VStack(spacing: 6) {
                            Text(item.name)
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            if equipped {
                                Text("Equipado")
                                    .font(.system(.footnote, design: .rounded, weight: .heavy))
                                    .foregroundColor(levelGreen)
                            } else if owned {
                                Text("Equipar")
                                    .font(.system(.footnote, design: .rounded, weight: .heavy))
                                    .foregroundColor(.white)
                            } else {
                                Text("\(item.price) monedas")
                                    .font(.system(.footnote, design: .rounded, weight: .heavy))
                                    .foregroundColor(affordable ? coinYellow : Color.white.opacity(0.35))
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .opacity(!owned && !affordable ? 0.6 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(!affordable)
                .accessibilityLabel("\(item.name), \(equipped ? "equipado" : (owned ? "en propiedad, tócalo para equipar" : "\(item.price) monedas"))")
            }
        }
    }
}

#Preview {
    RewardsSheetView(viewModel: MainActor.assumeIsolated { RewardsViewModel() })
}
