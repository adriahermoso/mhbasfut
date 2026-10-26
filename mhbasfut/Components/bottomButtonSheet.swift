import SwiftUI
import UIKit

/// Un componente reutilizable para la parte inferior de la pantalla que se adhiere
/// a los bordes sin padding y tiene un botón 3D con altura fija.
public struct BottomButton: View {
    
    public let subtitle: String
    public let title: String
    public let buttonText: String
    public let isActive: Bool
    public let action: () -> Void
    
    public init(
        subtitle: String,
        title: String,
        buttonText: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) {
        self.subtitle = subtitle
        self.title = title
        self.buttonText = buttonText
        self.isActive = isActive
        self.action = action
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) { // Espacio reducido entre texto y botón
            
            // Textos (Subtítulo y Título)
            VStack(alignment: .leading, spacing: 6) {
                Text(subtitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.66, green: 0.69, blue: 0.71))
                
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
            
            // Botón 3D
            Button(action: {
                if isActive {
                    action()
                }
            }) {
                Text(buttonText)
            }
            .buttonStyle(SubmitButtonStyle(isActive: isActive))
            .disabled(!isActive)
        }
        // Padding interno ajustado para no ocupar tanta pantalla
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 36) // Espacio inferior para el Home Indicator del iPhone
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(red: 0.125, green: 0.173, blue: 0.20)
                .clipShape(RoundedCorner(radius: 28, corners: [.topLeft, .topRight]))
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Custom Button Style (Fixed Height & Perfect Sync Animation)
fileprivate struct SubmitButtonStyle: ButtonStyle {
    let isActive: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        let activeFaceColor = Color(red: 0.996, green: 0.776, blue: 0.0)
        let activeShadowColor = Color(red: 0.831, green: 0.627, blue: 0.0)
        let activeTextColor = Color(red: 0.05, green: 0.15, blue: 0.22)
        
        let inactiveFaceColor = Color(red: 0.467, green: 0.388, blue: 0.102)
        let inactiveShadowColor = Color(red: 0.369, green: 0.298, blue: 0.075)
        let inactiveTextColor = Color(red: 0.161, green: 0.216, blue: 0.255)
        
        let faceColor = isActive ? activeFaceColor : inactiveFaceColor
        let shadowColor = isActive ? activeShadowColor : inactiveShadowColor
        let textColor = isActive ? activeTextColor : inactiveTextColor
        
        let isPressed = configuration.isPressed && isActive
        let depthOffset: CGFloat = 6 // Sombra 3D ligeramente más compacta
        
        return configuration.label
            .font(.system(size: 16, weight: .heavy))
            .foregroundColor(textColor)
            // ESTO DEFINE LA ALTURA DEL BOTÓN (Padding vertical fijo en lugar de extenderse)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            // 1. Capa Frontal (Se adhiere estrictamente al tamaño del texto)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(faceColor)
            )
            // 2. Al mover esto, Texto y Fondo Frontal se mueven 100% sincronizados
            .offset(y: isPressed ? depthOffset : 0)
            // 3. Capa Trasera (Se añade detrás y permanece estática gracias al orden de modificadores)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(shadowColor)
                    .offset(y: depthOffset) // Sombra estática hacia abajo
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .padding(.bottom, depthOffset) // Evita que se corte la sombra
    }
}

// MARK: - Extensión para redondear esquinas superiores
fileprivate extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

fileprivate struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}


// MARK: - Preview
struct BottomButton_Previews: PreviewProvider {
    
    struct PreviewWrapper: View {
        @State private var isFormValid: Bool = true
        
        var body: some View {
            ZStack {
                Color(red: 0.09, green: 0.12, blue: 0.14)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    Button("Cambiar estado: \(isFormValid ? "ACTIVO" : "INACTIVO")") {
                        isFormValid.toggle()
                    }
                    .foregroundColor(.white)
                    .padding(.top, 50)
                    
                    Spacer()
                    
                    BottomButton(
                        subtitle: "Pregunta 1/10",
                        title: "Pregunta 1 / 10: el título va aquí.",
                        buttonText: "CONTINUAR",
                        isActive: isFormValid
                    ) {
                        print("Botón pulsado!")
                    }
                }
                // IMPRESCINDIBLE PARA QUE TOQUE LOS BORDES
                .ignoresSafeArea(.container, edges: [.bottom, .horizontal])
            }
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}
