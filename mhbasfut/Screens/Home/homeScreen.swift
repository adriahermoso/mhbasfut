import SwiftUI

struct HomeScreen: View {
    @State private var showingStreakSheet = false
    @State private var showingRewardsSheet = false
    @State private var showingSettingsSheet = false
    @State private var showingPlanSheet = false
    @StateObject private var rewardsViewModel = RewardsViewModel()
    @StateObject private var planViewModel = PlanViewModel()
    @StateObject private var streakViewModel = StreakViewModel()
    /// Sport chosen in the questionnaire — drives pitch vs court background + ball.
    @AppStorage("questionary.selectedSport") private var selectedSport: String = "Futbol"
    /// Gate for the Sleep/Emotion sheets (HomeScreen only exists post-test,
    /// but the flag is re-checked so the sheets never fire mid-onboarding).
    @AppStorage("questionary.isCompleted") private var isQuestionnaireCompleted: Bool = false
    /// Plan 2 sequential sheets: Sleep first, then Emotion — never together.
    /// Single `item`-based sheet (instead of two `isPresented` sheets on the
    /// same view) so SwiftUI never tries to present/dismiss two sheets at
    /// once — that race is what left a blank white screen on launch when the
    /// happiness/sleep check fired the moment the app appeared.
    private enum WellnessSheet: Identifiable {
        case sleep
        case emotion

        var id: Self { self }
    }

    @State private var activeWellnessSheet: WellnessSheet?
    
    var body: some View {
        ZStack {
            // 1. Root Background
            Color(red: 0.125, green: 0.173, blue: 0.20)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // 2. Top Section (Pitch + Header)
                ZStack {
                    PitchProgressView(viewModel: planViewModel, sport: selectedSport)
                        .ignoresSafeArea(edges: .top)
                        .id(selectedSport)
                    
                    VStack(spacing: 0) {
                        
                        // Header
                        HStack {
                            // Coins / Rewards Button
                            Button(action: {
                                showingRewardsSheet = true
                            }) {
                                HStack(spacing: 6) {
                                    Image("ic_coin")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                    
                                    Text("\(rewardsViewModel.coins)")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Spacer()
                            
                            // Fire / Streak Button
                            Button(action: {
                                showingStreakSheet = true
                            }) {
                                HStack(spacing: 6) {
                                    Image("ic_fire")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                    
                                    Text("\(streakViewModel.currentStreakCount)")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Spacer()
                            
                            // Settings Button
                            Button(action: {
                                showingSettingsSheet = true
                            }) {
                                Image("ic_settings")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 3. Bottom Section – dynamic day / stage from PlanViewModel
                let isAllDone = planViewModel.isCurrentDayFullyCompleted
                BottomButton(
                    subtitle: planViewModel.fullDayLabel,
                    title: isAllDone ? "¡TODO COMPLETADO POR HOY!" : planViewModel.currentStageTitle,
                    buttonText: isAllDone ? "VER DÍA" : "EMPEZAR",
                    isActive: true
                ) {
                    showingPlanSheet = true
                }
                .padding(.top, -28)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        // NOTE: do NOT add .disabled(activeWellnessSheet != nil) here.
        // .disabled writes isEnabled=false into the environment, which is
        // inherited by presented sheets — it would disable the Sleep/Emotion
        // option buttons themselves and freeze the app on the sheet.
        // The non-dismissable sheet already blocks Home behind it.
        .onAppear {
            planViewModel.refresh()
            streakViewModel.refresh()
            // Defer wellness check until Home has finished its first layout
            // and the window is key. Presenting a sheet synchronously (or
            // next-runloop) the moment the app loads raced the window on
            // iOS 27 and left a pure white screen. 0.8s lets the pitch,
            // header and BottomButton commit first; the sheet then slides
            // over a rendered Home instead of a blank window.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                evaluateWellnessSheets()
            }
        }
        .sheet(isPresented: $showingRewardsSheet) {
            RewardsSheetView(viewModel: rewardsViewModel)
        }
        .sheet(isPresented: $showingStreakSheet) {
            StreakSheetView()
        }
        .sheet(isPresented: $showingSettingsSheet, onDismiss: {
            planViewModel.refresh()
            streakViewModel.refresh()
        }) {
            SettingsSheetView()
        }
        .sheet(isPresented: $showingPlanSheet, onDismiss: {
            planViewModel.refresh()
            streakViewModel.refresh()
        }) {
            PlanSheetView(viewModel: planViewModel) {
                streakViewModel.refresh()
            }
        }
        .sheet(item: $activeWellnessSheet, onDismiss: handleWellnessDismiss) { sheet in
            if sheet == .sleep {
                SleepQualitySheetView { rating in
                    handleSleepSelected(rating)
                }
            } else {
                EmotionSheetView { rating in
                    handleEmotionSelected(rating)
                }
            }
        }
    }

    // MARK: - Plan 2: Sleep Quality → Emotion Rater (sequential, blocking)

    /// Evaluates Sleep rules first, then Emotion — only on HomeScreen
    /// appearance with a completed questionnaire. Nothing is persisted until
    /// the user taps an option, so a force-quit re-shows the same sheet.
    private func evaluateWellnessSheets() {
        guard isQuestionnaireCompleted else { return }
        guard activeWellnessSheet == nil else { return }
        let answers = QuestionaryRepo().getSavedAnswers()
        if WellnessRepo.isSleepSheetDue(now: Date(), savedAnswers: answers) {
            activeWellnessSheet = .sleep
        } else if WellnessRepo.isEmotionDue(now: Date()) {
            activeWellnessSheet = .emotion
        }
    }

    private func handleSleepSelected(_ rating: Int) {
        WellnessRepo.saveSleepQuality(rating: rating, date: Date())
        GitHubSyncService.shared.requestSync(reason: .wellness)
        // Dismiss first; the emotion follow-up is presented from
        // handleWellnessDismiss (after the dismiss animation finishes),
        // never via a fixed-delay asyncAfter that could fire while the
        // sleep sheet is still dismissing and blank the screen.
        activeWellnessSheet = nil
    }

    private func handleEmotionSelected(_ rating: Int) {
        WellnessRepo.saveEmotion(rating: rating, date: Date())
        GitHubSyncService.shared.requestSync(reason: .wellness)
        activeWellnessSheet = nil
    }

    /// Chained second step: Sleep first, then Emotion — never together.
    /// Fires after the sleep sheet's dismiss animation completes, so the
    /// two sheets are strictly sequential.
    private func handleWellnessDismiss() {
        guard isQuestionnaireCompleted else { return }
        guard activeWellnessSheet == nil else { return }
        // Only chain to emotion when sleep was actually completed today;
        // otherwise this was an emotion dismiss (or a fresh launch) and
        // there is nothing more to show.
        guard WellnessRepo.hasSleepQuality(for: Date()) else { return }
        guard WellnessRepo.isEmotionDue(now: Date()) else { return }
        DispatchQueue.main.async {
            // Re-guard inside: the user could have backgrounded the app
            // during the dismiss animation.
            guard activeWellnessSheet == nil else { return }
            activeWellnessSheet = .emotion
        }
    }
}

// MARK: - Preview
struct HomeScreen_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreen()
    }
}
