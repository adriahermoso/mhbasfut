//
//  PlanRepo.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 02/09/2026.
//

import Foundation

// MARK: - Plan Decodable Data Models

public struct PlanFile: Codable {
    public let pla: String
    public let descripcio: String
    public let dies: [PlanDayData]
}

public struct PlanDayData: Codable {
    public let dia: Int
    public let titol: String
    public let tipus: String // "entrenament", "club", "recuperacio", "descans"
    public let esmorzar: PlanMealSection
    public let mig_mati: PlanMealSection
    public let entrenament: PlanTrainingSection?
    public let sessions: [PlanSessionData]?
    public let dinar: PlanMealSection
    public let berenar: PlanMealSection
    public let sopar: PlanMealSection
}

public struct PlanSessionData: Codable {
    public let hora: String?
    public let nom: String?
    public let contingut: [PlanExerciseData]?
    public let escalfament: [PlanExerciseData]?
    public let part_principal: [PlanExerciseData]?

    enum CodingKeys: String, CodingKey {
        case hora, nom, contingut, escalfament, part_principal
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hora = try c.decodeIfPresent(String.self, forKey: .hora)
        nom = try c.decodeIfPresent(String.self, forKey: .nom)
        contingut = try c.decodeIfPresent([PlanExerciseData].self, forKey: .contingut)
        part_principal = try c.decodeIfPresent([PlanExerciseData].self, forKey: .part_principal)
        // escalfament may be a String or an array — handle both
        if let arr = try? c.decodeIfPresent([PlanExerciseData].self, forKey: .escalfament) {
            escalfament = arr
        } else if let str = try? c.decodeIfPresent(String.self, forKey: .escalfament) {
            escalfament = [PlanExerciseData(exercici: str, series_repeticions: nil, descripcio: nil, imatge: nil)]
        } else {
            escalfament = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(hora, forKey: .hora)
        try c.encodeIfPresent(nom, forKey: .nom)
        try c.encodeIfPresent(contingut, forKey: .contingut)
        try c.encodeIfPresent(escalfament, forKey: .escalfament)
        try c.encodeIfPresent(part_principal, forKey: .part_principal)
    }
}

public struct PlanMealSection: Codable {
    public let opcions: [PlanMealOptionData]
}

public struct PlanMealOptionData: Codable {
    public let nom: String
    public let imatge: String
}

public struct PlanTrainingSection: Codable {
    public let nom: String?
    public let objectiu: String?
    public let nota: String?
    public let imatge: String?
    public let escalfament: [PlanExerciseData]?
    public let part_principal: [PlanExerciseData]?
    public let activitats: [PlanExerciseData]?
    public let forca: [PlanExerciseData]?
    public let pliometria: [PlanExerciseData]?

    enum CodingKeys: String, CodingKey {
        case nom, objectiu, nota, imatge
        case escalfament, part_principal, activitats, forca, pliometria
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nom = try c.decodeIfPresent(String.self, forKey: .nom)
        objectiu = try c.decodeIfPresent(String.self, forKey: .objectiu)
        nota = try c.decodeIfPresent(String.self, forKey: .nota)
        imatge = try c.decodeIfPresent(String.self, forKey: .imatge)
        activitats = try c.decodeIfPresent([PlanExerciseData].self, forKey: .activitats)
        forca = try c.decodeIfPresent([PlanExerciseData].self, forKey: .forca)
        pliometria = try c.decodeIfPresent([PlanExerciseData].self, forKey: .pliometria)
        // escalfament may be a String (e.g. "8-10 minuts") or an array — handle both
        if let arr = try? c.decodeIfPresent([PlanExerciseData].self, forKey: .escalfament) {
            escalfament = arr
        } else if let str = try? c.decodeIfPresent(String.self, forKey: .escalfament) {
            escalfament = [PlanExerciseData(exercici: str, series_repeticions: nil, descripcio: nil, imatge: nil)]
        } else {
            escalfament = nil
        }
        part_principal = try c.decodeIfPresent([PlanExerciseData].self, forKey: .part_principal)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(nom, forKey: .nom)
        try c.encodeIfPresent(objectiu, forKey: .objectiu)
        try c.encodeIfPresent(nota, forKey: .nota)
        try c.encodeIfPresent(imatge, forKey: .imatge)
        try c.encodeIfPresent(escalfament, forKey: .escalfament)
        try c.encodeIfPresent(part_principal, forKey: .part_principal)
        try c.encodeIfPresent(activitats, forKey: .activitats)
        try c.encodeIfPresent(forca, forKey: .forca)
        try c.encodeIfPresent(pliometria, forKey: .pliometria)
    }
}

public struct PlanExerciseData: Codable {
    public let exercici: String
    public let series_repeticions: String?
    public let descripcio: String?
    public let imatge: String?
}

// MARK: - Plan Repository

public class PlanRepo: @unchecked Sendable {
    public static let shared = PlanRepo()
    
    private let startDateKey = "plan.startDate"
    private let cycleNumberKey = "plan.cycleNumber"
    private let completedCyclesKey = "plan.completedCycles"
    private let lastSportKey = "plan.lastSport"
    private let archivesKey = "plan.archives"
    private var cachedPlan: PlanFile? = nil
    private var cachedSport: String? = nil
    private var cachedPlanNumber: Int? = nil
    
    public init() {}

    private static func programCompletedKey(forSport sport: String) -> String {
        "plan.programCompleted.\(sport)"
    }

    /// Sport whose plan should load ("Futbol" / "Basquet").
    public func currentSport() -> String {
        QuestionaryRepo().getSelectedSport() ?? "Futbol"
    }

    public static func planFilename(sport: String, number: Int) -> String {
        let clamped = min(max(number, 1), 4)
        if sport == "Basquet" {
            return "basket_pla-\(clamped)"
        }
        return "football_pla-\(clamped)"
    }

    /// Currently assigned plan (1–4) for the current sport. Falls back to
    /// classifying the saved physical-test answers so users who finished
    /// before plan assignment existed still get the right plan. Defaults to 1.
    public func getAssignedPlanNumber() -> Int {
        let store = QuestionaryRepo()
        let sport = currentSport()
        if let stored = store.getAssignedPlan(forSport: sport) {
            return stored
        }
        return PhysicalPlanClassifier.assignedPlan(answers: store.getSavedAnswers())
    }

    public func saveAssignedPlanNumber(_ number: Int) {
        let sport = currentSport()
        QuestionaryRepo().saveAssignedPlan(number, forSport: sport)
        if cachedSport != sport || cachedPlanNumber != number {
            cachedPlan = nil
            cachedSport = nil
            cachedPlanNumber = nil
        }
    }
    
    public func loadPlan() -> PlanFile? {
        let sport = currentSport()
        let planNumber = getAssignedPlanNumber()
        if let cached = cachedPlan, cachedSport == sport, cachedPlanNumber == planNumber {
            return cached
        }
        cachedPlan = nil
        cachedSport = nil
        cachedPlanNumber = nil
        
        let filename = Self.planFilename(sport: sport, number: planNumber)
        var url: URL? = nil
        
        // Primary: bundled JSON
        if let bundleURL = Bundle.main.url(forResource: filename, withExtension: "json") {
            url = bundleURL
        } else if let bundleSubURL = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "Data/Football") {
            url = bundleSubURL
        } else if let bundleSubURL = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "Data/Basquet") {
            url = bundleSubURL
        }

        let dataFolder = sport == "Basquet" ? "Data/Basquet" : "Data/Football"

        // Secondary: known relative paths
        if url == nil {
            let possiblePaths = [
                "mhbasfut/\(dataFolder)/\(filename).json",
                "\(dataFolder)/\(filename).json"
            ]
            for p in possiblePaths {
                let fileURL = URL(fileURLWithPath: p)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    url = fileURL
                    break
                }
            }
        }
        
        // Tertiary: fallback to bundle resource path
        if url == nil, let resourcePath = Bundle.main.resourcePath {
            let fallback = URL(fileURLWithPath: resourcePath).appendingPathComponent("\(dataFolder)/\(filename).json")
            if FileManager.default.fileExists(atPath: fallback.path) {
                url = fallback
            }
        }
        
        // Final: current working directory fallback
        if url == nil {
            let cwd = FileManager.default.currentDirectoryPath
            let fallback = URL(fileURLWithPath: cwd).appendingPathComponent("\(dataFolder)/\(filename).json")
            if FileManager.default.fileExists(atPath: fallback.path) {
                url = fallback
            }
        }
        
        guard let finalUrl = url else {
            #if DEBUG
            print("[PlanRepo] ❌ Could not find \(filename).json in any search path")
            #endif
            return nil
        }
        #if DEBUG
        print("[PlanRepo] ✅ Loading plan from: \(finalUrl.path)")
        #endif
        guard let data = try? Data(contentsOf: finalUrl) else {
            #if DEBUG
            print("[PlanRepo] ❌ Could not read data from \(finalUrl.path)")
            #endif
            return nil
        }
        do {
            let plan = try JSONDecoder().decode(PlanFile.self, from: data)
            #if DEBUG
            print("[PlanRepo] ✅ Plan decoded successfully: \(plan.dies.count) days")
            #endif
            cachedPlan = plan
            cachedSport = sport
            cachedPlanNumber = planNumber
            return plan
        } catch {
            #if DEBUG
            print("[PlanRepo] ❌ JSON decode error: \(error)")
            #endif
            return nil
        }
    }
    
    public func getDay(number: Int) -> PlanDayData? {
        guard let plan = loadPlan() else { return nil }
        return plan.dies.first(where: { $0.dia == number })
    }
    
    // MARK: - Calendar & Day Calculation
    
    public func getPlanStartDate() -> Date {
        let timestamp = UserDefaults.standard.double(forKey: startDateKey)
        if timestamp > 0 {
            return Date(timeIntervalSince1970: timestamp)
        }
        let now = Date()
        setPlanStartDate(now)
        return now
    }
    
    public func setPlanStartDate(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: startDateKey)
    }
    
    public func calculateCurrentDay() -> Int {
        let calendar = Calendar.current
        let startOfDayPlan = calendar.startOfDay(for: getPlanStartDate())
        let startOfDayToday = calendar.startOfDay(for: Date())
        let daysDiff = calendar.dateComponents([.day], from: startOfDayPlan, to: startOfDayToday).day ?? 0
        return min(max(daysDiff + 1, 1), 14)
    }

    /// Uncapped day number since the plan start (1 = the very first day).
    /// Returns nil when no plan start date is stored. Unlike
    /// `calculateCurrentDay()` this never clamps, so a 20-day-old cycle
    /// reports 20 and callers can detect that the 14-day window expired.
    public func rawDayNumber(now: Date = Date(), calendar: Calendar = Calendar.current) -> Int? {
        guard UserDefaults.standard.object(forKey: startDateKey) != nil else { return nil }
        let timestamp = UserDefaults.standard.double(forKey: startDateKey)
        guard timestamp > 0 else { return nil }
        let startOfDayPlan = calendar.startOfDay(for: Date(timeIntervalSince1970: timestamp))
        let startOfDayToday = calendar.startOfDay(for: now)
        let daysDiff = calendar.dateComponents([.day], from: startOfDayPlan, to: startOfDayToday).day ?? 0
        return daysDiff + 1
    }

    /// True when the stored 14-day cycle has run past its window
    /// (day 15 or later) and the user must retake the questionnaire.
    /// False when there is no stored cycle or the program is already done.
    public func hasPlanExpired(now: Date = Date()) -> Bool {
        if isProgramCompleted() { return false }
        guard let raw = rawDayNumber(now: now) else { return false }
        return raw > 14
    }
    
    // MARK: - Meal Options Persistence
    
    public func getSelectedMealOption(day: Int, stageIndex: Int) -> Int? {
        let key = "plan.selectedMeal.\(day).\(stageIndex)"
        if UserDefaults.standard.object(forKey: key) != nil {
            return UserDefaults.standard.integer(forKey: key)
        }
        return nil
    }
    
    public func saveSelectedMealOption(day: Int, stageIndex: Int, optionIndex: Int) {
        let key = "plan.selectedMeal.\(day).\(stageIndex)"
        UserDefaults.standard.set(optionIndex, forKey: key)
    }
    
    public func getAllSelectedMealOptions(day: Int) -> [Int: Int] {
        var result: [Int: Int] = [:]
        for stage in 0...6 {
            if let opt = getSelectedMealOption(day: day, stageIndex: stage) {
                result[stage] = opt
            }
        }
        return result
    }
    
    // MARK: - Completed Stages Persistence
    
    public func getCompletedStages(day: Int) -> Set<Int> {
        let key = "plan.completedStages.\(day)"
        if let arr = UserDefaults.standard.array(forKey: key) as? [Int] {
            return Set(arr)
        }
        return []
    }
    
    public func saveCompletedStages(day: Int, stages: Set<Int>) {
        let key = "plan.completedStages.\(day)"
        UserDefaults.standard.set(Array(stages), forKey: key)
    }
    
    // MARK: - Day Completion
    
    public func isDayCompleted(day: Int) -> Bool {
        let key = "plan.dayCompleted.\(day)"
        return UserDefaults.standard.bool(forKey: key)
    }
    
    public func setDayCompleted(day: Int, isCompleted: Bool) {
        let key = "plan.dayCompleted.\(day)"
        UserDefaults.standard.set(isCompleted, forKey: key)
    }

    // MARK: - Intensity Valuation (Borg 0–10, Plan 1)

    /// Key pattern: plan.intensity.<day>.<stageIndex> (e.g. plan.intensity.3.2).
    public func intensityKey(day: Int, stageIndex: Int) -> String {
        "plan.intensity.\(day).\(stageIndex)"
    }

    /// Saved Borg intensity 0–10, or nil when never rated. Presence of a value
    /// is the "already rated" flag, so the intensity sheet is skipped forever
    /// for that day + stage combination.
    public func getIntensity(day: Int, stageIndex: Int) -> Int? {
        let key = intensityKey(day: day, stageIndex: stageIndex)
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        let raw = UserDefaults.standard.integer(forKey: key)
        return min(max(raw, 0), 10)
    }

    public func hasIntensityRating(day: Int, stageIndex: Int) -> Bool {
        getIntensity(day: day, stageIndex: stageIndex) != nil
    }

    public func saveIntensity(day: Int, stageIndex: Int, value: Int) {
        let key = intensityKey(day: day, stageIndex: stageIndex)
        UserDefaults.standard.set(min(max(value, 0), 10), forKey: key)
    }
    
    // MARK: - Reset
    
    /// Clears live plan progress (start date, stages, days, meals, intensities).
    /// Cycle counters, the program-completed flag and the archives are kept —
    /// they are the user's history, not live state.
    public func resetPlanData() {
        UserDefaults.standard.removeObject(forKey: startDateKey)
        for d in 1...14 {
            UserDefaults.standard.removeObject(forKey: "plan.completedStages.\(d)")
            UserDefaults.standard.removeObject(forKey: "plan.dayCompleted.\(d)")
            for s in 0...6 {
                UserDefaults.standard.removeObject(forKey: "plan.selectedMeal.\(d).\(s)")
            }
            // Intensity ratings share the plan lifecycle: wiping them here keeps
            // "Rehacer test" / plan reassignment consistent (old days do not
            // leak ratings into a new 14-day cycle). Stages per day are at most
            // 7, so 0...10 covers every possible stageIndex safely.
            for s in 0...10 {
                UserDefaults.standard.removeObject(forKey: intensityKey(day: d, stageIndex: s))
            }
        }
    }

    // MARK: - Cycle model (4 consecutive 14-day plans)

    /// Which 14-day cycle the user is on (1-based). 1 by default.
    public func getCycleNumber() -> Int {
        max(UserDefaults.standard.integer(forKey: cycleNumberKey), 1)
    }

    public func setCycleNumber(_ n: Int) {
        UserDefaults.standard.set(max(n, 1), forKey: cycleNumberKey)
    }

    /// How many 14-day cycles the user has fully completed (14/14 days).
    public func getCompletedCycles() -> Int {
        UserDefaults.standard.integer(forKey: completedCyclesKey)
    }

    public func setCompletedCycles(_ n: Int) {
        UserDefaults.standard.set(max(n, 0), forKey: completedCyclesKey)
    }

    /// Sport of the most recent cycle. Used to decide progression vs. a
    /// fresh start when the user switches sports (Futbol ↔ Basquet).
    public func getLastSport() -> String? {
        UserDefaults.standard.string(forKey: lastSportKey)
    }

    public func setLastSport(_ sport: String) {
        UserDefaults.standard.set(sport, forKey: lastSportKey)
    }

    /// True when the user finished the 14 days of the 4th plan for `sport`.
    public func isProgramCompleted(forSport sport: String) -> Bool {
        UserDefaults.standard.bool(forKey: Self.programCompletedKey(forSport: sport))
    }

    public func isProgramCompleted() -> Bool {
        isProgramCompleted(forSport: currentSport())
    }

    public func setProgramCompleted(_ completed: Bool, forSport sport: String? = nil) {
        let s = sport ?? currentSport()
        UserDefaults.standard.set(completed, forKey: Self.programCompletedKey(forSport: s))
    }

    public func hasStoredStartDate() -> Bool {
        guard UserDefaults.standard.object(forKey: startDateKey) != nil else { return false }
        return UserDefaults.standard.double(forKey: startDateKey) > 0
    }

    /// The next plan in the progression. The 4 plans are meant to be done
    /// one after the other: each new cycle is at least one level above the
    /// previous one (capped at 4), and above that whenever the physical
    /// tests classify the user even higher.
    public static func nextPlanNumber(computedPlan: Int, previousPlan: Int?) -> Int {
        let computed = min(max(computedPlan, 1), 4)
        guard let previous = previousPlan else { return computed }
        return min(4, max(computed, previous + 1))
    }

    // MARK: - Cycle archives

    /// One finished (or recovered) 14-day cycle, kept as history.
    public struct PlanCycleArchive: Codable, Equatable {
        public var sport: String
        public var planNumber: Int
        public var cycleNumber: Int
        public var startDate: Date?
        public var endDate: Date
        public var allDaysCompleted: Bool
        /// True when the entry was rescued by the legacy leak sweep
        /// (progress that could not belong to the live cycle).
        public var recovered: Bool
        public var days: [DaySnapshot]

        public init(sport: String, planNumber: Int, cycleNumber: Int, startDate: Date?, endDate: Date, allDaysCompleted: Bool, recovered: Bool = false, days: [DaySnapshot]) {
            self.sport = sport
            self.planNumber = planNumber
            self.cycleNumber = cycleNumber
            self.startDate = startDate
            self.endDate = endDate
            self.allDaysCompleted = allDaysCompleted
            self.recovered = recovered
            self.days = days
        }
    }

    public func getArchives(defaults: UserDefaults = .standard) -> [PlanCycleArchive] {
        guard let data = defaults.data(forKey: archivesKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([PlanCycleArchive].self, from: data)) ?? []
    }

    public func appendArchive(_ archive: PlanCycleArchive, defaults: UserDefaults = .standard) {
        var list = getArchives(defaults: defaults)
        list.append(archive)
        saveArchives(list, defaults: defaults)
    }

    public func saveArchives(_ list: [PlanCycleArchive], defaults: UserDefaults = .standard) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(list) {
            defaults.set(data, forKey: archivesKey)
        }
    }

    /// Snapshot of the live 14 days as archive material.
    public func liveDaysSnapshot(defaults: UserDefaults = .standard) -> [DaySnapshot] {
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
                let key = intensityKey(day: d, stageIndex: stage)
                if defaults.object(forKey: key) != nil {
                    intensities["\(stage)"] = min(max(defaults.integer(forKey: key), 0), 10)
                }
            }
            days.append(DaySnapshot(day: d, completed: isDone, completedStages: stages, selectedMeals: meals, intensities: intensities))
        }
        return days
    }

    private func dayHasAnyData(_ d: Int, defaults: UserDefaults) -> Bool {
        if defaults.bool(forKey: "plan.dayCompleted.\(d)") { return true }
        if let arr = defaults.array(forKey: "plan.completedStages.\(d)") as? [Int], !arr.isEmpty { return true }
        for s in 0...6 where defaults.object(forKey: "plan.selectedMeal.\(d).\(s)") != nil { return true }
        for s in 0...10 where defaults.object(forKey: intensityKey(day: d, stageIndex: s)) != nil { return true }
        return false
    }

    /// Repairs users hit by the pre-cycle leak bug: after retaking the
    /// questionnaire on the same plan, old days stayed "completed", so the
    /// new cycle could not be done ("cannot complete meals"). Any progress on
    /// days beyond the day the user could possibly have reached is impossible
    /// by definition — rescue it into the archives and clear it so the live
    /// cycle is playable again.
    @discardableResult
    public func sweepImpossibleProgressIfNeeded(defaults: UserDefaults = .standard, now: Date = Date()) -> Int {
        guard QuestionaryRepo().isQuestionnaireCompleted() else { return 0 }
        guard let raw = rawDayNumber(now: now) else { return 0 }
        guard raw < 14 else { return 0 }
        let firstImpossible = raw + 1
        guard firstImpossible <= 14 else { return 0 }

        var leaked: [DaySnapshot] = []
        var leakedDays: [Int] = []
        for d in firstImpossible...14 where dayHasAnyData(d, defaults: defaults) {
            leakedDays.append(d)
        }
        guard !leakedDays.isEmpty else { return 0 }

        let all = liveDaysSnapshot(defaults: defaults)
        for d in leakedDays {
            if let snap = all.first(where: { $0.day == d }) { leaked.append(snap) }
        }
        let startTs = defaults.double(forKey: startDateKey)
        let archive = PlanCycleArchive(
            sport: currentSport(),
            planNumber: getAssignedPlanNumber(),
            cycleNumber: getCycleNumber(),
            startDate: startTs > 0 ? Date(timeIntervalSince1970: startTs) : nil,
            endDate: now,
            allDaysCompleted: false,
            recovered: true,
            days: leaked
        )
        appendArchive(archive, defaults: defaults)

        for d in leakedDays {
            defaults.removeObject(forKey: "plan.completedStages.\(d)")
            defaults.removeObject(forKey: "plan.dayCompleted.\(d)")
            for s in 0...6 { defaults.removeObject(forKey: "plan.selectedMeal.\(d).\(s)") }
            for s in 0...10 { defaults.removeObject(forKey: intensityKey(day: d, stageIndex: s)) }
        }
        return leakedDays.count
    }

    // MARK: - Cycle transitions

    /// Called when day 14 is fully completed. Archives nothing yet: the
    /// cycle is archived and replaced when the retake questionnaire is
    /// finished. Plan 4 (or an already completed program) closes the
    /// program instead of asking for another retake.
    @discardableResult
    public func handleFinalDayCompleted() -> Bool {
        let plan = getAssignedPlanNumber()
        setCompletedCycles(getCompletedCycles() + 1)
        if plan >= 4 {
            setProgramCompleted(true)
            return false // program closed → keep the final day on screen
        }
        QuestionaryRepo().saveCompletion(isCompleted: false)
        return true // retake required
    }

    /// Single funnel for every questionnaire completion. Archives the
    /// previous live cycle (if any), decides the next plan in the
    /// progression, clears live progress and restarts the 14 days today.
    /// Returns the plan number the new cycle runs.
    @discardableResult
    public func completeQuestionnaireCycle(sport: String, computedPlan: Int, defaults: UserDefaults = .standard, now: Date = Date()) -> Int {
        let hadLiveCycle = hasStoredStartDate()
        let previousPlan: Int? = hadLiveCycle ? getAssignedPlanNumber() : nil

        if hadLiveCycle {
            let days = liveDaysSnapshot(defaults: defaults)
            let allDone = days.allSatisfy { $0.completed }
            let startTs = defaults.double(forKey: startDateKey)
            let archive = PlanCycleArchive(
                sport: getLastSport() ?? currentSport(),
                planNumber: getAssignedPlanNumber(),
                cycleNumber: getCycleNumber(),
                startDate: startTs > 0 ? Date(timeIntervalSince1970: startTs) : nil,
                endDate: now,
                allDaysCompleted: allDone,
                recovered: false,
                days: days
            )
            appendArchive(archive, defaults: defaults)
        }

        let sameSport = hadLiveCycle && (getLastSport() ?? currentSport()) == sport
        let next: Int
        if isProgramCompleted(forSport: sport) {
            // Explicit retake after finishing the program (e.g. "Rehacer
            // test"): fresh assessment restarts the progression.
            setProgramCompleted(false, forSport: sport)
            next = min(max(computedPlan, 1), 4)
        } else if sameSport {
            next = Self.nextPlanNumber(computedPlan: computedPlan, previousPlan: previousPlan)
        } else {
            next = min(max(computedPlan, 1), 4)
        }

        QuestionaryRepo().saveAssignedPlan(next, forSport: sport)
        resetPlanData()
        setCycleNumber(hadLiveCycle ? getCycleNumber() + 1 : 1)
        setLastSport(sport)
        setPlanStartDate(now)
        if cachedSport != sport || cachedPlanNumber != next {
            cachedPlan = nil
            cachedSport = nil
            cachedPlanNumber = nil
        }
        return next
    }

    /// Launch/foreground gate: keeps the UI honest when a cycle expires
    /// without the user finishing day 14 — quest rewrites storage only
    /// when needed. Returns true when a retake was enforced.
    @discardableResult
    public func enforceExpiryIfNeeded(now: Date = Date()) -> Bool {
        sweepImpossibleProgressIfNeeded(now: now)
        guard QuestionaryRepo().isQuestionnaireCompleted() else { return false }
        guard hasPlanExpired(now: now) else { return false }
        QuestionaryRepo().saveCompletion(isCompleted: false)
        return true
    }
}
