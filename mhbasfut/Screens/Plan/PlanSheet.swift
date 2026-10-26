//
//  PlanSheet.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 02/09/2026.
//

import SwiftUI
import UIKit

// MARK: - PlanSheetView
// Sequential navigation: dynamic stages from PlanViewModel (loaded from football_pla-1.json).
// Bottom arrows + COMPLETAR use the exact same 3D style as bottomButtonSheet.swift (SubmitButtonStyle).

struct PlanSheetView: View {
    @Environment(\.dismiss) var dismiss

    @ObservedObject var viewModel: PlanViewModel
    var onComplete: (() -> Void)?

    @State private var showingIntensitySheet = false
    @State private var pendingIntensityStageIndex: Int? = nil
    /// Training preferences (Settings → Preferencias de entrenamiento).
    @AppStorage("training.showObjectives") private var showObjectives: Bool = true
    @AppStorage("training.confirmComplete") private var confirmComplete: Bool = false
    @State private var showingConfirmAlert = false
    @State private var pendingConfirmIndex: Int? = nil

    private var dayLabel: String { viewModel.fullDayLabel }

    private var currentIndex: Int {
        get { viewModel.currentStageIndex }
        nonmutating set { viewModel.currentStageIndex = newValue }
    }
    private var completedSteps: Set<Int> { viewModel.completedStages }

    // Same palette as SettingsSheetView
    private let backgroundColor = Color(red: 28/255, green: 38/255, blue: 43/255) // #1C262B
    private let textColor = Color(red: 230/255, green: 235/255, blue: 238/255)
    private let objectiveColor = Color(red: 0.66, green: 0.69, blue: 0.71)
    private let bottomBarBackground = Color(red: 0.125, green: 0.173, blue: 0.20)

    private var steps: [PlanStep] { viewModel.steps }

    private var currentStep: PlanStep? {
        if steps.indices.contains(viewModel.currentStageIndex) {
            return steps[viewModel.currentStageIndex]
        }
        return steps.first
    }
    private var canGoBack: Bool { viewModel.currentStageIndex > 0 }
    private var canGoForward: Bool { viewModel.currentStageIndex < steps.count - 1 }
    private var isCurrentMeal: Bool {
        guard let step = currentStep else { return false }
        if case .meal = step.kind { return true }
        return false
    }

    // MARK: - Intensity valuation trigger (Plan 1)
    // A stage triggers the Borg sheet iff it is a training kind holding at
    // least one exercise: sessions-based stages, "entrenament" warmup/main,
    // and the single-card "club" / "recuperacio" / "descans" stages all decode
    // to PlanStep.Kind.training(exercises:) with a non-empty list. Meal stages
    // (.meal) never trigger. Empty training lists never trigger (no crash).
    private var isCurrentTrainingWithExercises: Bool {
        guard let step = currentStep else { return false }
        return IntensityLogic.isTrainingWithExercises(kind: step.kind)
    }

    private func shouldAskIntensity(for stageIndex: Int) -> Bool {
        guard viewModel.isTrainingStageWithExercises(at: stageIndex) else { return false }
        return !viewModel.hasIntensityRating(for: stageIndex)
    }

    private var isCompletarEnabled: Bool {
        if viewModel.completedStages.contains(viewModel.currentStageIndex) { return false }
        if viewModel.currentStageIndex == 0 { return true }
        for i in 0..<viewModel.currentStageIndex {
            if !viewModel.completedStages.contains(i) { return false }
        }
        return true
    }

    init(viewModel: PlanViewModel = PlanViewModel(), onComplete: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onComplete = onComplete
    }

    init(dayLabel: String = "Día 1: Fuerza general y estabilidad", initialIndex: Int = 0, onComplete: (() -> Void)? = nil) {
        let vm = PlanViewModel()
        if dayLabel.contains("Día") {
            let separator = dayLabel.contains(": ") ? ": " : " - "
            let parts = dayLabel.components(separatedBy: separator)
            if parts.count == 2 {
                vm.currentDayTitol = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        vm.currentStageIndex = initialIndex
        self.viewModel = vm
        self.onComplete = onComplete
    }

    init(title: String, objective: String? = nil, dayLabel: String = "Día 1: Fuerza general y estabilidad", onComplete: (() -> Void)? = nil) {
        let vm = PlanViewModel()
        vm.currentStageIndex = 0
        self.viewModel = vm
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundColor.ignoresSafeArea()
            if let step = currentStep {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .top) {
                            Text(step.title)
                                .font(.system(size: 34, weight: .heavy))
                                .foregroundColor(textColor)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(textColor)
                            }
                            .accessibilityLabel("Cerrar")
                            .padding(.top, 6)
                        }
                        if showObjectives, let objective = step.objective, !objective.isEmpty {
                            HStack(alignment: .top, spacing: 12) {
                                Capsule().fill(Color.white).frame(width: 5)
                                Text(objective)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(objectiveColor)
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 16)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            switch step.kind {
                            case .meal(let options):
                                MealOptionCarousel(options: options, viewModel: viewModel, stageIndex: viewModel.currentStageIndex)
                            case .training(let exercises):
                                ExerciseTimelineView(exercises: exercises)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 160)
                    }
                }
            } else {
                VStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
            }
            bottomBar
        }
        .disabled(showingIntensitySheet)
        .alert("¿Completar etapa?", isPresented: $showingConfirmAlert) {
            Button("Cancelar", role: .cancel) {
                pendingConfirmIndex = nil
            }
            Button("Completar") {
                proceedCompletar()
            }
        } message: {
            Text("La etapa se marcará como completada.")
        }
        .sheet(isPresented: $showingIntensitySheet) {
            IntensitySheetView(
                day: viewModel.currentDay,
                stageIndex: pendingIntensityStageIndex ?? viewModel.currentStageIndex
            ) { value in
                handleIntensityFinished(value: value)
            }
            .interactiveDismissDisabled(true)
        }
    }

    // MARK: - COMPLETAR with intensity interception

    /// Normal stage-advance path (meal selection + complete + dismiss + next).
    /// Runs only after the intensity flow has finished (or when it is skipped).
    private func completeStageNormally(index completedIndex: Int) {
        if steps.indices.contains(completedIndex), case .meal = steps[completedIndex].kind {
            let selectedOpt = viewModel.selectedMealOptions[completedIndex] ?? 0
            viewModel.saveMealSelection(stageIndex: completedIndex, optionIndex: selectedOpt)
        }
        viewModel.completeStage(index: completedIndex)
        onComplete?()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if viewModel.currentStageIndex == completedIndex {
                viewModel.advanceToNextStage()
            }
        }
    }

    /// Intercepts COMPLETAR: training stages with exercises show the Borg
    /// sheet first when that day + stage was never rated. Everything else
    /// completes immediately. Meal stages never trigger.
    private func handleCompletar() {
        guard isCompletarEnabled else { return }
        if confirmComplete {
            pendingConfirmIndex = viewModel.currentStageIndex
            showingConfirmAlert = true
            return
        }
        proceedCompletar()
    }

    /// Runs the intensity check / normal advance for the pending (or current)
    /// stage. Used both directly and after the confirmation alert.
    private func proceedCompletar() {
        let completedIndex = pendingConfirmIndex ?? viewModel.currentStageIndex
        pendingConfirmIndex = nil
        guard isCompletarEnabled, completedIndex == viewModel.currentStageIndex else { return }
        if shouldAskIntensity(for: completedIndex) {
            pendingIntensityStageIndex = completedIndex
            showingIntensitySheet = true
            return
        }
        completeStageNormally(index: completedIndex)
    }

    /// "He acabat": persist intensity, close the intensity sheet, then run the
    /// normal advance. The stage is never marked complete before this point,
    /// so killing the app mid-sheet leaves the stage unadvanced and the sheet
    /// appears again on the next COMPLETAR tap.
    private func handleIntensityFinished(value: Int) {
        let finishedIndex = pendingIntensityStageIndex ?? viewModel.currentStageIndex
        viewModel.saveIntensityRating(stageIndex: finishedIndex, value: value)
        pendingIntensityStageIndex = nil
        showingIntensitySheet = false
        completeStageNormally(index: finishedIndex)
    }

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(dayLabel)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 4)
            HStack(spacing: 12) {
                Button(action: {
                    guard canGoBack else { return }
                    viewModel.currentStageIndex -= 1
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .heavy))
                        .frame(width: 56, height: 18)
                }
                .buttonStyle(PlanArrowButtonStyle(isActive: canGoBack, isGreen: isCurrentMeal))
                .disabled(!canGoBack)

                Button(action: {
                    handleCompletar()
                }) {
                    let isMeal = isCurrentMeal
                    let isDone = viewModel.completedStages.contains(viewModel.currentStageIndex)
                    Text(isMeal ? (isDone ? "SELECCIONADO" : "SELECCIONAR") : (isDone ? "COMPLETADO" : "COMPLETAR"))
                }
                .buttonStyle(isCurrentMeal ? AnyButtonStyle(PlanSubmitGreenButtonStyle(isActive: isCompletarEnabled)) : AnyButtonStyle(PlanSubmitButtonStyle(isActive: isCompletarEnabled)))
                .disabled(!isCompletarEnabled)
                .animation(nil, value: isCompletarEnabled)

                Button(action: {
                    guard canGoForward else { return }
                    viewModel.currentStageIndex += 1
                }) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .heavy))
                        .frame(width: 56, height: 18)
                }
                .buttonStyle(PlanArrowButtonStyle(isActive: canGoForward, isGreen: isCurrentMeal))
                .disabled(!canGoForward)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            bottomBarBackground
                .clipShape(RoundedCorner(radius: 28, corners: [.topLeft, .topRight]))
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Meal Option Carousel (like second image)

private struct MealOptionCarousel: View {
    let options: [PlanMealOption]
    @ObservedObject var viewModel: PlanViewModel
    let stageIndex: Int

    private var selectedIndex: Int {
        viewModel.selectedMealOptions[stageIndex] ?? 0
    }

    var body: some View {
        VStack(spacing: 12) {
            // Pixel triangle indicator – asset ic_tirangle_indicator
            Image("ic_tirangle_indicator")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 28)
                .padding(.bottom, 4)

            // Horizontal pager: swipe to flip through options, snaps so one
            // card locks centered. The centered card is the selection.
            GeometryReader { geo in
                let cardWidth: CGFloat = 260
                let sideInset = max((geo.size.width - cardWidth) / 2, 0)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(options.enumerated()), id: \.offset) { idx, option in
                            MealCard(option: option)
                                .frame(width: cardWidth, height: 300)
                                .id(idx)
                                .onTapGesture {
                                    viewModel.selectedMealOptions[stageIndex] = idx
                                    viewModel.saveMealSelection(stageIndex: stageIndex, optionIndex: idx)
                                }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, sideInset)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: pageBinding, anchor: .center)
            }
            .frame(height: 320)

            // Selected option title below the card, on the background
            Text(options.indices.contains(selectedIndex) ? options[selectedIndex].name.lowercased() : "")
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, minHeight: 66)
        }
        .padding(.vertical, 8)
    }

    // The scroll position IS the selection: swiping to a card selects it,
    // tapping a card scrolls it into place.
    private var pageBinding: Binding<Int?> {
        Binding(
            get: { viewModel.selectedMealOptions[stageIndex] ?? 0 },
            set: {
                let val = $0 ?? 0
                viewModel.selectedMealOptions[stageIndex] = val
                viewModel.saveMealSelection(stageIndex: stageIndex, optionIndex: val)
            }
        )
    }
}

private struct MealCard: View {
    let option: PlanMealOption

    // Image-only card: no fills, no border, no text inside. The title is
    // rendered below the pager instead.
    var body: some View {
        ZStack {
            if let uiImage = planImage(named: option.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                // No food art bundled yet — placeholder holds the layout
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                Image(systemName: "photo.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Plan image loading
// Exercise webps are stored as Data assets (.dataset), which UIImage(named:)
// cannot see — they must be loaded via NSDataAsset. JSON `imatge` values carry
// a ".webp" suffix while the asset itself is named without it, so strip it.
// Falls back to UIImage(named:) for regular .imageset art.
private func planImage(named rawName: String) -> UIImage? {
    let baseName = rawName.hasSuffix(".webp")
        ? String(rawName.dropLast(".webp".count))
        : rawName
    if let asset = NSDataAsset(name: baseName), let image = UIImage(data: asset.data) {
        return image
    }
    if let asset = NSDataAsset(name: rawName), let image = UIImage(data: asset.data) {
        return image
    }
    return UIImage(named: baseName) ?? UIImage(named: rawName)
}

private struct PixelTriangle: Shape {    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        // pixelated downward triangle – stepped edges
        let step: CGFloat = w / 7
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w - step, y: step))
        path.addLine(to: CGPoint(x: w - step*1.5, y: step))
        path.addLine(to: CGPoint(x: w - step*1.5, y: step*2))
        path.addLine(to: CGPoint(x: w - step*2, y: step*2))
        path.addLine(to: CGPoint(x: w - step*2.5, y: step*3))
        path.addLine(to: CGPoint(x: w/2 + step, y: h))
        path.addLine(to: CGPoint(x: w/2 - step, y: h))
        path.addLine(to: CGPoint(x: step*2.5, y: step*3))
        path.addLine(to: CGPoint(x: step*2, y: step*3))
        path.addLine(to: CGPoint(x: step*2, y: step*2))
        path.addLine(to: CGPoint(x: step*1.5, y: step*2))
        path.addLine(to: CGPoint(x: step*1.5, y: step))
        path.addLine(to: CGPoint(x: step, y: step))
        path.addLine(to: CGPoint(x: step, y: 0))
        path.closeSubpath()
        return path
    }
}

// MARK: - Exercise Timeline (like first image)

private struct ExerciseTimelineView: View {
    let exercises: [PlanExercise]

    var body: some View {
        // One row per exercise coupling number + card, so each number stays
        // vertically centered on its own card. (The previous two-column layout
        // used a fixed 96pt connector while cards vary in height, which drifted
        // the numbers progressively off their cards.)
        VStack(spacing: 0) {
            ForEach(Array(exercises.enumerated()), id: \.offset) { idx, ex in
                HStack(alignment: .center, spacing: 14) {
                    // Pixel number
                    ZStack {
                        PlanPixelBox()
                            .fill(Color(red: 54/255, green: 71/255, blue: 81/255))
                            .frame(width: 44, height: 44)
                        Text("\(idx + 1)")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundColor(.white)
                    }
                    .frame(width: 44)

                    // Card
                    HStack(spacing: 12) {
                        // White image square
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white)
                                .frame(width: 84, height: 84)
                            Group {
                                if let uiImage = planImage(named: ex.imageName) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 70, height: 70)
                                } else {
                                    Image(systemName: "figure.run")
                                        .font(.system(size: 32, weight: .medium))
                                        .foregroundColor(.black.opacity(0.75))
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(ex.detail == "5 minuts" ? "5 minuts de \(ex.name.lowercased())" : ex.name)
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                            Text(ex.desc)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.55))
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(Color(red: 0.07, green: 0.07, blue: 0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                // Connector bridging the card gap, centered under the number
                // so the rail stays continuous between rows.
                if idx < exercises.count - 1 {
                    HStack(spacing: 14) {
                        Rectangle()
                            .fill(Color(red: 61/255, green: 77/255, blue: 90/255))
                            .frame(width: 4, height: 14)
                            .frame(width: 44)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 3D Button Styles – instant state change, no animation

private struct PlanSubmitButtonStyle: ButtonStyle {
    let isActive: Bool
    func makeBody(configuration: Configuration) -> some View {
        let activeFaceColor = Color(red: 0.996, green: 0.776, blue: 0.0) // yellow/orange for training
        let activeShadowColor = Color(red: 0.831, green: 0.627, blue: 0.0)
        let activeTextColor = Color(red: 0.05, green: 0.15, blue: 0.22)
        let inactiveFaceColor = Color(red: 0.467, green: 0.388, blue: 0.102)
        let inactiveShadowColor = Color(red: 0.369, green: 0.298, blue: 0.075)
        let inactiveTextColor = Color(red: 0.161, green: 0.216, blue: 0.255)
        let faceColor = isActive ? activeFaceColor : inactiveFaceColor
        let shadowColor = isActive ? activeShadowColor : inactiveShadowColor
        let textColor = isActive ? activeTextColor : inactiveTextColor
        let isPressed = configuration.isPressed && isActive
        let depthOffset: CGFloat = 6
        return configuration.label
            .font(.system(size: 16, weight: .heavy))
            .foregroundColor(textColor)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(faceColor))
            .offset(y: isPressed ? depthOffset : 0)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(shadowColor).offset(y: depthOffset))
            .animation(.easeOut(duration: 0.12), value: isPressed)
            .animation(nil, value: isActive)
            .padding(.bottom, depthOffset)
    }
}

private struct PlanSubmitGreenButtonStyle: ButtonStyle {
    let isActive: Bool
    func makeBody(configuration: Configuration) -> some View {
        let activeFaceColor = Color(red: 0.55, green: 0.82, blue: 0.18) // lime for SELECCIONAR
        let activeShadowColor = Color(red: 0.43, green: 0.64, blue: 0.13)
        let activeTextColor = Color(red: 0.05, green: 0.15, blue: 0.22)
        // Disabled in food mode stays solid muted green (not transparent) – avoids weird washed look
        let inactiveFaceColor = Color(red: 0.38, green: 0.56, blue: 0.14)
        let inactiveShadowColor = Color(red: 0.29, green: 0.44, blue: 0.10)
        let inactiveTextColor = Color(red: 0.08, green: 0.18, blue: 0.06)
        let faceColor = isActive ? activeFaceColor : inactiveFaceColor
        let shadowColor = isActive ? activeShadowColor : inactiveShadowColor
        let textColor = isActive ? activeTextColor : inactiveTextColor
        let isPressed = configuration.isPressed && isActive
        let depthOffset: CGFloat = 6
        return configuration.label
            .font(.system(size: 16, weight: .heavy))
            .foregroundColor(textColor)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(faceColor))
            .offset(y: isPressed ? depthOffset : 0)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(shadowColor).offset(y: depthOffset))
            .animation(.easeOut(duration: 0.12), value: isPressed)
            .animation(nil, value: isActive)
            .padding(.bottom, depthOffset)
    }
}

private struct PlanArrowButtonStyle: ButtonStyle {
    let isActive: Bool
    var isGreen: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        let activeFaceColor = isGreen ? Color(red: 0.55, green: 0.82, blue: 0.18) : Color(red: 0.996, green: 0.776, blue: 0.0)
        let activeShadowColor = isGreen ? Color(red: 0.43, green: 0.64, blue: 0.13) : Color(red: 0.831, green: 0.627, blue: 0.0)
        let activeTextColor = Color(red: 0.05, green: 0.15, blue: 0.22)
        // Food mode disabled stays solid muted green (not transparent/washed), exercise stays brown
        let inactiveFaceColor = isGreen ? Color(red: 0.38, green: 0.56, blue: 0.14) : Color(red: 0.467, green: 0.388, blue: 0.102)
        let inactiveShadowColor = isGreen ? Color(red: 0.29, green: 0.44, blue: 0.10) : Color(red: 0.369, green: 0.298, blue: 0.075)
        let inactiveTextColor = isGreen ? Color(red: 0.08, green: 0.18, blue: 0.06) : Color(red: 0.161, green: 0.216, blue: 0.255)
        let faceColor = isActive ? activeFaceColor : inactiveFaceColor
        let shadowColor = isActive ? activeShadowColor : inactiveShadowColor
        let textColor = isActive ? activeTextColor : inactiveTextColor
        let isPressed = configuration.isPressed && isActive
        let depthOffset: CGFloat = 6
        return configuration.label
            .font(.system(size: 16, weight: .heavy))
            .foregroundColor(textColor)
            .padding(.vertical, 16)
            .frame(width: 56)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(faceColor))
            .offset(y: isPressed ? depthOffset : 0)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(shadowColor).offset(y: depthOffset))
            .animation(.easeOut(duration: 0.12), value: isPressed)
            .animation(nil, value: isActive)
            .padding(.bottom, depthOffset)
    }
}

// Helper to erase ButtonStyle type
private struct AnyButtonStyle: ButtonStyle {
    let _makeBody: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { config in AnyView(style.makeBody(configuration: config)) }
    }
    func makeBody(configuration: Configuration) -> some View { _makeBody(configuration) }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

private struct PlanPixelBox: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width; let h = rect.height; let p = min(w,h)/8
        path.move(to: CGPoint(x: p*2, y: 0)); path.addLine(to: CGPoint(x: w - p*2, y: 0))
        path.addLine(to: CGPoint(x: w - p*2, y: p)); path.addLine(to: CGPoint(x: w - p, y: p))
        path.addLine(to: CGPoint(x: w - p, y: p*2)); path.addLine(to: CGPoint(x: w, y: p*2))
        path.addLine(to: CGPoint(x: w, y: h - p*2)); path.addLine(to: CGPoint(x: w - p, y: h - p*2))
        path.addLine(to: CGPoint(x: w - p, y: h - p)); path.addLine(to: CGPoint(x: w - p*2, y: h - p))
        path.addLine(to: CGPoint(x: w - p*2, y: h)); path.addLine(to: CGPoint(x: p*2, y: h))
        path.addLine(to: CGPoint(x: p*2, y: h - p)); path.addLine(to: CGPoint(x: p, y: h - p))
        path.addLine(to: CGPoint(x: p, y: h - p*2)); path.addLine(to: CGPoint(x: 0, y: h - p*2))
        path.addLine(to: CGPoint(x: 0, y: p*2)); path.addLine(to: CGPoint(x: p, y: p*2))
        path.addLine(to: CGPoint(x: p, y: p)); path.addLine(to: CGPoint(x: p*2, y: p))
        path.closeSubpath(); return path
    }
}

#Preview {
    PlanSheetView(viewModel: PlanViewModel())
}

#Preview("Desayuno") {
    let vm = PlanViewModel()
    vm.currentStageIndex = 0
    return PlanSheetView(viewModel: vm)
}
