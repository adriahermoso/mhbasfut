//
//  AdminOverrideApplier.swift
//  mhbasfut
//
//  Plan Admin Data Sync – edición manual desde el panel web.
//  El panel escribe `adminOverrides` + `adminRevision` dentro de
//  users/{usuario}.json. La app, al arrancar/volver a primer plano (y
//  antes de cada subida), aplica esas ediciones si la revisión remota es
//  más nueva que la última aplicada. Todo el módulo es puro y testeable:
//  recibe un diccionario y unos UserDefaults, no toca la red.
//

import Foundation

public enum AdminOverrideApplier {

    /// Clave donde se recuerda la última `adminRevision` aplicada.
    public static let lastAppliedRevisionKey = "admin.lastAppliedRevision"

    /// Revisión aplicada más recientemente (nil si nunca).
    public static func appliedRevision(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: lastAppliedRevisionKey)
    }

    public static func storeAppliedRevision(_ revision: String?, defaults: UserDefaults = .standard) {
        defaults.set(revision, forKey: lastAppliedRevisionKey)
    }

    /// ¿Debe aplicarse la revisión remota? Solo si existe y es estrictamente
    /// posterior a la última aplicada (comparación por fecha ISO-8601).
    public static func shouldApply(remoteRevision: String?, appliedRevision: String?) -> Bool {
        guard let remote = remoteRevision, let remoteDate = parseISO8601(remote) else { return false }
        guard let applied = appliedRevision, let appliedDate = parseISO8601(applied) else { return true }
        return remoteDate > appliedDate
    }

    /// Formato exacto que escribe la web: ISO-8601 SIN milisegundos
    /// ("2026-10-17T12:34:56Z"), que es lo que acepta JSONDecoder .iso8601.
    public static func parseISO8601(_ s: String) -> Date? {
        let withFractions = ISO8601DateFormatter()
        withFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFractions.date(from: s) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: s)
    }

    /// Aplica las ediciones presentes en `overrides` sobre los UserDefaults.
    /// Devuelve la lista de campos aplicados (para logs y tests). Los campos
    /// ausentes o inválidos se ignoran en silencio: una edición del panel
    /// nunca debe romper la app.
    @discardableResult
    public static func apply(overrides: [String: Any], defaults: UserDefaults = .standard) -> [String] {
        var applied: [String] = []

        if let completed = overrides["questionnaireCompleted"] as? Bool {
            defaults.set(completed, forKey: "questionary.isCompleted")
            applied.append("questionnaireCompleted")
        }

        if let sport = overrides["sport"] as? String, sport == "Futbol" || sport == "Basquet" {
            defaults.set(sport, forKey: "questionary.selectedSport")
            applied.append("sport")
        }

        let sport = resolvedSport(overrides: overrides, defaults: defaults)

        if let plan = intValue(overrides["planNumber"]) {
            let clamped = min(max(plan, 1), 4)
            let key = "plan.assignedNumber.\(sport)"
            defaults.set(clamped, forKey: key)
            applied.append("planNumber")
        }

        if let raw = overrides["planStartDate"], let date = dateValue(raw) {
            defaults.set(date.timeIntervalSince1970, forKey: "plan.startDate")
            applied.append("planStartDate")
        }

        if let cycle = intValue(overrides["cycleNumber"]) {
            defaults.set(max(cycle, 1), forKey: "plan.cycleNumber")
            applied.append("cycleNumber")
        }

        if let completedCycles = intValue(overrides["completedCycles"]) {
            defaults.set(max(completedCycles, 0), forKey: "plan.completedCycles")
            applied.append("completedCycles")
        }

        if let programCompleted = overrides["programCompleted"] as? Bool {
            defaults.set(programCompleted, forKey: "plan.programCompleted.\(sport)")
            applied.append("programCompleted")
        }

        if let coins = intValue(overrides["coins"]) {
            defaults.set(max(coins, 0), forKey: "rewards.coins")
            applied.append("coins")
        }

        if let rawDates = overrides["streakCompletedDates"] as? [Any] {
            let stamps: [Double] = rawDates.compactMap { raw in
                if let d = dateValue(raw) { return d.timeIntervalSince1970 }
                return nil
            }
            defaults.set(stamps, forKey: "streak.completedDates")
            applied.append("streakCompletedDates")
        }

        if let answers = overrides["answers"] as? [String: String] {
            defaults.set(answers, forKey: "questionary.answers")
            applied.append("answers")
        }

        if let days = overrides["days"] as? [String: Any] {
            var appliedDays = 0
            for (dayKey, value) in days {
                guard let day = Int(dayKey), (1...14).contains(day),
                      let dayDict = value as? [String: Any] else { continue }
                applyDay(day: day, dict: dayDict, defaults: defaults)
                appliedDays += 1
            }
            if appliedDays > 0 { applied.append("days") }
        }

        return applied
    }

    // MARK: - Internals

    private static func applyDay(day: Int, dict: [String: Any], defaults: UserDefaults) {
        if let completed = dict["completed"] as? Bool {
            defaults.set(completed, forKey: "plan.dayCompleted.\(day)")
        }
        if let stages = dict["completedStages"] as? [Int] {
            defaults.set(stages.map { $0 }, forKey: "plan.completedStages.\(day)")
        } else if let stages = dict["completedStages"] as? [Double] {
            defaults.set(stages.map { Int($0) }, forKey: "plan.completedStages.\(day)")
        }
        if let meals = dict["selectedMeals"] as? [String: Any] {
            for (stageKey, option) in meals {
                guard let stage = Int(stageKey), (0...6).contains(stage),
                      let idx = intValue(option) else { continue }
                defaults.set(idx, forKey: "plan.selectedMeal.\(day).\(stage)")
            }
        }
        if let intensities = dict["intensities"] as? [String: Any] {
            for (stageKey, value) in intensities {
                guard let stage = Int(stageKey), (0...10).contains(stage),
                      let v = intValue(value) else { continue }
                defaults.set(min(max(v, 0), 10), forKey: "plan.intensity.\(day).\(stage)")
            }
        }
    }

    static func resolvedSport(overrides: [String: Any], defaults: UserDefaults = .standard) -> String {
        if let sport = overrides["sport"] as? String, sport == "Futbol" || sport == "Basquet" {
            return sport
        }
        if let stored = defaults.string(forKey: "questionary.selectedSport"), !stored.isEmpty {
            return stored
        }
        if let last = defaults.string(forKey: "plan.lastSport"), !last.isEmpty {
            return last
        }
        return "Futbol"
    }

    static func intValue(_ raw: Any?) -> Int? {
        if let i = raw as? Int { return i }
        if let d = raw as? Double { return Int(d) }
        if let s = raw as? String { return Int(s) }
        return nil
    }

    static func dateValue(_ raw: Any) -> Date? {
        if let s = raw as? String { return parseISO8601(s) }
        if let d = raw as? Double { return Date(timeIntervalSince1970: d > 100_000_000_000 ? d / 1000.0 : d) }
        if let i = raw as? Int { return Date(timeIntervalSince1970: TimeInterval(i)) }
        return nil
    }
}
