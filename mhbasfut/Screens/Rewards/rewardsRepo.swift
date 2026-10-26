//
//  rewardsRepo.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import Foundation

// MARK: - Shop catalog (shared by ViewModel + sheet, single source of truth)

/// Shop categories. Titles and icons match the sheet tabs.
public enum RewardShopCategory: String, CaseIterable, Identifiable {
    case pelo, camiseta, pantalon, botas, tonoPiel

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .pelo: return "Pelo"
        case .camiseta: return "Camiseta"
        case .pantalon: return "Pantalón"
        case .botas: return "Botas"
        case .tonoPiel: return "Tono de piel"
        }
    }

    public var iconName: String {
        switch self {
        case .pelo: return "person.crop.circle"
        case .camiseta: return "tshirt.fill"
        case .pantalon: return "figure.stand"
        case .botas: return "shoe.fill"
        case .tonoPiel: return "face.smiling"
        }
    }
}

/// One purchasable item. Six per category ("<Título> 1…6"),
/// priced 100, 150, … 350 — the same prices the sheet always displayed.
public struct RewardShopItem: Identifiable, Equatable {
    public let category: RewardShopCategory
    public let index: Int

    public var id: String { "\(category.rawValue).\(index)" }
    public var name: String { "\(category.title) \(index + 1)" }
    public var price: Int { 100 + index * 50 }

    public init(category: RewardShopCategory, index: Int) {
        self.category = category
        self.index = index
    }

    public static func items(for category: RewardShopCategory) -> [RewardShopItem] {
        (0..<6).map { RewardShopItem(category: category, index: $0) }
    }
}

protocol RewardsRepository {
    func getCoins() async -> Int
    func setCoins(_ coins: Int) async
    func addCoins(_ amount: Int) async
    func getLevel() async -> Int
    func getCharacterName() async -> String
    func setCharacterName(_ name: String) async
    func getOwnedItemIDs() async -> Set<String>
    func setOwnedItemIDs(_ ids: Set<String>) async
    func getEquippedItemIndex(for category: String) async -> Int?
    func setEquippedItemIndex(_ index: Int?, for category: String) async
}

actor MockRewardsRepo: RewardsRepository {
    private var coins: Int = 500
    private var level: Int = 0
    private var characterName: String = "CharacterName"
    private var ownedItemIDs: Set<String> = []
    private var equippedItems: [String: Int] = [:]

    func getCoins() async -> Int {
        try? await Task.sleep(nanoseconds: 50_000_000)
        return coins
    }

    func setCoins(_ coins: Int) async {
        self.coins = max(0, coins)
    }

    func addCoins(_ amount: Int) async {
        self.coins = max(0, self.coins + amount)
    }

    func getLevel() async -> Int {
        try? await Task.sleep(nanoseconds: 30_000_000)
        return level
    }

    func getCharacterName() async -> String {
        try? await Task.sleep(nanoseconds: 30_000_000)
        return characterName
    }

    func setCharacterName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            characterName = trimmed
        }
    }

    func getOwnedItemIDs() async -> Set<String> {
        ownedItemIDs
    }

    func setOwnedItemIDs(_ ids: Set<String>) async {
        ownedItemIDs = ids
    }

    func getEquippedItemIndex(for category: String) async -> Int? {
        equippedItems[category]
    }

    func setEquippedItemIndex(_ index: Int?, for category: String) async {
        equippedItems[category] = index
    }
}

actor UserDefaultsRewardsRepo: RewardsRepository {
    private let coinsKey = "rewards.coins"
    private let levelKey = "rewards.level"
    private let nameKey = "rewards.characterName"
    private let ownedKey = "rewards.ownedItems"
    private let equippedKeyPrefix = "rewards.equipped."

    func getCoins() async -> Int {
        if UserDefaults.standard.object(forKey: coinsKey) == nil { return 500 }
        return UserDefaults.standard.integer(forKey: coinsKey)
    }

    func setCoins(_ coins: Int) async {
        UserDefaults.standard.set(max(0, coins), forKey: coinsKey)
    }

    func addCoins(_ amount: Int) async {
        let current = await getCoins()
        await setCoins(current + amount)
    }

    func getLevel() async -> Int {
        if UserDefaults.standard.object(forKey: levelKey) == nil { return 0 }
        return UserDefaults.standard.integer(forKey: levelKey)
    }

    func getCharacterName() async -> String {
        if let name = UserDefaults.standard.string(forKey: nameKey) { return name }
        return "CharacterName"
    }

    func setCharacterName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.set(trimmed, forKey: nameKey)
    }

    func getOwnedItemIDs() async -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: ownedKey) ?? [])
    }

    func setOwnedItemIDs(_ ids: Set<String>) async {
        UserDefaults.standard.set(Array(ids), forKey: ownedKey)
    }

    func getEquippedItemIndex(for category: String) async -> Int? {
        let key = equippedKeyPrefix + category
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        return UserDefaults.standard.integer(forKey: key)
    }

    func setEquippedItemIndex(_ index: Int?, for category: String) async {
        let key = equippedKeyPrefix + category
        if let index {
            UserDefaults.standard.set(index, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
