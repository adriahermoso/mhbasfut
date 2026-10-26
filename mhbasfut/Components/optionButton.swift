import SwiftUI

/// A reusable 3D-styled button with Horizontal (Image + Text) and Vertical (Icon + Text) modes.
public struct OptionButton: View {
    
    public enum Mode {
        /// Displays an asset image on top of the text (Squarish button that fills space proportionally)
        case horizontal(imageAsset: String)
        /// Displays an optional SF Symbol next to the text (Wide button)
        case vertical(systemIcon: String?)
    }
    
    public let mode: Mode
    public let text: String
    public let isSelected: Bool
    public let action: () -> Void
    
    public init(mode: Mode, text: String, isSelected: Bool = false, action: @escaping () -> Void) {
        self.mode = mode
        self.text = text
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            switch mode {
            case .horizontal(let imageAsset):
                // HORIZONTAL MODE (Image on top, Text below, Flexible Aspect Ratio)
                VStack(spacing: 8) {
                    Image(imageAsset)
                        .resizable()
                        .scaledToFit()
                        // Allows the image to scale infinitely while keeping its aspect ratio
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 20) // Breathing room on the sides
                    
                    Text(text)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7) // Shrinks text slightly on tiny screens
                        .padding(.bottom, 12)
                }
                .padding(.top, 16)
                .frame(maxWidth: .infinity)
                // 0.85 gives it that slightly-taller-than-wide squarish look from your design
                .aspectRatio(0.85, contentMode: .fit)
                
            case .vertical(let systemIcon):
                // VERTICAL MODE (Icon left, Text right, Full Width)
                HStack(spacing: 16) {
                    if let systemIcon = systemIcon {
                        Image(systemName: systemIcon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text(text)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(OptionButtonStyle(isSelected: isSelected))
    }
}

// MARK: - Custom Button Style (3D Effect)
fileprivate struct OptionButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        // Colors extracted from your design
        let backgroundColor = Color(red: 0.11, green: 0.14, blue: 0.18) // Dark background
        let unselectedBorderColor = Color(red: 0.18, green: 0.22, blue: 0.28) // Muted gray/blue
        let selectedBorderColor = Color(red: 1.00, green: 0.77, blue: 0.05) // Golden yellow
        
        let activeColor = isSelected ? selectedBorderColor : unselectedBorderColor
        let isPressed = configuration.isPressed
        let depthOffset: CGFloat = 6 // How thick the 3D bottom edge is
        
        return configuration.label
            .background(
                ZStack {
                    // 1. Bottom 3D shadow layer
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(activeColor)
                        .offset(y: depthOffset)
                    
                    // 2. Main button background layer
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(backgroundColor)
                    
                    // 3. Top border
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(activeColor, lineWidth: 2)
                }
                // Moves the background down when pressed to simulate clicking
                .offset(y: isPressed ? depthOffset : 0)
            )
            // Moves the text/image content down when pressed
            .offset(y: isPressed ? depthOffset : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            // Extra padding at the bottom so the 3D offset doesn't get clipped by containers
            .padding(.bottom, depthOffset)
    }
}

// MARK: - Preview (Demonstration on how to use)
struct OptionButton_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var selectedHorizontal: String = "Futbol"
        @State private var selectedVertical: String = "Option 5"
        
        var body: some View {
            ZStack {
                Color(red: 0.08, green: 0.10, blue: 0.12).ignoresSafeArea() // App background
                
                ScrollView {
                    VStack(spacing: 40) {
                        
                        // 1. HORIZONTAL USAGE
                        // The HStack distributes available space equally to both buttons
                        HStack(spacing: 16) {
                            OptionButton(
                                mode: .horizontal(imageAsset: "soccer_ball_asset"), // Put your actual asset name here
                                text: "Futbol",
                                isSelected: selectedHorizontal == "Futbol"
                            ) {
                                selectedHorizontal = "Futbol"
                            }
                            
                            OptionButton(
                                mode: .horizontal(imageAsset: "basketball_asset"), // Put your actual asset name here
                                text: "Basquet",
                                isSelected: selectedHorizontal == "Basquet"
                            ) {
                                selectedHorizontal = "Basquet"
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // 2. VERTICAL USAGE
                        VStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { index in
                                let optionText = "Option \(index) placeholder text"
                                
                                OptionButton(
                                    mode: .vertical(systemIcon: "square.dashed"),
                                    text: optionText,
                                    isSelected: selectedVertical == optionText
                                ) {
                                    selectedVertical = optionText
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical)
                }
            }
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}
