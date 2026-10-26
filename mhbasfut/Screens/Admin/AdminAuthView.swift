//
//  AdminAuthView.swift
//  mhbasfut
//
//  Plan Admin Data Sync – Paso 3.
//  Pantalla en español: "Vincular cuenta de profesor".
//  Usuario + Contraseña (entregados por WhatsApp). La sesión queda
//  abierta hasta desvincular explícitamente. Reutiliza la paleta
//  #1C262B, los TextField de PerfilSheet y el botón 3D BottomButton.
//

import SwiftUI

struct AdminAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sync = GitHubSyncService.shared

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var formError: String? = nil
    @State private var showLogoutConfirm: Bool = false
    @State private var showSwitchAccountConfirm: Bool = false

    private let backgroundColor = Color(red: 28/255, green: 38/255, blue: 43/255)
    private let textColor = Color(red: 230/255, green: 235/255, blue: 238/255)
    private let subtitleColor = Color(red: 0.66, green: 0.69, blue: 0.71)

    private var canLink: Bool {
        username.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 &&
        password.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4
    }

    private var lastSyncText: String {
        guard let date = sync.lastSyncDate else { return "Aún no se ha sincronizado." }
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.locale = Locale(identifier: "es_ES")
        return "Última sincronización: \(f.string(from: date))"
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Vincular cuenta de profesor")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(textColor)
                        .lineLimit(2)
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
                        if sync.isAdminMode {
                            adminModeCard
                        } else if sync.isLinked {
                            linkedCard
                        } else {
                            Text("Introduce el usuario y la contraseña que te ha dado tu profesor por WhatsApp. Solo tendrás que hacerlo una vez.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(subtitleColor)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Usuario")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(subtitleColor)
                                .padding(.horizontal, 4)

                            TextField("p. ej. alex_04", text: $username)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 18)
                                .background(fieldBackground)
                                .accessibilityLabel("Usuario")

                            Text("Contraseña")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(subtitleColor)
                                .padding(.horizontal, 4)

                            SecureField("Contraseña del profesor", text: $password)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 18)
                                .background(fieldBackground)
                                .accessibilityLabel("Contraseña")

                            if let formError {
                                Text(formError)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.45))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let serverError = sync.lastErrorMessage {
                                Text(serverError)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Text(lastSyncText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(subtitleColor)
                        }

                        if sync.isLinked, let serverError = sync.lastErrorMessage {
                            Text(serverError)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                }

                if sync.isAdminMode {
                    BottomButton(
                        subtitle: "Ningún dato sale de este dispositivo",
                        title: "Modo Admin",
                        buttonText: "SALIR DEL MODO ADMIN",
                        isActive: true
                    ) {
                        sync.studentSignOut()
                        dismiss()
                    }
                } else if sync.isLinked {
                    BottomButton(
                        subtitle: lastSyncText,
                        title: "Cuenta vinculada",
                        buttonText: sync.isSyncing ? "SINCRONIZANDO…" : "DESVINCULAR",
                        isActive: !sync.isSyncing
                    ) {
                        showLogoutConfirm = true
                    }
                } else {
                    BottomButton(
                        subtitle: "Tu progreso se compartirá con tu profesor",
                        title: "Sesión de alumno",
                        buttonText: sync.isSyncing ? "VINCULANDO…" : "VINCULAR",
                        isActive: canLink && !sync.isSyncing
                    ) {
                        attemptLink()
                    }
                }
            }
            .ignoresSafeArea(.container, edges: [.bottom, .horizontal])
        }
        .onAppear {
            username = sync.linkedUsername ?? ""
        }
        .alert("Cambiar de cuenta", isPresented: $showSwitchAccountConfirm) {
            Button("Cancelar", role: .cancel) { }
            Button("Continuar", role: .destructive) {
                Task {
                    // La cuenta distinta no hereda el progreso actual.
                    await sync.wipeLocalData()
                    performLink()
                }
            }
        } message: {
            Text("Al vincular otra cuenta se borrará el progreso guardado en este dispositivo.")
        }
        .alert("Desvincular cuenta", isPresented: $showLogoutConfirm) {
            Button("Cancelar", role: .cancel) { }
            Button("Desvincular", role: .destructive) {
                sync.logout()
                username = ""
                password = ""
                dismiss()
            }
        } message: {
            Text("Se cerrará la sesión y la app dejará de enviar tus datos al profesor. Podrás vincularla de nuevo cuando quieras.")
        }
    }

    // MARK: - Acciones

    /// Vincular valida contra la misma lista que el sign-in, así que ya no
    /// se puede escribir en el repo con un usuario inventado.
    private func attemptLink() {
        guard canLink else { return }
        let resolved = StudentAccounts.canonicalUsername(username)
        if let resolved, let current = sync.studentUsername, current != resolved {
            showSwitchAccountConfirm = true
            return
        }
        performLink()
    }

    private func performLink() {
        if let err = sync.link(username: username, password: password) {
            formError = err
        } else {
            formError = nil
            sync.requestSync(reason: .manual, force: true)
            dismiss()
        }
    }

    // MARK: - Subvistas

    private var linkedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(red: 0.55, green: 0.82, blue: 0.18))
                Text("Vinculada como \(sync.linkedUsername ?? "")")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.white)
            }
            Text("Tus datos (cuestionario, plan, comidas, intensidad, sueño, emoción, racha y recompensas) se envían automáticamente a tu profesor cuando completas actividades o la app pasa a segundo plano.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(subtitleColor)
                .fixedSize(horizontal: false, vertical: true)
            Text(lastSyncText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(subtitleColor)
            if sync.isSyncing {
                ProgressView()
                    .tint(.white)
                    .accessibilityLabel("Sincronizando")
            } else {
                Button(action: { sync.requestSync(reason: .manual, force: true) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sincronizar ahora")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.05))
                }
                .accessibilityLabel("Sincronizar ahora")
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

    /// Modo prueba: la app funciona como siempre, pero `uploadTarget`
    /// bloquea toda subida, así que no se crea `users/Admin.json` y el
    /// profesor no ve nada en la consola de la web.
    private var adminModeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(red: 0.55, green: 0.82, blue: 0.18))
                Text("Modo Admin activado")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.white)
            }
            Text("Estás en modo prueba. Puedes usar la app con normalidad, pero nada de lo que hagas se envía a GitHub ni aparece en la consola del profesor. Al salir volverás a la pantalla de inicio de sesión.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(subtitleColor)
                .fixedSize(horizontal: false, vertical: true)
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

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(red: 0.11, green: 0.14, blue: 0.18))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(red: 0.20, green: 0.25, blue: 0.32), lineWidth: 1.5)
            )
    }
}

#Preview {
    AdminAuthView()
}
