//
//  WellnessSheets.swift
//  mhbasfut
//
//  Plan 2 – Sleep Quality + Emotion Rater sheets.
//  Same visual language as Plan/Rewards/Streak sheets: dark #1C262B
//  background, rounded cards, heavy titles. Both sheets are non-dismissable
//  and auto-dismiss on selection (the caller persists, then dismisses).
//

import SwiftUI

// MARK: - Shared option models (order is part of the spec)

public struct WellnessOption: Identifiable, Equatable {
    public let id: Int
    public let rating: Int
    public let emoji: String
    public let label: String

    public init(rating: Int, emoji: String, label: String) {
        self.id = rating
        self.rating = rating
        self.emoji = emoji
        self.label = label
    }
}

public enum SleepQualityOptions {
    /// 0 = Muy bien … 3 = Mal. Order matters.
    public static let all: [WellnessOption] = [
        WellnessOption(rating: 0, emoji: "😃", label: "Muy bien"),
        WellnessOption(rating: 1, emoji: "😐", label: "Regular"),
        WellnessOption(rating: 2, emoji: "🥱", label: "Cansado"),
        WellnessOption(rating: 3, emoji: "😴", label: "Mal"),
    ]
}

public enum EmotionOptions {
    /// 0 = Genial … 4 = Fatal. Order matters.
    public static let all: [WellnessOption] = [
        WellnessOption(rating: 0, emoji: "😁", label: "Genial"),
        WellnessOption(rating: 1, emoji: "🙂", label: "Bien"),
        WellnessOption(rating: 2, emoji: "😐", label: "Normal"),
        WellnessOption(rating: 3, emoji: "🙁", label: "Mal"),
        WellnessOption(rating: 4, emoji: "😫", label: "Fatal"),
    ]
}

// MARK: - Shared palette (same as Settings/Streak/Plan sheets)

private let wellnessBackground = Color(red: 28/255, green: 38/255, blue: 43/255) // #1C262B
private let wellnessText = Color(red: 230/255, green: 235/255, blue: 238/255)
private let wellnessSubtitle = Color(red: 0.66, green: 0.69, blue: 0.71)
private let wellnessCardFill = Color(red: 0.11, green: 0.14, blue: 0.18)
private let wellnessCardStroke = Color(red: 0.20, green: 0.25, blue: 0.32)

// MARK: - Shared option card (emoji over label, full width)

private struct WellnessOptionCard: View {
    let option: WellnessOption
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(option.emoji)
                    .font(.system(size: 44))
                Text(option.label)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(wellnessCardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(wellnessCardStroke, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
    }
}

// MARK: - Shared sheet scaffold (title + subtitle + options, no close button)

private struct WellnessSheetScaffold<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ZStack {
            wellnessBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(wellnessText)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)

                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(wellnessSubtitle)
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        content
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
                .padding(.top, 4)
            }
            .ignoresSafeArea(.container, edges: [.bottom, .horizontal])
        }
        .interactiveDismissDisabled(true)
    }
}

// MARK: - Sleep Quality sheet (daily)

struct SleepQualitySheetView: View {
    var onSelect: (Int) -> Void

    init(onSelect: @escaping (Int) -> Void) {
        self.onSelect = onSelect
    }

    var body: some View {
        WellnessSheetScaffold(
            title: "¿Cómo has dormido?",
            subtitle: "Selecciona cómo te sientes al despertar"
        ) {
            ForEach(SleepQualityOptions.all) { option in
                WellnessOptionCard(option: option) {
                    onSelect(option.rating)
                }
            }
        }
    }
}

// MARK: - Emotion sheet (every 3 calendar days)

struct EmotionSheetView: View {
    var onSelect: (Int) -> Void

    init(onSelect: @escaping (Int) -> Void) {
        self.onSelect = onSelect
    }

    var body: some View {
        WellnessSheetScaffold(title: "¿Cómo te sientes hoy?") {
            ForEach(EmotionOptions.all) { option in
                WellnessOptionCard(option: option) {
                    onSelect(option.rating)
                }
            }
        }
    }
}

#Preview("Sleep") {
    SleepQualitySheetView { _ in }
}

#Preview("Emotion") {
    EmotionSheetView { _ in }
}
