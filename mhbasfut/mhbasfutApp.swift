//
//  mhbasfutApp.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import SwiftUI

@main
struct mhbasfutApp: App {
    // Super-light splash first so the user never stares at the white system
    // launch screen while ContentView/Home does its heavy init (plan JSON,
    // pitch image, wellness check). ContentView is only created AFTER the
    // splash has committed its first frame.
    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // UI tests: `--uitest-reset` limpia el dominio persistente ANTES de
        // que se cree ningún estado (solo actúa cuando el runner lo pasa).
        if ProcessInfo.processInfo.arguments.contains("--uitest-reset"),
           let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
        #if DEBUG
        // Sonda de sincronización en vivo (solo Debug, solo con el argumento):
        // crea y borra users/AppSmokeTest.json para verificar la ruta real.
        if ProcessInfo.processInfo.arguments.contains("--sync-probe") {
            Task { @MainActor in await SyncProbe.run() }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                } else {
                    ContentView()
                }
            }
            // Global default: SF Pro Rounded for every Text in the app
            // (sheets and fullscreen covers inherit this too).
            .fontDesign(.rounded)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    // Admin Data Sync: al pasar a segundo plano → subir snapshot.
                    GitHubSyncService.shared.requestSync(reason: .background)
                } else if newPhase == .active {
                    // Gate de ciclo + posibles ediciones del panel admin:
                    // el remoto manda si su adminRevision es más nuevo.
                    PlanRepo.shared.enforceExpiryIfNeeded()
                    Task { @MainActor in
                        let applied = await GitHubSyncService.shared.applyRemoteOverridesIfNeeded()
                        if applied {
                            GitHubSyncService.shared.requestSync(reason: .manual)
                        }
                    }
                }
            }
            .onAppear {
                print("[MHBasfut] App WindowGroup appeared (splash-1)")
                // Gate de ciclo antes de que ContentView se cree (tras el
                // splash): ciclos caducados fuerzan el cuestionario.
                PlanRepo.shared.enforceExpiryIfNeeded()
                Task { @MainActor in
                    let applied = await GitHubSyncService.shared.applyRemoteOverridesIfNeeded()
                    if applied {
                        GitHubSyncService.shared.requestSync(reason: .manual)
                    }
                }
                // 0.6s is enough for the splash (zero assets) to hit the
                // window; heavy work starts only after this flips.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}

// Preview of a real screen wrapped exactly like the app entry does,
// so you can see SF Pro Rounded applied without touching the screen itself.
#Preview("App - Home Screen") {
    HomeScreen()
        .fontDesign(.rounded)
}
