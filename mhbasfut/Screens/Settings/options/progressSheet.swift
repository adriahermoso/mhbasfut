//
//  progressSheet.swift
//  mhbasfut
//
//  Progress sheet showing the questionnaire punctuation card.
//  Kept on "Rehacer test", deleted on "Eliminar datos".
//

import SwiftUI

struct progressSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var score: QuestionaryScore?

    private let backgroundColor = Color(red: 28/255, green: 38/255, blue: 43/255)
    private let textColor = Color(red: 230/255, green: 235/255, blue: 238/255)
    private let subtitleColor = Color(red: 0.66, green: 0.69, blue: 0.71)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Progreso")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(textColor)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(textColor)
                }
                .accessibilityLabel("Cerrar")
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if score != nil {
                        QuestionaryScoreCard(score: score)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 44, weight: .bold))
                                .foregroundColor(Color(red: 1.00, green: 0.77, blue: 0.05))
                            Text("Aún no tienes puntuación")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundColor(textColor)
                                .multilineTextAlignment(.center)
                            Text("Completa el test inicial para ver aquí tu tarjeta de puntuación.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(subtitleColor)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color(red: 0.11, green: 0.14, blue: 0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color(red: 0.20, green: 0.25, blue: 0.32), lineWidth: 1.5)
                                )
                        )
                    }
                }
                .padding(.bottom, 20)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(backgroundColor.edgesIgnoringSafeArea(.all))
        .onAppear {
            score = QuestionaryRepo().getSavedScore()
        }
    }
}

// Alias with Swift naming conventions pointing to the same sheet.
typealias ProgressSheetView = progressSheet

#Preview {
    progressSheet()
}
