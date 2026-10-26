//
//  rewardsViewmodel.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import Foundation
import Combine

@MainActor
class RewardsViewModel: ObservableObject {
    @Published var coins: Int = 500
    @Published var level: Int = 0
    @Published var characterName: String = "CharacterName"
    @Published var ownedItemIDs: Set<String> = []
    @Published var equippedItems: [String: Int] = [:]

    private let repo: RewardsRepository

    init(repo: RewardsRepository = UserDefaultsRewardsRepo()) {
        self.repo = repo
        Task { await load() }
    }

    func load() async {
        async let fetchedCoins = repo.getCoins()
        async let fetchedLevel = repo.getLevel()
        async let fetchedName = repo.getCharacterName()
        async let fetchedOwned = repo.getOwnedItemIDs()
        coins = await fetchedCoins
        level = await fetchedLevel
        characterName = await fetchedName
        ownedItemIDs = await fetchedOwned
        var equipped: [String: Int] = [:]
        for category in RewardShopCategory.allCases {
            if let index = await repo.getEquippedItemIndex(for: category.rawValue) {
                equipped[category.rawValue] = index
            }
        }
        equippedItems = equipped
    }

    func setCoins(_ newValue: Int) {
        coins = max(0, newValue)
        Task { await repo.setCoins(coins) }
    }

    func addCoins(_ amount: Int) {
        coins = max(0, coins + amount)
        Task { await repo.addCoins(amount) }
    }

    func setCharacterName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        characterName = trimmed
        Task { await repo.setCharacterName(trimmed) }
    }

    // MARK: - Shop: buy / equip

    func isOwned(_ item: RewardShopItem) -> Bool {
        ownedItemIDs.contains(item.id)
    }

    func isEquipped(_ item: RewardShopItem) -> Bool {
        equippedItems[item.category.rawValue] == item.index
    }

    func canAfford(_ item: RewardShopItem) -> Bool {
        isOwned(item) || coins >= item.price
    }

    /// Owned item → equip. Affordable new item → deduct coins, own + equip.
    /// Unaffordable items are ignored. State persists via the repository.
    func buyOrEquip(_ item: RewardShopItem) {
        if isOwned(item) {
            equippedItems[item.category.rawValue] = item.index
            let key = item.category.rawValue
            let index = item.index
            Task { await repo.setEquippedItemIndex(index, for: key) }
            return
        }
        guard coins >= item.price else { return }
        coins -= item.price
        ownedItemIDs.insert(item.id)
        equippedItems[item.category.rawValue] = item.index
        let snapshotCoins = coins
        let snapshotOwned = ownedItemIDs
        let key = item.category.rawValue
        let index = item.index
        Task {
            await repo.setCoins(snapshotCoins)
            await repo.setOwnedItemIDs(snapshotOwned)
            await repo.setEquippedItemIndex(index, for: key)
        }
    }

    func refresh() {
        Task { await load() }
    }
}
