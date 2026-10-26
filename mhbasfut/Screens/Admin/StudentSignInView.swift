//
//  StudentSignInView.swift
//  mhbasfut
//
//  Sign-in de alumno: primera pantalla antes del cuestionario.
//  Usuario + Contraseña (repartidos por WhatsApp, hardcodeados de forma
//  temporal en StudentAccounts). La sesión persiste hasta "Cerrar sesión"
//  en Ajustes. Reutiliza la paleta #1C262B, los TextField de PerfilSheet
//  y el botón 3D BottomButton.
//

import SwiftUI

struct StudentSignInView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String? = nil
    @State private var isEntering: Bool = false

    private let backgroundColor = Color(red: 28/255, green: 38/255, blue: 43/255)
    private let textColor = Color(red: 230/255, green: 235/255, blue: 238/255)
    private let subtitleColor = Color(red: 0.66, green: 0.69, blue: 0.71)

    private var canEnter: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty && !isEntering
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bienvenido a MHBasFut")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(textColor)
                    Text("Inicia sesión con tu cuenta de jugador, o entra sin cuenta para empezar")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(subtitleColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.top, 64)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Usuario")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(subtitleColor)
                            .padding(.horizontal, 4)

                        TextField("p. ej. HugoMartinez", text: $username)
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

                        SecureField("Tu contraseña", text: $password)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                            .background(fieldBackground)
                            .accessibilityLabel("Contraseña")

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.45))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 16)
                }

                // Acceso sin cuenta: la app completa, sin enviar nada a ningún sitio.
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: { enterAsGuest() }) {
                        Text("ENTRAR SIN CUENTA")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(red: 0.16, green: 0.21, blue: 0.26))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color(red: 0.35, green: 0.42, blue: 0.50), lineWidth: 1.5)
                                    )
                            )
                    }
                    .accessibilityLabel("Entrar sin cuenta")
                    .accessibilityHint("Usa la app completa sin registrarte; tus datos no salen del dispositivo")

                    Text("Sin cuenta, tus datos se quedan en tu móvil y no se envían a ningún sitio. Si luego te dan una cuenta de jugador, sal del modo invitado desde Ajustes.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(subtitleColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 14)

                BottomButton(
                    subtitle: "Tu progreso se compartirá con tu profesor",
                    title: "Sesión de jugador",
                    buttonText: isEntering ? "ENTRANDO…" : "ENTRAR",
                    isActive: canEnter
                ) {
                    enter()
                }
            }
            .ignoresSafeArea(.container, edges: [.bottom, .horizontal])
        }
    }

    private func enter() {
        guard canEnter else { return }
        isEntering = true
        // Pequeño respiro para que el botón muestre ENTRANDO… antes del cambio de pantalla.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if let err = GitHubSyncService.shared.studentSignIn(username: username, password: password) {
                errorMessage = err
                isEntering = false
            }
            // Si ok, ContentView cambia sola a cuestionario/Home (sesión en UserDefaults).
        }
    }

    /// Sesión de invitado: app completa, sin cuenta y sin salir de la red.
    private func enterAsGuest() {
        GitHubSyncService.shared.startGuestSession()
        // ContentView cambia sola al cuestionario/Home.
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
    StudentSignInView()
}
