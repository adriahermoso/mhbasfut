//
//  AcercaSheet.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import SwiftUI

/// Locked-in legal URLs (also used in App Store Connect).
public enum LegalLinks {
    public static let privacyPolicy = URL(string: "https://adriahermoso.github.io/mhbasfut/privacy-policy.html")!
    public static let support = URL(string: "https://adriahermoso.github.io/mhbasfut/support.html")!
}

struct AcercaSheetView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage(AppAccent.storageKey) private var accentRaw: String = AppAccent.dorado.rawValue

    private var accent: AppAccent {
        AppAccent(rawValue: accentRaw) ?? .dorado
    }

    private let backgroundColor = Color(red: 28/255, green: 38/255, blue: 43/255)
    private let textColor = Color(red: 230/255, green: 235/255, blue: 238/255)
    private let subtitleColor = Color(red: 0.66, green: 0.69, blue: 0.71)

    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return "Versión \(version)"
        }
        return "Versión 1.0.0"
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Acerca de MHBasFut")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

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
                        Text("MHBasFut te ayuda a seguir tu rutina de entrenamiento invisible: cuestionario inicial, plan personalizado de 14 días, racha diaria y recompensas.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(subtitleColor)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Si vinculas tu cuenta de profesor (Ajustes → Vincular cuenta de profesor), tu progreso —cuestionario, plan, comidas, intensidad, sueño, emoción, racha y recompensas— se envía a tu profesor y se guarda en el repositorio adriahermoso/mhbasfut bajo users/{tu-usuario}.json. Puedes desvincularla en cualquier momento para detener los envíos.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(subtitleColor)
                            .fixedSize(horizontal: false, vertical: true)

                        Link(destination: LegalLinks.privacyPolicy) {
                            legalRow(icon: "lock.shield.fill", title: "Política de privacidad")
                        }
                        .accessibilityLabel("Abrir la política de privacidad")

                        Link(destination: LegalLinks.support) {
                            legalRow(icon: "questionmark.circle.fill", title: "Soporte")
                        }
                        .accessibilityLabel("Abrir la página de soporte")

                        Text(appVersion)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(subtitleColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)

                        Text("Hecho por Absurd Studio")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(subtitleColor)
                            .frame(maxWidth: .infinity, alignment: .center)
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

    private func legalRow(icon: String, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(accent.color)
                .frame(width: 26)

            Text(title)
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(.white)

            Spacer(minLength: 8)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(subtitleColor)
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
    AcercaSheetView()
}
