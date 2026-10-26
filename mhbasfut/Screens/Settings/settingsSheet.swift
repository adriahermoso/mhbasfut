//
//  settingsSheet.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import SwiftUI

struct SettingsSheetView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var sync = GitHubSyncService.shared

    @State private var showingPerfil = false
    @State private var showingProgreso = false
    @State private var showingPreferencias = false
    @State private var showingApariencia = false
    @State private var showingIdioma = false
    @State private var showingAcerca = false
    @State private var showingEliminarDatosAlert = false
    @State private var showingCerrarSesionAlert = false
    @State private var showingRehacerTestAlert = false
    @State private var showingAdminAuth = false
    @State private var showingEliminarCuentaAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String? = nil

    private let backgroundColor = Color(red: 28/255, green: 38/255, blue: 43/255) // #1C262B
    private let textColor = Color(red: 230/255, green: 235/255, blue: 238/255)
    private let iconColor = Color(red: 180/255, green: 185/255, blue: 190/255)
    @AppStorage(AppAccent.storageKey) private var accentRaw: String = AppAccent.dorado.rawValue

    private var toggleOnColor: Color {
        (AppAccent(rawValue: accentRaw) ?? .dorado).color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header – title + close (same separation as StreakSheet: 24h / 32v via outer padding, same title style as option sheets)
            HStack {
                Text("Ajustes")
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

            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    settingsRow(
                        icon: "person.circle.fill",
                        title: "Perfil",
                        accessory: .chevron,
                        action: {
                            viewModel.didTapPerfil()
                            showingPerfil = true
                        }
                    )

                    settingsRow(
                        icon: "chart.bar.fill",
                        title: "Progreso",
                        accessory: .chevron,
                        action: {
                            showingProgreso = true
                        }
                    )

                    settingsRow(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Rehacer test",
                        accessory: .none,
                        action: { showingRehacerTestAlert = true }
                    )

                    settingsRow(
                        icon: "questionmark.circle.fill",
                        title: "Preferencias de entrenamiento",
                        accessory: .chevron,
                        action: {
                            viewModel.didTapPreferenciasEntrenamiento()
                            showingPreferencias = true
                        }
                    )

                    settingsToggleRow(
                        icon: "bell.fill",
                        title: "Recordatorios",
                        isOn: $viewModel.remindersEnabled,
                        onChange: { viewModel.setRemindersEnabled($0) }
                    )

                    settingsToggleRow(
                        icon: "speaker.wave.2.fill",
                        title: "Sonido y vibración",
                        isOn: $viewModel.soundEnabled,
                        onChange: { viewModel.setSoundEnabled($0) }
                    )

                    settingsRow(
                        icon: "paintpalette.fill",
                        title: "Apariencia",
                        accessory: .chevron,
                        action: {
                            viewModel.didTapApariencia()
                            showingApariencia = true
                        }
                    )

                    settingsRow(
                        icon: "globe",
                        title: "Idioma",
                        accessory: .chevron,
                        action: {
                            viewModel.didTapIdioma()
                            showingIdioma = true
                        }
                    )

                    // Un invitado no tiene cuenta que vincular: se sale del
                    // modo invitado por "Salir de la sesión de invitado".
                    if !sync.isGuest {
                        settingsRow(
                            icon: "person.badge.key.fill",
                            title: "Vincular cuenta de profesor",
                            accessory: .chevron,
                            action: { showingAdminAuth = true }
                        )
                    }

                    settingsRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: sync.isGuest ? "Salir de la sesión de invitado" : "Cerrar sesión",
                        accessory: .none,
                        action: { showingCerrarSesionAlert = true }
                    )

                    // 5.1.1(v): borrado de cuenta desde la app. Solo para
                    // jugadores con cuenta real (no Admin, no invitados).
                    if sync.isStudentSignedIn, !sync.isAdminMode, !sync.isGuest {
                        settingsRow(
                            icon: "person.crop.circle.badge.xmark",
                            title: "Eliminar mi cuenta",
                            accessory: .none,
                            action: {
                                guard !isDeletingAccount else { return }
                                showingEliminarCuentaAlert = true
                            }
                        )
                    }

                    settingsRow(
                        icon: "trash.fill",
                        title: "Eliminar datos",
                        accessory: .none,
                        action: { showingEliminarDatosAlert = true }
                    )

                    settingsRow(
                        icon: "info.circle.fill",
                        title: "Acerca de MHBasFut",
                        accessory: .chevron,
                        action: {
                            viewModel.didTapAcerca()
                            showingAcerca = true
                        }
                    )
                }
            }

            Spacer(minLength: 0)

            Text(viewModel.appVersion)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(backgroundColor.edgesIgnoringSafeArea(.all))
        .alert("Rehacer test", isPresented: $showingRehacerTestAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Rehacer", role: .destructive) {
                viewModel.didTapRehacerTest()
                dismiss()
            }
        } message: {
            Text("Esta acción no se puede deshacer. Si rehaces el test perderás tu progreso actual. ¿Quieres continuar?")
        }
        .alert(sync.isGuest ? "Salir de la sesión de invitado" : "Cerrar sesión", isPresented: $showingCerrarSesionAlert) {
            Button("Cancelar", role: .cancel) { }
            Button(sync.isGuest ? "Salir y borrar" : "Cerrar sesión", role: .destructive) {
                if sync.isGuest {
                    // El progreso del invitado no debe heredarse por una cuenta.
                    Task {
                        await sync.wipeLocalData()
                        dismiss()
                    }
                } else {
                    sync.studentSignOut()
                    dismiss()
                }
            }
        } message: {
            Text(sync.isGuest
                 ? "Se borrará el progreso de la sesión de invitado y volverás a la pantalla de inicio de sesión."
                 : "Se cerrará tu sesión de jugador y la app dejará de enviar tus datos. Volverás a la pantalla de inicio de sesión.")
        }
        .alert("Eliminar mi cuenta", isPresented: $showingEliminarCuentaAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                guard !isDeletingAccount else { return }
                isDeletingAccount = true
                Task {
                    let error = await sync.deleteAccountAndData()
                    isDeletingAccount = false
                    if let error {
                        deleteAccountError = error
                    } else {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Se eliminarán tus datos del servidor del profesor (\(sync.linkedUsername ?? "tu cuenta")) y después el progreso de este dispositivo. Esta acción no se puede deshacer.")
        }
        .alert(
            "No se pudo eliminar la cuenta",
            isPresented: Binding(
                get: { deleteAccountError != nil },
                set: { if !$0 { deleteAccountError = nil } }
            )
        ) {
            Button("Entendido", role: .cancel) { deleteAccountError = nil }
        } message: {
            Text(deleteAccountError ?? "")
        }
        .alert("Eliminar datos", isPresented: $showingEliminarDatosAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                viewModel.didTapEliminarDatos()
                dismiss()
            }
        } message: {
            Text("Esta acción no se puede deshacer. Se borrarán todos tus datos y progreso de forma permanente. ¿Estás seguro?")
        }
        .sheet(isPresented: $showingPerfil) {
            PerfilSheetView()
        }
        .sheet(isPresented: $showingProgreso) {
            progressSheet()
        }
        .sheet(isPresented: $showingPreferencias) {
            PreferenciasEntrenamientoSheetView()
        }
        .sheet(isPresented: $showingApariencia) {
            AparienciaSheetView()
        }
        .sheet(isPresented: $showingIdioma) {
            IdiomaSheetView()
        }
        .sheet(isPresented: $showingAcerca) {
            AcercaSheetView()
        }
        .sheet(isPresented: $showingAdminAuth) {
            AdminAuthView()
        }
    }

    // MARK: - Row Types

    private enum Accessory { case none, chevron }

    @ViewBuilder
    private func settingsRow(icon: String, title: String, accessory: Accessory, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(iconColor)
                        .frame(width: 26)

                    Text(title)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer()

                    if accessory == .chevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                }
                .contentShape(Rectangle())
                .padding(.vertical, 18)
            }
            .buttonStyle(.plain)

            DashedSeparator()
        }
    }

    @ViewBuilder
    private func settingsToggleRow(icon: String, title: String, isOn: Binding<Bool>, onChange: @escaping (Bool) -> Void) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(iconColor)
                    .frame(width: 26)

                Text(title)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.85)
                    .layoutPriority(0)

                Spacer()

                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(toggleOnColor)
                    .scaleEffect(0.85, anchor: .trailing)
                    .layoutPriority(1)
                    .onChange(of: isOn.wrappedValue) { _, newValue in
                        onChange(newValue)
                    }
            }
            .padding(.vertical, 12)
            .padding(.trailing, 4)
            .contentShape(Rectangle())

            DashedSeparator()
        }
    }
}

// MARK: - Dashed Separator

private struct DashedSeparator: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: geo.size.width, y: 0.5))
            }
            .stroke(Color.gray.opacity(0.35), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [6, 4]))
        }
        .frame(height: 1)
    }
}

#Preview {
    SettingsSheetView()
}
