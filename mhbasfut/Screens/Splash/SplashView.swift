//
//  SplashView.swift
//  mhbasfut
//
//  Super-light launch splash: renders the first frame in milliseconds with
//  zero heavy work (no images, no JSON, no view models, no sheets).
//  It masks the white system launch screen on cold start (iOS 27 simulator
//  was pegging CPU decoding the old 4K pitch photo) while ContentView/Home
//  finishes loading behind it.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("MHBasfut")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(Color(red: 1.00, green: 0.77, blue: 0.05))

                ProgressView()
                    .tint(Color(red: 1.00, green: 0.77, blue: 0.05))

                // Build marker: proves the new splash build is installed.
                // If you still see pure white, you are running a stale build.
                Text("cargando… build splash-1")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .onAppear {
                        print("[MHBasfut] Splash appeared (splash-1)")
                    }
            }
        }
    }
}

#Preview {
    SplashView()
}
