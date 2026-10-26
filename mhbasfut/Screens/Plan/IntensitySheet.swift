//
//  IntensitySheet.swift
//  mhbasfut
//
//  Plan 1 – Borg 0–10 intensity valuation sheet shown after a training stage.
//  Reuses OptionButton rows + BottomButton 3D CTA + app palette (#1C262B).
//

import SwiftUI

struct IntensitySheetView: View {
    @Environment(\.dismiss) private var dismiss

    let day: Int
    let stageIndex: Int
    var onFinished: (Int) -> Void

    @State private var selectedIntensity: Int? = nil

    private let backgroundColor = Color(red: 28/255, green: 38/255, blue: 43/255) // #1C262B
    private let textColor = Color(red: 230/255, green: 235/255, blue: 238/255)
    private let subtitleColor = Color(red: 0.66, green: 0.69, blue: 0.71)

    init(day: Int, stageIndex: Int, onFinished: @escaping (Int) -> Void) {
        self.day = day
        self.stageIndex = stageIndex
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        if selectedIntensity == nil {
                            borgList
                        } else {
                            recoveryList
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }

                if let selected = selectedIntensity {
                    let exercises = IntensityLogic.exercises(for: selected)
                    BottomButton(
                        subtitle: "Intensidad \(selected) · \(exercises.count) ejercicios",
                        title: "Recuperación",
                        buttonText: "He acabat",
                        isActive: true
                    ) {
                        onFinished(selected)
                    }
                    .accessibilityLabel("He acabat")
                }
            }
            .ignoresSafeArea(.container, edges: [.bottom, .horizontal])
        }
        .interactiveDismissDisabled(true)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Valora la intensidad")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(textColor)
                    Text("Sesión acabada · Día \(day)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(subtitleColor)
                }
                Spacer()
                // No close button by design: the sheet is non-dismissable
                // until "He acabat" is tapped (.interactiveDismissDisabled).
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            if selectedIntensity == nil {
                Text("¿Cómo de dura ha sido esta sesión?")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(subtitleColor)
                    .padding(.horizontal, 24)
                    .padding(.top, 2)
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: - Borg options (11 rows, highest to lowest)

    private var borgList: some View {
        VStack(spacing: 12) {
            ForEach(IntensityLogic.borgOptions) { option in
                OptionButton(
                    mode: .vertical(systemIcon: nil),
                    text: option.label,
                    isSelected: selectedIntensity == option.value
                ) {
                    selectedIntensity = option.value
                }
                .accessibilityLabel(option.label)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Recovery list (contiguous prefix per mapping)

    private var recoveryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selected = selectedIntensity,
               let chosen = IntensityLogic.borgOptions.first(where: { $0.value == selected }) {
                HStack {
                    Text(chosen.label)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(Color(red: 1.00, green: 0.77, blue: 0.05))
                        .accessibilityLabel("Intensidad seleccionada: \(chosen.label)")

                    Spacer(minLength: 8)

                    Button(action: { selectedIntensity = nil }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                            Text("Cambiar")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(subtitleColor)
                    }
                    .accessibilityLabel("Volver a la selección de intensidad")
                }
            }

            ForEach(Array(IntensityLogic.exercises(for: selectedIntensity ?? 0).enumerated()), id: \.offset) { idx, exercise in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(idx + 1)")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 54/255, green: 71/255, blue: 81/255))
                        )
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(.white)
                        Text(exercise.detail)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Color(red: 0.07, green: 0.07, blue: 0.07))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityLabel("\(exercise.name). \(exercise.detail)")
            }
        }
        .padding(.bottom, 4)
    }
}

#Preview("Intensity – Borg") {
    IntensitySheetView(day: 3, stageIndex: 2) { _ in }
}

#Preview("Intensity – logic check") {
    let v = IntensityLogic.exercises(for: 8).count
    return Text("8 → \(v) ejercicios")
}
