//
//  ContentView.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("questionary.isCompleted") private var isQuestionnaireCompleted: Bool = false
    // Sesión de alumno: el sign-in va antes que todo (incluido el cuestionario).
    @AppStorage("student.username") private var studentUsername: String = ""
    // Sesión de invitado: app completa sin cuenta y sin enviar nada a GitHub.
    @AppStorage(GitHubSyncService.guestKey) private var isGuest: Bool = false

    var body: some View {
        Group {
            // Solo sin sesión (ni invitado) se pide entrar.
            if !isGuest && studentUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                StudentSignInView()
            } else if PlanRepo.shared.hasPlanExpired() {
                // El ciclo de 14 días caducó sin terminar el día 14: la app
                // devuelve directamente al cuestionario para evaluar y
                // arrancar el siguiente plan.
                QuestionaryScreen(forceRetake: true)
            } else if isQuestionnaireCompleted {
                HomeScreen()
            } else {
                QuestionaryScreen()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isQuestionnaireCompleted)
        .animation(.easeInOut(duration: 0.35), value: studentUsername)
        .animation(.easeInOut(duration: 0.35), value: isGuest)
    }
}

#Preview {
    ContentView()
        .fontDesign(.rounded)
}
