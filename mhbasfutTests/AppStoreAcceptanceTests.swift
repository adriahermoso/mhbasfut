//
//  AppStoreAcceptanceTests.swift
//  mhbasfutTests
//
//  Plan 3 – acceptance tests for App Store readiness:
//  rewards shop persistence, settings preferences, privacy manifest,
//  and "already rated" skip logic.
//  Requires the mhbasfutTests unit-test target (host: mhbasfut app).
//

import XCTest
@testable import mhbasfut

final class AppStoreAcceptanceTests: XCTestCase {

    // MARK: - Key stash / restore (never pollute production data)

    private var stash: [String: Any] = [:]
    private let keys = [
        "rewards.coins", "rewards.characterName",
        "rewards.ownedItems",
        "rewards.equipped.pelo", "rewards.equipped.camiseta",
        "settings.remindersEnabled", "settings.soundEnabled",
        "settings.accent", "settings.language",
        TrainingPreferences.showObjectivesKey,
        TrainingPreferences.confirmCompleteKey,
        WellnessRepo.sleepHistoryKey,
        WellnessRepo.emotionHistoryKey,
    ]

    override func setUp() {
        super.setUp()
        stash = [:]
        for key in keys + ["plan.intensity.14.10"] {
            if let value = UserDefaults.standard.object(forKey: key) {
                stash[key] = value
            }
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in keys + ["plan.intensity.14.10"] {
            if let value = stash[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    // MARK: - Step 1: privacy manifest is bundled

    func testPrivacyManifestIsBundled() {
        XCTAssertNotNil(
            Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
            "PrivacyInfo.xcprivacy must be a member of the app target (Copy Bundle Resources)."
        )
    }

    // MARK: - Step 2: rewards shop catalog + purchase persistence

    func testShopCatalogPrices() {
        for category in RewardShopCategory.allCases {
            let items = RewardShopItem.items(for: category)
            XCTAssertEqual(items.count, 6, "\(category.rawValue)")
            XCTAssertEqual(items.map(\.price), [100, 150, 200, 250, 300, 350])
        }
    }

    func testOwnedAndEquippedRoundTrip() async {
        let repo = UserDefaultsRewardsRepo()
        let owned0 = await repo.getOwnedItemIDs()
        XCTAssertEqual(owned0, [])
        await repo.setOwnedItemIDs(["pelo.0", "botas.2"])
        let owned1 = await repo.getOwnedItemIDs()
        XCTAssertEqual(owned1, ["pelo.0", "botas.2"])
        let equippedPeloNil = await repo.getEquippedItemIndex(for: "pelo")
        XCTAssertNil(equippedPeloNil)
        await repo.setEquippedItemIndex(0, for: "pelo")
        let equippedPelo = await repo.getEquippedItemIndex(for: "pelo")
        XCTAssertEqual(equippedPelo, 0)
    }

    func testBuyDeductsCoinsAndPersists() async {
        let repo = UserDefaultsRewardsRepo()
        await MainActor.run {
            let viewModel = RewardsViewModel(repo: repo)
            // Default 500 coins: Pelo 1 (100) is affordable.
            viewModel.buyOrEquip(RewardShopItem(category: .pelo, index: 0))
            XCTAssertTrue(viewModel.isOwned(RewardShopItem(category: .pelo, index: 0)))
            XCTAssertTrue(viewModel.isEquipped(RewardShopItem(category: .pelo, index: 0)))
            XCTAssertEqual(viewModel.coins, 400)
        }
        // Flush the ViewModel's fire-and-forget persistence tasks.
        try? await Task.sleep(nanoseconds: 500_000_000)
        let coins = await repo.getCoins()
        XCTAssertEqual(coins, 400)
        let owned = await repo.getOwnedItemIDs()
        XCTAssertTrue(owned.contains("pelo.0"))
        let equippedPelo = await repo.getEquippedItemIndex(for: "pelo")
        XCTAssertEqual(equippedPelo, 0)
    }

    func testUnaffordableItemIsIgnored() async {
        let repo = UserDefaultsRewardsRepo()
        await repo.setCoins(50)
        await MainActor.run {
            let viewModel = RewardsViewModel(repo: repo)
            // Sneakers 6 costs 350: ignored, coins untouched.
            viewModel.coins = 50
            viewModel.buyOrEquip(RewardShopItem(category: .botas, index: 5))
            XCTAssertFalse(viewModel.isOwned(RewardShopItem(category: .botas, index: 5)))
            XCTAssertEqual(viewModel.coins, 50)
        }
    }

    func testCharacterNamePersists() async {
        let repo = UserDefaultsRewardsRepo()
        await repo.setCharacterName("  ")
        let blankName = await repo.getCharacterName()
        XCTAssertEqual(blankName, "CharacterName")
        await repo.setCharacterName("Nova Estrella")
        let name = await repo.getCharacterName()
        XCTAssertEqual(name, "Nova Estrella")
    }

    // MARK: - Step 2: training preferences + settings persistence

    func testTrainingPreferenceKeysRoundTrip() {
        UserDefaults.standard.set(false, forKey: TrainingPreferences.showObjectivesKey)
        UserDefaults.standard.set(true, forKey: TrainingPreferences.confirmCompleteKey)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: TrainingPreferences.showObjectivesKey))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: TrainingPreferences.confirmCompleteKey))
    }

    func testSettingsTogglesPersist() async {
        let repo = UserDefaultsSettingsRepo()
        await repo.setRemindersEnabled(false)
        await repo.setSoundEnabled(false)
        let remindersOff = await repo.getRemindersEnabled()
        let soundOff = await repo.getSoundEnabled()
        XCTAssertFalse(remindersOff)
        XCTAssertFalse(soundOff)
        await repo.setRemindersEnabled(true)
        await repo.setSoundEnabled(true)
        let remindersOn = await repo.getRemindersEnabled()
        let soundOn = await repo.getSoundEnabled()
        XCTAssertTrue(remindersOn)
        XCTAssertTrue(soundOn)
    }

    func testAccentAndLanguageDefaults() {
        // Untouched installs fall back to gold + Spanish.
        XCTAssertNil(UserDefaults.standard.string(forKey: AppAccent.storageKey))
        XCTAssertEqual(AppAccent.current, .dorado)
        XCTAssertEqual(AppLanguage.storageKey, "settings.language")
    }

    // MARK: - Skip logic ("already rated" never re-asks)

    func testIntensitySkipLogic() {
        let repo = PlanRepo.shared
        XCTAssertFalse(repo.hasIntensityRating(day: 14, stageIndex: 10))
        repo.saveIntensity(day: 14, stageIndex: 10, value: 6)
        XCTAssertTrue(repo.hasIntensityRating(day: 14, stageIndex: 10))
        XCTAssertEqual(repo.getIntensity(day: 14, stageIndex: 10), 6)
    }

    func testSleepAlreadyRatedToday() {
        XCTAssertFalse(WellnessRepo.hasSleepQuality(for: Date()))
        WellnessRepo.saveSleepQuality(rating: 1, date: Date())
        XCTAssertTrue(WellnessRepo.hasSleepQuality(for: Date()))
    }

    func testEmotionDueOnlyAfterThreeDays() {
        let calendar = Calendar.current
        let now = Date()
        UserDefaults.standard.removeObject(forKey: WellnessRepo.emotionHistoryKey)
        XCTAssertTrue(WellnessRepo.isEmotionDue(now: now))
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        WellnessRepo.saveEmotion(rating: 2, date: twoDaysAgo)
        XCTAssertFalse(WellnessRepo.isEmotionDue(now: now))
    }
}
