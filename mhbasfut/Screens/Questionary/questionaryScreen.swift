//
//  questionaryScreen.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import SwiftUI
import UIKit

public struct QuestionaryScreen: View {
    @StateObject private var viewModel: QuestionaryViewModel
    
    public init(forceRetake: Bool = false) {
        _viewModel = StateObject(wrappedValue: QuestionaryViewModel(forceRetake: forceRetake))
    }
    
    public var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.12)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with back button & progress bar
                HStack(spacing: 14) {
                    if viewModel.state == .answering {
                        Button(action: {
                            viewModel.goToPrevious()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 38, height: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(red: 0.16, green: 0.20, blue: 0.24))
                                )
                        }
                    }
                    
                    PixelProgressBar(progress: viewModel.progress)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if viewModel.state == .selectingSport {
                            sportSelectionView
                        } else if viewModel.state == .answering, let question = viewModel.currentQuestion {
                            questionView(for: question)
                        } else if viewModel.state == .finished {
                            QuestionaryFinishedView(viewModel: viewModel)
                        }
                    }
                    .padding(.bottom, 30)
                }
                .scrollDismissesKeyboard(.interactively)
                
                Spacer(minLength: 0)
                
                bottomSheet
            }
            .ignoresSafeArea(.container, edges: [.bottom, .horizontal])
        }
    }
    
    // MARK: - Sport Selection
    
    private var sportSelectionView: some View {
        HStack(spacing: 16) {
            OptionButton(
                mode: .horizontal(imageAsset: "football_ball_gold"),
                text: "Futbol",
                isSelected: viewModel.selectedSport == "Futbol"
            ) {
                viewModel.selectedSport = "Futbol"
            }
            
            OptionButton(
                mode: .horizontal(imageAsset: "basquet_ball_gold"),
                text: "Basquet",
                isSelected: viewModel.selectedSport == "Basquet"
            ) {
                viewModel.selectedSport = "Basquet"
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    // MARK: - Dynamic Question View
    
    private func questionView(for question: Question) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // Category tag
            if let category = question.category {
                HStack(spacing: 6) {
                    Image(systemName: categoryIcon(for: category))
                        .font(.system(size: 13, weight: .bold))
                    Text(category.uppercased())
                        .font(.system(size: 12, weight: .heavy))
                }
                .foregroundColor(Color(red: 1.00, green: 0.77, blue: 0.05))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(red: 1.00, green: 0.77, blue: 0.05).opacity(0.15))
                )
                .padding(.bottom, 4)
            }
            
            if let explanation = question.explanation, !explanation.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 6)
                    
                    Text(explanation)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.66, green: 0.69, blue: 0.71))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
            
            if let imageName = question.imageName, !imageName.isEmpty {
                if let uiImage = questionaryImage(named: imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.vertical, 4)
                }
            }

            if question.diagram == "t_test" {
                TTestDiagramView()
                    .padding(.vertical, 4)
            }
            
            switch question.questionType {
            case .options:
                VStack(spacing: 12) {
                    ForEach(question.answers, id: \.self) { answer in
                        OptionButton(
                            mode: .vertical(systemIcon: QuestionIconProvider.iconName(question: question, answer: answer, sport: viewModel.selectedSport)),
                            text: answer,
                            isSelected: viewModel.selectedAnswer == answer
                        ) {
                            viewModel.selectedAnswer = answer
                        }
                    }
                }
                
            case .slider:
                QuestionarySliderView(
                    question: question,
                    value: $viewModel.currentSliderValue
                )
                
            case .field, .fields:
                QuestionaryFieldsView(
                    question: question,
                    fieldValues: $viewModel.currentFieldValues,
                    viewModel: viewModel
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Dades personals i esportives": return "person.crop.circle"
        case "Son i descans": return "moon.stars.fill"
        case "Nutrició i hidratació": return "fork.knife"
        case "Recuperació muscular": return "bolt.heart.fill"
        case "Salut mental i benestar": return "brain.head.profile"
        case "Hàbits saludables": return "heart.text.square.fill"
        case "Prevenció de lesions": return "shield.fill"
        case "Proves físiques": return "figure.run"
        default: return "questionmark.circle.fill"
        }
    }
    
    // MARK: - Bottom Sheet
    
    private var bottomSheet: some View {        let isSelecting = viewModel.state == .selectingSport
        let isFinished = viewModel.state == .finished
        let isActive = viewModel.isCurrentAnswerValid
        
        let subtitle: String
        let title: String
        let btnText: String
        
        if isSelecting {
            subtitle = "Las preguntas empezarán cuando elijas el deporte."
            title = "¿QUÉ DEPORTE PRACTICAS?"
            btnText = "EMPEZAR"
        } else if isFinished {
            subtitle = "TEST INICIAL COMPLETADO"
            title = "TODO LISTO PARA EMPEZAR"
            btnText = "FINALIZAR"
        } else {
            subtitle = "Pregunta \(viewModel.currentQuestionIndex + 1)/\(viewModel.questions.count)"
            title = viewModel.currentQuestion?.question ?? ""
            btnText = "CONTINUAR"
        }
        
        return BottomButton(
            subtitle: subtitle,
            title: title,
            buttonText: btnText,
            isActive: isActive
        ) {
            viewModel.continueToNext()
        }
    }
}

// MARK: - T-Test cones diagram (native UI, no image asset needed)

public struct TTestDiagramView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Text("4 CONS EN FORMA DE T")
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(Color(red: 1.00, green: 0.77, blue: 0.05))

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let cx = w * 0.5
                let cy = h * 0.5
                let b = CGPoint(x: cx, y: h * 0.10)
                let s = CGPoint(x: cx, y: h * 0.90)
                let c = CGPoint(x: w * 0.16, y: cy)
                let a = CGPoint(x: cx, y: cy)
                let d = CGPoint(x: w * 0.84, y: cy)

                ZStack {
                    // Vertical route S → A → B (solid)
                    Path { p in
                        p.move(to: s)
                        p.addLine(to: b)
                    }
                    .stroke(Color(red: 0.66, green: 0.69, blue: 0.71), lineWidth: 2)

                    // Horizontal C → A (dashed, lateral)
                    Path { p in
                        p.move(to: c)
                        p.addLine(to: a)
                    }
                    .stroke(Color(red: 0.66, green: 0.69, blue: 0.71), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))

                    // Horizontal A → D (solid, lateral)
                    Path { p in
                        p.move(to: a)
                        p.addLine(to: d)
                    }
                    .stroke(Color(red: 1.00, green: 0.77, blue: 0.05), lineWidth: 2)

                    // Cones
                    cone(at: b)
                    cone(at: s)
                    cone(at: c)
                    cone(at: a)
                    cone(at: d)

                    // Labels
                    coneLabel("B", at: CGPoint(x: b.x, y: b.y - 20))
                    coneLabel("S", at: CGPoint(x: s.x, y: s.y + 20))
                    coneLabel("C", at: CGPoint(x: c.x - 20, y: c.y))
                    coneLabel("A", at: CGPoint(x: a.x + 22, y: a.y))
                    coneLabel("D", at: CGPoint(x: d.x + 20, y: d.y))
                }
            }
            .frame(height: 200)

            Text("S → A → B → C → A → S")
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(Color(red: 1.00, green: 0.77, blue: 0.05))
        }
        .padding(18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.18, green: 0.22, blue: 0.28))
                    .offset(y: 4)

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.11, green: 0.14, blue: 0.18))

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(red: 0.18, green: 0.22, blue: 0.28), lineWidth: 1.5)
            }
        )
        .padding(.bottom, 4)
    }

    private func cone(at point: CGPoint) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 13, height: 13)
            .position(point)
    }

    private func coneLabel(_ text: String, at point: CGPoint) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.white)
            .position(point)
    }
}

// MARK: - Questionary image loading
// Exercise webps are stored as Data assets (.dataset), which SwiftUI Image(name:) / UIImage(named:) cannot see - they must be loaded via NSDataAsset, same as PlanSheet planImage(named:).
private func questionaryImage(named rawName: String) -> UIImage? {
    let baseName = rawName.hasSuffix(".webp") ? String(rawName.dropLast(".webp".count)) : rawName
    if let asset = NSDataAsset(name: baseName), let image = UIImage(data: asset.data) {
        return image
    }
    if let asset = NSDataAsset(name: rawName), let image = UIImage(data: asset.data) {
        return image
    }
    return UIImage(named: baseName) ?? UIImage(named: rawName)
}

// MARK: - Interactive 3D Slider Component

public struct QuestionarySliderView: View {
    let question: Question
    @Binding var value: Double
    
    private var minVal: Double { question.min ?? 1.0 }
    private var maxVal: Double { question.max ?? 10.0 }
    private var stepVal: Double { question.step ?? 1.0 }
    
    private var formattedValue: String {
        if stepVal >= 1.0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Main Value Readout Card
            VStack(spacing: 8) {
                Text(formattedValue)
                    .font(.system(size: 48, weight: .heavy))
                    .foregroundColor(Color(red: 1.00, green: 0.77, blue: 0.05))
                
                if let unit = question.unit {
                    Text(unit.uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.66, green: 0.69, blue: 0.71))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 1.00, green: 0.77, blue: 0.05))
                        .offset(y: 4)
                    
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 0.11, green: 0.14, blue: 0.18))
                    
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(red: 1.00, green: 0.77, blue: 0.05), lineWidth: 1.5)
                }
            )
            .padding(.bottom, 4)
            
            // Slider Control Card
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    Button(action: {
                        let next = max(minVal, value - stepVal)
                        value = (next * 10).rounded() / 10
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0.16, green: 0.20, blue: 0.26))
                            )
                    }
                    .disabled(value <= minVal)
                    
                    Slider(value: $value, in: minVal...maxVal, step: stepVal)
                        .tint(Color(red: 1.00, green: 0.77, blue: 0.05))
                    
                    Button(action: {
                        let next = min(maxVal, value + stepVal)
                        value = (next * 10).rounded() / 10
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0.16, green: 0.20, blue: 0.26))
                            )
                    }
                    .disabled(value >= maxVal)
                }
                
                HStack {
                    Text(formatBound(minVal))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0.66, green: 0.69, blue: 0.71))
                    
                    Spacer()
                    
                    Text(formatBound(maxVal))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0.66, green: 0.69, blue: 0.71))
                }
                .padding(.horizontal, 4)
            }
            .padding(18)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 0.18, green: 0.22, blue: 0.28))
                        .offset(y: 4)
                    
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 0.11, green: 0.14, blue: 0.18))
                    
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(red: 0.18, green: 0.22, blue: 0.28), lineWidth: 1.5)
                }
            )
            .padding(.bottom, 4)
        }
    }
    
    private func formatBound(_ val: Double) -> String {
        if stepVal >= 1.0 {
            return String(format: "Mín: %.0f", val)
        } else {
            return String(format: "%.1f", val)
        }
    }
}

// MARK: - Interactive 3D Text / Numeric Fields Component

public struct QuestionaryFieldsView: View {
    let question: Question
    @Binding var fieldValues: [String: String]
    @ObservedObject var viewModel: QuestionaryViewModel
    
    public init(question: Question, fieldValues: Binding<[String: String]>, viewModel: QuestionaryViewModel) {
        self.question = question
        self._fieldValues = fieldValues
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            if question.questionType == .field {
                fieldCard(
                    label: question.question,
                    placeholder: question.placeholder ?? "Introduce tu respuesta",
                    key: "single",
                    inputType: question.resolvedSingleInputType()
                )
            } else if let fields = question.fields {
                ForEach(fields) { field in
                    fieldCard(
                        label: field.label,
                        placeholder: field.placeholder,
                        key: field.key,
                        inputType: field.resolvedInputType(questionId: question.id)
                    )
                }
            }
        }
    }
    
    private func keyboardType(for type: FieldInputType) -> UIKeyboardType {
        switch type {
        case .integer: return .numberPad
        case .decimal: return .decimalPad
        case .time: return .numbersAndPunctuation
        case .text: return .default
        }
    }
    
    private func fieldCard(label: String, placeholder: String, key: String, inputType: FieldInputType) -> some View {
        let binding = Binding<String>(
            get: { fieldValues[key] ?? "" },
            set: {
                let filtered = QuestionaryValidation.filter($0, for: inputType)
                // For numeric/time types only allow filtered chars; text passes through.
                fieldValues[key] = (inputType == .text) ? $0 : filtered
            }
        )
        let raw = binding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let error = viewModel.fieldError(for: key)
        let hasError = error != nil && !raw.isEmpty
        let isFilled = !raw.isEmpty && !hasError
        let activeColor: Color = hasError
            ? Color(red: 0.95, green: 0.30, blue: 0.30)
            : (isFilled ? Color(red: 1.00, green: 0.77, blue: 0.05) : Color(red: 0.18, green: 0.22, blue: 0.28))
        
        return VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(red: 0.75, green: 0.78, blue: 0.81))
                .padding(.horizontal, 4)
            
            HStack {
                TextField(placeholder, text: binding)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .keyboardType(keyboardType(for: inputType))
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(activeColor)
                        .offset(y: 4)
                    
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.11, green: 0.14, blue: 0.18))
                    
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(activeColor, lineWidth: 1.5)
                }
            )
            .padding(.bottom, hasError ? 0 : 4)

            if hasError, let error {
                Text(error)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.45))
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
            }
        }
    }
}

// MARK: - Reusable Score / Punctuation Card (also used by progressSheet)

public struct QuestionaryScoreCard: View {
    let score: QuestionaryScore?

    public init(score: QuestionaryScore?) {
        self.score = score
    }

    private var total: Int { score?.total ?? 0 }
    private var level: String { score?.levelText ?? "Completa el test para ver tu puntuación" }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("TU PUNTUACIÓN")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(Color(red: 1.00, green: 0.77, blue: 0.05))

                Spacer()

                Text("14 DÍAS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(red: 0.20, green: 0.25, blue: 0.30)))
            }

            // Total readout
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(total)")
                    .font(.system(size: 52, weight: .heavy))
                    .foregroundColor(Color(red: 1.00, green: 0.77, blue: 0.05))
                Text("/ 100 pts")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.75, green: 0.78, blue: 0.81))
                Spacer()
            }
            Text(level)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            VStack(spacing: 10) {
                pillarRow(icon: "moon.stars.fill", category: "Son i descans", shortTitle: "Sueño y descanso")
                pillarRow(icon: "fork.knife", category: "Nutrició i hidratació", shortTitle: "Nutrición e hidratación")
                pillarRow(icon: "bolt.heart.fill", category: "Recuperació muscular", shortTitle: "Recuperación muscular")
                pillarRow(icon: "shield.fill", category: "Prevenció de lesions", shortTitle: "Prevención de lesiones")
                pillarRow(icon: "brain.head.profile", category: "Salut mental i benestar", shortTitle: "Salud mental")
                pillarRow(icon: "heart.text.square.fill", category: "Hàbits saludables", shortTitle: "Hábitos saludables")
            }

            Divider()
                .background(Color(red: 0.25, green: 0.30, blue: 0.35))
                .padding(.vertical, 4)

            HStack {
                Text("PUNTUACIÓN TOTAL")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 0.75, green: 0.78, blue: 0.81))

                Spacer()

                Text("\(total) pts")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(Color(red: 1.00, green: 0.77, blue: 0.05))
            }

            if let date = score?.date {
                Text("Calculado el \(formattedDate(date))" + (score?.sport.map { " • \($0)" } ?? ""))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.66, green: 0.69, blue: 0.71))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.11, green: 0.14, blue: 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(red: 0.20, green: 0.25, blue: 0.32), lineWidth: 1.5)
                )
        )
    }

    private func pillarRow(icon: String, category: String, shortTitle: String) -> some View {
        let earned = score?.points(for: category) ?? 0
        let max = QuestionaryScore.categoryMax[category] ?? 0
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(red: 1.00, green: 0.77, blue: 0.05))
                .frame(width: 24)

            Text(shortTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Text("\(formatPoints(earned)) / \(Int(max)) pts")
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(Color(red: 0.75, green: 0.78, blue: 0.81))
        }
        .padding(.vertical, 3)
    }

    private func formatPoints(_ v: Double) -> String {
        if v.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(v))"
        }
        return String(format: "%.1f", v)
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "ca_ES")
        return f.string(from: date)
    }
}

// MARK: - Finished Specific Content View

public struct QuestionaryFinishedView: View {
    @ObservedObject var viewModel: QuestionaryViewModel
    
    public var body: some View {
        VStack(spacing: 22) {
            // Header Emblem & Title
            VStack(spacing: 14) {
                Image(viewModel.selectedSport == "Basquet" ? "basquet_ball_gold" : "football_ball_gold")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 86, height: 86)
                
                Text("Perfil de Entrenamiento Invisible")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Tu diagnóstico inicial de \(viewModel.selectedSport == "Basquet" ? "básquet" : "fútbol") ha sido registrado correctamente. A continuación tienes el desglose de tu plan.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(red: 0.66, green: 0.69, blue: 0.71))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .padding(.top, 12)
            
            // Dynamic score card computed from the user's answers (was static 100 pts before)
            QuestionaryScoreCard(score: viewModel.finalScore)

            assignedPlanCard(planNumber: viewModel.assignedPlanNumber)
            
            // Performance Scale Explanation
            VStack(alignment: .leading, spacing: 10) {
                Text("ESCALA DE SEGUIMIENTO")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(Color(red: 1.00, green: 0.77, blue: 0.05))
                
                scaleItem(range: "90–100 pts", desc: "Entrenamiento invisible excelente", color: Color(red: 0.30, green: 0.85, blue: 0.40))
                scaleItem(range: "80–89 pts", desc: "Entrenamiento invisible muy bueno", color: Color(red: 0.55, green: 0.82, blue: 0.18))
                scaleItem(range: "70–79 pts", desc: "Entrenamiento invisible bueno", color: Color(red: 1.00, green: 0.77, blue: 0.05))
                scaleItem(range: "60–69 pts", desc: "Entrenamiento invisible mejorable", color: Color(red: 1.00, green: 0.55, blue: 0.10))
                scaleItem(range: "< 60 pts", desc: "Entrenamiento invisible deficiente", color: Color(red: 0.95, green: 0.30, blue: 0.30))
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
    }
    
    private func pillarRow(icon: String, title: String, points: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(red: 1.00, green: 0.77, blue: 0.05))
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Text("\(points) pts")
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(Color(red: 0.75, green: 0.78, blue: 0.81))
        }
        .padding(.vertical, 3)
    }
    
    private func scaleItem(range: String, desc: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(range)
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: 80, alignment: .leading)
            
            Text(desc)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(red: 0.66, green: 0.69, blue: 0.71))
            
            Spacer()
        }
    }

    private func assignedPlanCard(planNumber: Int) -> some View {
        let levelNames = ["", "Inicial", "Básico-Intermedio", "Avanzado", "Alto"]
        let level = (1...4).contains(planNumber) ? levelNames[planNumber] : ""
        return HStack(spacing: 14) {
            Text("PLAN \(planNumber)")
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(Color(red: 1.00, green: 0.77, blue: 0.05))

            VStack(alignment: .leading, spacing: 4) {
                Text("TU PLAN ASIGNADO")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(Color(red: 1.00, green: 0.77, blue: 0.05))
                Text("Nivel \(level) según tus pruebas físicas")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            Spacer()
        }
        .padding(18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 1.00, green: 0.77, blue: 0.05))
                    .offset(y: 4)

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.11, green: 0.14, blue: 0.18))

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(red: 1.00, green: 0.77, blue: 0.05), lineWidth: 1.5)
            }
        )
        .padding(.bottom, 4)
    }
}

// MARK: - Pixel Progress Bar Shape Components

public struct PixelProgressBar: View {
    public var progress: Double
    let pixelSize: CGFloat = 4
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                PixelShape(pixelSize: pixelSize)
                    .fill(Color(red: 0.16, green: 0.20, blue: 0.24))
                    .overlay(
                        PixelShape(pixelSize: pixelSize)
                            .stroke(Color(red: 0.25, green: 0.30, blue: 0.35), lineWidth: 2)
                    )
                
                PixelShape(pixelSize: pixelSize)
                    .fill(Color(red: 1.0, green: 0.65, blue: 0.15))
                    .frame(width: max(0, geometry.size.width * CGFloat(progress)))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
                    .mask(PixelShape(pixelSize: pixelSize))
            }
        }
        .frame(height: 20)
    }
}

fileprivate struct PixelShape: Shape {
    var pixelSize: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let p = pixelSize
        
        path.move(to: CGPoint(x: p * 2, y: 0))
        path.addLine(to: CGPoint(x: rect.width - p * 2, y: 0))
        
        path.addLine(to: CGPoint(x: rect.width - p * 2, y: p))
        path.addLine(to: CGPoint(x: rect.width - p, y: p))
        path.addLine(to: CGPoint(x: rect.width - p, y: p * 2))
        path.addLine(to: CGPoint(x: rect.width, y: p * 2))
        
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - p * 2))
        
        path.addLine(to: CGPoint(x: rect.width - p, y: rect.height - p * 2))
        path.addLine(to: CGPoint(x: rect.width - p, y: rect.height - p))
        path.addLine(to: CGPoint(x: rect.width - p * 2, y: rect.height - p))
        path.addLine(to: CGPoint(x: rect.width - p * 2, y: rect.height))
        
        path.addLine(to: CGPoint(x: p * 2, y: rect.height))
        
        path.addLine(to: CGPoint(x: p * 2, y: rect.height - p))
        path.addLine(to: CGPoint(x: p, y: rect.height - p))
        path.addLine(to: CGPoint(x: p, y: rect.height - p * 2))
        path.addLine(to: CGPoint(x: 0, y: rect.height - p * 2))
        
        path.addLine(to: CGPoint(x: 0, y: p * 2))
        
        path.addLine(to: CGPoint(x: p, y: p * 2))
        path.addLine(to: CGPoint(x: p, y: p))
        path.addLine(to: CGPoint(x: p * 2, y: p))
        path.addLine(to: CGPoint(x: p * 2, y: 0))
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

struct QuestionaryScreen_Previews: PreviewProvider {
    static var previews: some View {
        QuestionaryScreen()
            .preferredColorScheme(.dark)
    }
}
