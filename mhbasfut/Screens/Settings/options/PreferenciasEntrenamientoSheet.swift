//
//  PreferenciasEntrenamientoSheet.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import SwiftUI

/// UserDefaults keys (consumed live by PlanSheetView).
public enum TrainingPreferences {
    public static let showObjectivesKey = "training.showObjectives"
    public static let confirmCompleteKey = "training.confirmComplete"
}

struct PreferenciasEntrenamientoSheetView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage(TrainingPreferences.showObjectivesKey) private var showObjectives: Bool = true
    @AppStorage(TrainingPreferences.confirmCompleteKey) private var confirmComplete: Bool = false

    private let backgroundColor = Color(red: 28/255, green: 38/255, blue: 43/255)
    private let textColor = Color(red: 230/255, green: 235/255, blue: 238/255)
    private let subtitleColor = Color(red: 0.66, green: 0.69, blue: 0.71)
    private let toggleColor = Color(red: 0.55, green: 0.82, blue: 0.18)

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Preferencias de entrenamiento")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(textColor)
                    }
                    .accessibilityLabel("Cerrar")
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        preferenceCard(
                            title: "Mostrar objetivos de etapa",
                            detail: "Muestra el objetivo del entrenamiento en cada etapa del plan.",
                            isOn: $showObjectives
                        )
                        .accessibilityLabel("Mostrar objetivos de etapa")

                        preferenceCard(
                            title: "Pedir confirmación al completar",
                            detail: "Muestra una confirmación antes de marcar una etapa como completada.",
                            isOn: $confirmComplete
                        )
                        .accessibilityLabel("Pedir confirmación al completar")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
                .padding(.top, 4)

                Spacer(minLength: 0)
            }
            .ignoresSafeArea(.container, edges: [.bottom, .horizontal])
        }
    }

    private func preferenceCard(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(subtitleColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(toggleColor)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.11, green: 0.14, blue: 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(red: 0.20, green: 0.25, blue: 0.32), lineWidth: 1.5)
                )
        )
    }
}

#Preview {
    PreferenciasEntrenamientoSheetView()
}
