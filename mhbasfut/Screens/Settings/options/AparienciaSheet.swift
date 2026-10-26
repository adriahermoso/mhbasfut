//
//  AparienciaSheet.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import SwiftUI

/// Accent color choice. Persisted as a raw string under "settings.accent"
/// and consumed by the settings screens (toggles, links, previews).
public enum AppAccent: String, CaseIterable, Identifiable {
    case dorado, verde, azul

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dorado: return "Dorado"
        case .verde: return "Verde"
        case .azul: return "Azul"
        }
    }

    public var color: Color {
        switch self {
        case .dorado: return Color(red: 0.996, green: 0.776, blue: 0.0)
        case .verde: return Color(red: 0.55, green: 0.82, blue: 0.18)
        case .azul: return Color(red: 52/255, green: 172/255, blue: 231/255)
        }
    }

    public static let storageKey = "settings.accent"

    public static var current: AppAccent {
        AppAccent(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "dorado") ?? .dorado
    }
}

struct AparienciaSheetView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage(AppAccent.storageKey) private var accentRaw: String = AppAccent.dorado.rawValue

    private var accent: AppAccent {
        AppAccent(rawValue: accentRaw) ?? .dorado
    }

    private let backgroundColor = Color(red: 28/255, green: 38/255, blue: 43/255)
    private let textColor = Color(red: 230/255, green: 235/255, blue: 238/255)
    private let subtitleColor = Color(red: 0.66, green: 0.69, blue: 0.71)

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Apariencia")
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
                        Text("Color de acento")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(subtitleColor)
                            .padding(.horizontal, 4)

                        ForEach(AppAccent.allCases) { option in
                            Button(action: {
                                accentRaw = option.rawValue
                            }) {
                                HStack(spacing: 14) {
                                    Circle()
                                        .fill(option.color)
                                        .frame(width: 28, height: 28)

                                    Text(option.title)
                                        .font(.system(size: 16, weight: .heavy))
                                        .foregroundColor(.white)

                                    Spacer(minLength: 8)

                                    if option == accent {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .heavy))
                                            .foregroundColor(option.color)
                                    }
                                }
                                .padding(18)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Color(red: 0.11, green: 0.14, blue: 0.18))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                .stroke(
                                                    option == accent ? option.color : Color(red: 0.20, green: 0.25, blue: 0.32),
                                                    lineWidth: option == accent ? 2 : 1.5
                                                )
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color de acento \(option.title)")
                        }

                        // Live preview: shows the chosen accent immediately.
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Vista previa")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(subtitleColor)

                            Text("Así se ve tu acento")
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundColor(accent.color)

                            Capsule()
                                .fill(accent.color)
                                .frame(height: 12)
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
}

#Preview {
    AparienciaSheetView()
}
