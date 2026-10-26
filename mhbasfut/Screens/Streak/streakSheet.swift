//
//  streakSheet.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

//
//  streakSheet.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import SwiftUI

struct StreakSheetView: View {
    // Allows the view to dismiss itself when presented as a sheet
    @Environment(\.dismiss) var dismiss
    
    // Binds the view to our data logic
    @StateObject private var viewModel = StreakViewModel()
    
    let backgroundColor = Color(red: 28/255, green: 38/255, blue: 43/255)
    let inactivePixelColor = Color(red: 54/255, green: 71/255, blue: 81/255)
    let activePixelColor = Color(red: 255/255, green: 107/255, blue: 0/255)
    let textColor = Color(red: 230/255, green: 235/255, blue: 238/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Header with Close Button
            HStack {
                Spacer()
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(textColor)
                }
            }
            
            // Fire Icon
            Image("ic_fire")
                .resizable()
                .scaledToFit()
                .frame(width: 67, height: 67)
                .padding(.bottom, -12)
            
            // Streak Text
            VStack(alignment: .leading, spacing: -2) {
                Text("Llevas una")
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundColor(textColor)
                
                HStack(spacing: 8) {
                    Text("\(viewModel.currentStreakCount) días de")
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundColor(activePixelColor)
                    
                    Text("racha")
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundColor(textColor)
                }
            }
            
            // Subtitle
            Text("¡Sigue así! Completa tu plan cada día\ny no dejes que tu racha se reinicie.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.gray)
                .padding(.top, 4)
                .padding(.bottom, 16)
            
            // Calendar Controls
            HStack {
                Text(viewModel.currentMonthYearString())
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(textColor)
                
                Spacer()
                
                Button(action: { viewModel.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(viewModel.monthOffset > -3 ? textColor : .gray.opacity(0.3))
                }
                .disabled(viewModel.monthOffset <= -3)
                .padding(.trailing, 12)
                
                Button(action: { viewModel.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(viewModel.monthOffset < 0 ? textColor : .gray.opacity(0.3))
                }
                .disabled(viewModel.monthOffset >= 0)
            }
            
            // Calendar Grid
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
            
            // In streakSheet.swift, replace the weekday ForEach with this:
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.localizedWeekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.bottom, 8)
                }
                        
                let days = viewModel.getDaysForMonth()
                ForEach(0..<days.count, id: \.self) { index in
                    if let date = days[index] {
                        let dayNumber = Calendar.current.component(.day, from: date)
                        let isStreak = viewModel.isStreakDay(date: date)
                        
                        ZStack {
                            PixelBox()
                                .fill(isStreak ? activePixelColor : inactivePixelColor)
                                .aspectRatio(1, contentMode: .fit)
                            
                            Text("\(dayNumber)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(textColor)
                        }
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(backgroundColor.edgesIgnoringSafeArea(.all))
    }
}

// MARK: - Pixel Art Shape

struct PixelBox: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let p = min(w, h) / 8
        
        path.move(to: CGPoint(x: p*2, y: 0))
        path.addLine(to: CGPoint(x: w - p*2, y: 0))
        path.addLine(to: CGPoint(x: w - p*2, y: p))
        path.addLine(to: CGPoint(x: w - p, y: p))
        path.addLine(to: CGPoint(x: w - p, y: p*2))
        path.addLine(to: CGPoint(x: w, y: p*2))
        path.addLine(to: CGPoint(x: w, y: h - p*2))
        path.addLine(to: CGPoint(x: w - p, y: h - p*2))
        path.addLine(to: CGPoint(x: w - p, y: h - p))
        path.addLine(to: CGPoint(x: w - p*2, y: h - p))
        path.addLine(to: CGPoint(x: w - p*2, y: h))
        path.addLine(to: CGPoint(x: p*2, y: h))
        path.addLine(to: CGPoint(x: p*2, y: h - p))
        path.addLine(to: CGPoint(x: p, y: h - p))
        path.addLine(to: CGPoint(x: p, y: h - p*2))
        path.addLine(to: CGPoint(x: 0, y: h - p*2))
        path.addLine(to: CGPoint(x: 0, y: p*2))
        path.addLine(to: CGPoint(x: p, y: p*2))
        path.addLine(to: CGPoint(x: p, y: p))
        path.addLine(to: CGPoint(x: p*2, y: p))
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

struct StreakSheetView_Previews: PreviewProvider {
    static var previews: some View {
        StreakSheetView()
    }
}
