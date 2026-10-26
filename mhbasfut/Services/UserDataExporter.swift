//
//  UserDataExporter.swift
//  mhbasfut
//
//  Plan Admin Data Sync – Paso 2.
//  Exportador puro y testeable: serializa TODO el estado persistido del
//  usuario (UserDefaults) en un único objeto JSON listo para subir a
//  `users/{username}.json` del repo adriahermoso/mhbasfut.
//  Reutiliza las claves de QuestionaryRepo, PlanRepo, WellnessRepo,
//  UserDefaultsStreakRepo, UserDefaultsRewardsRepo y Settings.
//

import Foundation

// MARK: - Snapshot Codable (1:1 con el JSON subido a GitHub)

public struct UserDataSnapshot: Equatable {

    enum CodingKeys: String, CodingKey {
        case schemaVersion, exportedAt, username, sport
        case questionnaireCompleted, questionnaireCompletedDate
        case questionnaireAnswers, questionnaireScore
        case assignedPlan, assignedPlanPerSport
        case planStartDate, currentDay, days
        case sleepHistory, emotionHistory
        case streakCompletedDates, streakCount
        case coins, level, characterName, ownedItems, equippedItems
        case remindersEnabled, soundEnabled, appVersion
        case cycleNumber, completedCycles, programCompleted, lastSport
        case planArchives, adminRevision
    }
    public var schemaVersion: Int
    public var exportedAt: Date
    public var username: String
    public var sport: String?
    public var questionnaireCompleted: Bool
    public var questionnaireCompletedDate: Date?
    public var questionnaireAnswers: [String: String]
    public var questionnaireScore: QuestionaryScore?
    public var assignedPlan: Int?
    public var assignedPlanPerSport: [String: Int]
    public var planStartDate: Date?
    public var currentDay: Int
    public var days: [DaySnapshot]
    public var sleepHistory: [WellnessRating]
    public var emotionHistory: [WellnessRating]
    public var streakCompletedDates: [Date]
    public var streakCount: Int
    public var coins: Int
    public var level: Int
    public var characterName: String
    public var ownedItems: [String]
    public var equippedItems: [String: Int]
    public var remindersEnabled: Bool?
    public var soundEnabled: Bool?
    public var appVersion: String?
    // Schema v2 — ciclo de 4 planes de 14 días + ediciones del panel admin.
    public var cycleNumber: Int
    public var completedCycles: Int
    public var programCompleted: Bool
    public var lastSport: String?
    public var planArchives: [PlanRepo.PlanCycleArchive]
    /// Última `adminRevision` aplicada desde el panel (eco para la web).
    public var adminRevision: String?

    public init(
        schemaVersion: Int = 2,
        exportedAt: Date = Date(),
        username: String,
        sport: String? = nil,
        questionnaireCompleted: Bool = false,
        questionnaireCompletedDate: Date? = nil,
        questionnaireAnswers: [String: String] = [:],
        questionnaireScore: QuestionaryScore? = nil,
        assignedPlan: Int? = nil,
        assignedPlanPerSport: [String: Int] = [:],
        planStartDate: Date? = nil,
        currentDay: Int = 1,
        days: [DaySnapshot] = [],
        sleepHistory: [WellnessRating] = [],
        emotionHistory: [WellnessRating] = [],
        streakCompletedDates: [Date] = [],
        streakCount: Int = 0,
        coins: Int = 500,
        level: Int = 0,
        characterName: String = "CharacterName",
        ownedItems: [String] = [],
        equippedItems: [String: Int] = [:],
        remindersEnabled: Bool? = nil,
        soundEnabled: Bool? = nil,
        appVersion: String? = nil,
        cycleNumber: Int = 1,
        completedCycles: Int = 0,
        programCompleted: Bool = false,
        lastSport: String? = nil,
        planArchives: [PlanRepo.PlanCycleArchive] = [],
        adminRevision: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.username = username
        self.sport = sport
        self.questionnaireCompleted = questionnaireCompleted
        self.questionnaireCompletedDate = questionnaireCompletedDate
        self.questionnaireAnswers = questionnaireAnswers
        self.questionnaireScore = questionnaireScore
        self.assignedPlan = assignedPlan
        self.assignedPlanPerSport = assignedPlanPerSport
        self.planStartDate = planStartDate
        self.currentDay = currentDay
        self.days = days
        self.sleepHistory = sleepHistory
        self.emotionHistory = emotionHistory
        self.streakCompletedDates = streakCompletedDates
        self.streakCount = streakCount
        self.coins = coins
        self.level = level
        self.characterName = characterName
        self.ownedItems = ownedItems
        self.equippedItems = equippedItems
        self.remindersEnabled = remindersEnabled
        self.soundEnabled = soundEnabled
        self.appVersion = appVersion
        self.cycleNumber = cycleNumber
        self.completedCycles = completedCycles
        self.programCompleted = programCompleted
        self.lastSport = lastSport
        self.planArchives = planArchives
        self.adminRevision = adminRevision
    }
}

extension UserDataSnapshot: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        exportedAt = try c.decode(Date.self, forKey: .exportedAt)
        username = try c.decode(String.self, forKey: .username)
        sport = try c.decodeIfPresent(String.self, forKey: .sport)
        questionnaireCompleted = try c.decode(Bool.self, forKey: .questionnaireCompleted)
        questionnaireCompletedDate = try c.decodeIfPresent(Date.self, forKey: .questionnaireCompletedDate)
        questionnaireAnswers = try c.decode([String: String].self, forKey: .questionnaireAnswers)
        questionnaireScore = try c.decodeIfPresent(QuestionaryScore.self, forKey: .questionnaireScore)
        assignedPlan = try c.decodeIfPresent(Int.self, forKey: .assignedPlan)
        assignedPlanPerSport = try c.decode([String: Int].self, forKey: .assignedPlanPerSport)
        planStartDate = try c.decodeIfPresent(Date.self, forKey: .planStartDate)
        currentDay = try c.decode(Int.self, forKey: .currentDay)
        days = try c.decode([DaySnapshot].self, forKey: .days)
        sleepHistory = try c.decode([WellnessRating].self, forKey: .sleepHistory)
        emotionHistory = try c.decode([WellnessRating].self, forKey: .emotionHistory)
        streakCompletedDates = try c.decode([Date].self, forKey: .streakCompletedDates)
        streakCount = try c.decode(Int.self, forKey: .streakCount)
        coins = try c.decode(Int.self, forKey: .coins)
        level = try c.decode(Int.self, forKey: .level)
        characterName = try c.decode(String.self, forKey: .characterName)
        ownedItems = try c.decode([String].self, forKey: .ownedItems)
        equippedItems = try c.decode([String: Int].self, forKey: .equippedItems)
        remindersEnabled = try c.decodeIfPresent(Bool.self, forKey: .remindersEnabled)
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled)
        appVersion = try c.decodeIfPresent(String.self, forKey: .appVersion)
        cycleNumber = try c.decodeIfPresent(Int.self, forKey: .cycleNumber) ?? 1
        completedCycles = try c.decodeIfPresent(Int.self, forKey: .completedCycles) ?? 0
        programCompleted = try c.decodeIfPresent(Bool.self, forKey: .programCompleted) ?? false
        lastSport = try c.decodeIfPresent(String.self, forKey: .lastSport)
        planArchives = try c.decodeIfPresent([PlanRepo.PlanCycleArchive].self, forKey: .planArchives) ?? []
        adminRevision = try c.decodeIfPresent(String.self, forKey: .adminRevision)
    }

    /// Codifica los opcionales con `encode(_:forKey:)` (no `encodeIfPresent`)
    /// para que el JSON tenga SIEMPRE el esquema fijo: los campos sin valor
    /// salen como `null` en vez de omitirse.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(exportedAt, forKey: .exportedAt)
        try c.encode(username, forKey: .username)
        try c.encode(sport, forKey: .sport)
        try c.encode(questionnaireCompleted, forKey: .questionnaireCompleted)
        try c.encode(questionnaireCompletedDate, forKey: .questionnaireCompletedDate)
        try c.encode(questionnaireAnswers, forKey: .questionnaireAnswers)
        try c.encode(questionnaireScore, forKey: .questionnaireScore)
        try c.encode(assignedPlan, forKey: .assignedPlan)
        try c.encode(assignedPlanPerSport, forKey: .assignedPlanPerSport)
        try c.encode(planStartDate, forKey: .planStartDate)
        try c.encode(currentDay, forKey: .currentDay)
        try c.encode(days, forKey: .days)
        try c.encode(sleepHistory, forKey: .sleepHistory)
        try c.encode(emotionHistory, forKey: .emotionHistory)
        try c.encode(streakCompletedDates, forKey: .streakCompletedDates)
        try c.encode(streakCount, forKey: .streakCount)
        try c.encode(coins, forKey: .coins)
        try c.encode(level, forKey: .level)
        try c.encode(characterName, forKey: .characterName)
        try c.encode(ownedItems, forKey: .ownedItems)
        try c.encode(equippedItems, forKey: .equippedItems)
        try c.encode(remindersEnabled, forKey: .remindersEnabled)
        try c.encode(soundEnabled, forKey: .soundEnabled)
        try c.encode(appVersion, forKey: .appVersion)
        try c.encode(cycleNumber, forKey: .cycleNumber)
        try c.encode(completedCycles, forKey: .completedCycles)
        try c.encode(programCompleted, forKey: .programCompleted)
        try c.encode(lastSport, forKey: .lastSport)
        try c.encode(planArchives, forKey: .planArchives)
        try c.encode(adminRevision, forKey: .adminRevision)
    }
}

public struct DaySnapshot: Codable, Equatable {
    public var day: Int
    public var completed: Bool
    public var completedStages: [Int]
    public var selectedMeals: [String: Int]
    public var intensities: [String: Int]

    public init(day: Int, completed: Bool = false, completedStages: [Int] = [], selectedMeals: [String: Int] = [:], intensities: [String: Int] = [:]) {
        self.day = day
        self.completed = completed
        self.completedStages = completedStages
        self.selectedMeals = selectedMeals
        self.intensities = intensities
    }
}

// MARK: - Exportador

public enum UserDataExporter {

    /// Construye el snapshot leyendo el UserDefaults real.
    /// `username` es la cuenta vinculada (fichero users/{username}.json).
    public static func build(username: String, defaults: UserDefaults = .standard) -> UserDataSnapshot {
        let qRepo = QuestionaryRepo()
        let planRepo = PlanRepo()

        let answers = qRepo.getSavedAnswers()
        let sport = qRepo.getSelectedSport()
        let completed = qRepo.isQuestionnaireCompleted()
        let score = qRepo.getSavedScore()

        let completedDate: Date? = {
            let ts = defaults.double(forKey: "questionary.completedDate")
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }()

        var perSport: [String: Int] = [:]
        for s in ["Futbol", "Basquet"] {
            if let n = qRepo.getAssignedPlan(forSport: s) { perSport[s] = n }
        }
        let assigned: Int? = {
            let sportKey = sport ?? planRepo.currentSport()
            return qRepo.getAssignedPlan(forSport: sportKey) ?? perSport[ sportKey ]
        }()

        let startTs = defaults.double(forKey: "plan.startDate")
        let startDate: Date? = startTs > 0 ? Date(timeIntervalSince1970: startTs) : nil
        let currentDay = planRepo.calculateCurrentDay()

        var days: [DaySnapshot] = []
        for d in 1...14 {
            let isDone = defaults.bool(forKey: "plan.dayCompleted.\(d)")
            let stages = (defaults.array(forKey: "plan.completedStages.\(d)") as? [Int] ?? []).sorted()
            var meals: [String: Int] = [:]
            for stage in 0...6 {
                let key = "plan.selectedMeal.\(d).\(stage)"
                if defaults.object(forKey: key) != nil {
                    meals["\(stage)"] = defaults.integer(forKey: key)
                }
            }
            var intensities: [String: Int] = [:]
            for stage in 0...10 {
                let key = "plan.intensity.\(d).\(stage)"
                if defaults.object(forKey: key) != nil {
                    intensities["\(stage)"] = min(max(defaults.integer(forKey: key), 0), 10)
                }
            }
            days.append(DaySnapshot(day: d, completed: isDone, completedStages: stages, selectedMeals: meals, intensities: intensities))
        }

        let sleep: [WellnessRating] = {
            guard let data = defaults.data(forKey: WellnessRepo.sleepHistoryKey),
                  let h = try? JSONDecoder().decode([WellnessRating].self, from: data) else { return [] }
            return h
        }()
        let emotion: [WellnessRating] = {
            guard let data = defaults.data(forKey: WellnessRepo.emotionHistoryKey),
                  let h = try? JSONDecoder().decode([WellnessRating].self, from: data) else { return [] }
            return h
        }()

        let streakDates: [Date] = {
            let arr = defaults.array(forKey: "streak.completedDates") as? [Double] ?? []
            return arr.map { Date(timeIntervalSince1970: $0) }.sorted()
        }()
        let streakCount = currentStreakCount(dates: streakDates)

        let coins: Int = defaults.object(forKey: "rewards.coins") == nil ? 500 : defaults.integer(forKey: "rewards.coins")
        let level: Int = defaults.object(forKey: "rewards.level") == nil ? 0 : defaults.integer(forKey: "rewards.level")
        let name: String = defaults.string(forKey: "rewards.characterName") ?? "CharacterName"
        let owned: [String] = (defaults.stringArray(forKey: "rewards.ownedItems") ?? []).sorted()
        var equipped: [String: Int] = [:]
        for cat in ["pelo", "camiseta", "pantalon", "botas", "tonoPiel"] {
            let key = "rewards.equipped.\(cat)"
            if defaults.object(forKey: key) != nil {
                equipped[cat] = defaults.integer(forKey: key)
            }
        }

        let reminders: Bool? = defaults.object(forKey: "settings.remindersEnabled") == nil ? nil : defaults.bool(forKey: "settings.remindersEnabled")
        let sound: Bool? = defaults.object(forKey: "settings.soundEnabled") == nil ? nil : defaults.bool(forKey: "settings.soundEnabled")
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

        let cycleNumber = planRepo.getCycleNumber()
        let completedCycles = planRepo.getCompletedCycles()
        let programCompleted = planRepo.isProgramCompleted()
        let lastSport = planRepo.getLastSport()
        let archives = planRepo.getArchives(defaults: defaults)
        let adminRevision = defaults.string(forKey: AdminOverrideApplier.lastAppliedRevisionKey)

        return UserDataSnapshot(
            username: username,
            sport: sport,
            questionnaireCompleted: completed,
            questionnaireCompletedDate: completedDate,
            questionnaireAnswers: answers,
            questionnaireScore: score,
            assignedPlan: assigned,
            assignedPlanPerSport: perSport,
            planStartDate: startDate,
            currentDay: currentDay,
            days: days,
            sleepHistory: sleep,
            emotionHistory: emotion,
            streakCompletedDates: streakDates,
            streakCount: streakCount,
            coins: coins,
            level: level,
            characterName: name,
            ownedItems: owned,
            equippedItems: equipped,
            remindersEnabled: reminders,
            soundEnabled: sound,
            appVersion: appVersion,
            cycleNumber: cycleNumber,
            completedCycles: completedCycles,
            programCompleted: programCompleted,
            lastSport: lastSport,
            planArchives: archives,
            adminRevision: adminRevision
        )
    }

    /// JSON listo para subir (claves ordenadas, fechas ISO8601).
    public static func jsonData(for snapshot: UserDataSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    // MARK: - Streak (misma regla que UserDefaultsStreakRepo, versión pura)

    public static func currentStreakCount(dates: [Date], now: Date = Date(), calendar: Calendar = Calendar.current) -> Int {
        guard !dates.isEmpty else { return 0 }
        let completed = Set(dates.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let start: Date
        if completed.contains(today) { start = today }
        else if completed.contains(yesterday) { start = yesterday }
        else { return 0 }
        var count = 0
        var cursor = start
        while completed.contains(cursor) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }
}
