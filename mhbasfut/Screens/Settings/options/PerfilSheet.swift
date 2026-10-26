//
//  PerfilSheet.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import SwiftUI

struct PerfilSheetView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = RewardsViewModel()
    @State private var draftName: String = ""
    @State private var didInitDraft: Bool = false

    private let backgroundColor = Color(red: 28/255, green: 38/255, blue: 43/255)
    private let textColor = Color(red: 230/255, green: 235/255, blue: 238/255)
    private let subtitleColor = Color(red: 0.66, green: 0.69, blue: 0.71)

    private var trimmedDraft: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedDraft.isEmpty && trimmedDraft != viewModel.characterName
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Perfil")
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
                .padding(.horizontal, 24)
                .padding(.top, 32)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Nombre de tu personaje")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(subtitleColor)
                            .padding(.horizontal, 4)

                        TextField("Escribe un nombre", text: $draftName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(red: 0.11, green: 0.14, blue: 0.18))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color(red: 0.20, green: 0.25, blue: 0.32), lineWidth: 1.5)
                                    )
                            )
                            .accessibilityLabel("Nombre del personaje")

                        HStack(spacing: 16) {
                            Text("Nivel \(viewModel.level)")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.55, green: 0.82, blue: 0.18))
                                .clipShape(Capsule())

                            Text("\(viewModel.coins) monedas")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.97, green: 0.72, blue: 0.0))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                }

                BottomButton(
                    subtitle: "Tu personaje",
                    title: viewModel.characterName,
                    buttonText: "GUARDAR",
                    isActive: canSave
                ) {
                    viewModel.setCharacterName(trimmedDraft)
                    dismiss()
                }
            }
            .ignoresSafeArea(.container, edges: [.bottom, .horizontal])
        }
        .onAppear {
            if !didInitDraft {
                draftName = viewModel.characterName
            }
        }
        .onChange(of: viewModel.characterName) { _, newValue in
            if !didInitDraft {
                didInitDraft = true
                draftName = newValue
            }
        }
    }
}

#Preview {
    PerfilSheetView()
}
