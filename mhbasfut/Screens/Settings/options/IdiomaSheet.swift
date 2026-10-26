//
//  IdiomaSheet.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import SwiftUI

/// App language. Spanish is the working language; the choice persists.
public enum AppLanguage: String, CaseIterable, Identifiable {
    case espanol

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .espanol: return "Español"
        }
    }

    public static let storageKey = "settings.language"
}

struct IdiomaSheetView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage(AppLanguage.storageKey) private var languageRaw: String = AppLanguage.espanol.rawValue

    private let backgroundColor = Color(red: 28/255, green: 38/255, blue: 43/255)
    private let textColor = Color(red: 230/255, green: 235/255, blue: 238/255)
    private let subtitleColor = Color(red: 0.66, green: 0.69, blue: 0.71)

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Idioma")
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
                        ForEach(AppLanguage.allCases) { option in
                            Button(action: {
                                languageRaw = option.rawValue
                            }) {
                                HStack(spacing: 14) {
                                    Text(option.title)
                                        .font(.system(size: 16, weight: .heavy))
                                        .foregroundColor(.white)

                                    Spacer(minLength: 8)

                                    if option.rawValue == languageRaw {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .heavy))
                                            .foregroundColor(Color(red: 0.55, green: 0.82, blue: 0.18))
                                    }
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
                            .buttonStyle(.plain)
                            .accessibilityLabel("Idioma \(option.title)")
                        }

                        Text("Los cuestionarios y planes del programa se muestran en el idioma del programa.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(subtitleColor)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
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
    IdiomaSheetView()
}
