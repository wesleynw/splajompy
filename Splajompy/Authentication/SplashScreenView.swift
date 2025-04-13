import SwiftUI

struct SplashScreenView: View {
  @EnvironmentObject var authManager: AuthManager
  @State private var isLoginViewPresenting: Bool = false
  @State private var isRegisterViewPresenting: Bool = false
  let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

  var body: some View {
    ZStack {
      ZStack {
        LinearGradient(
          gradient: Gradient(colors: [
            Color(red: 0.05, green: 0.05, blue: 0.2),
            Color(red: 0.0, green: 0.0, blue: 0.0),
          ]),
          startPoint: .top,
          endPoint: .bottom
        )

        RadialGradient(
          gradient: Gradient(colors: [
            Color(red: 0.1, green: 0.2, blue: 0.6).opacity(0.7),
            Color.clear,
          ]),
          center: .init(x: 0.3, y: 0.3),
          startRadius: 0,
          endRadius: UIScreen.main.bounds.width * 0.8
        )

        RadialGradient(
          gradient: Gradient(colors: [
            Color(red: 0.4, green: 0.1, blue: 0.6).opacity(0.5),
            Color.clear,
          ]),
          center: .init(x: 0.7, y: 0.8),
          startRadius: 50,
          endRadius: UIScreen.main.bounds.width * 0.8
        )

        RadialGradient(
          gradient: Gradient(colors: [
            Color(red: 0.2, green: 0.3, blue: 0.8).opacity(0.3),
            Color.clear,
          ]),
          center: .top,
          startRadius: 0,
          endRadius: UIScreen.main.bounds.height * 0.6
        )
      }
      .ignoresSafeArea()

      VStack {
        Spacer()
          .frame(height: 60)

        Text("Welcome to")
          .font(.system(size: 28, weight: .medium, design: .rounded))
          .padding(.top, 10)

        Text("Splajompy")
          .font(.system(size: 38, weight: .black))
          .tracking(2)
          .foregroundStyle(
            LinearGradient(
              colors: [
                Color(red: 0.6, green: 0.3, blue: 1.0),
                Color(red: 0.2, green: 0.5, blue: 0.9),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .shadow(
            color: Color(red: 0.3, green: 0.1, blue: 0.6).opacity(0.6),
            radius: 8,
            x: 0,
            y: 2
          )
          .padding(.bottom, 16)

        Spacer()
        
        HStack(spacing: 16) {
          Button {
            isLoginViewPresenting = true
            feedbackGenerator.impactOccurred()
          } label: {
            Text("Log In")
              .fontWeight(.bold)
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 50)
              .background(
                ZStack {
                  RoundedRectangle(cornerRadius: 30)
                    .fill(Color.clear)
                  RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.secondary.opacity(0.8), lineWidth: 2)
                }
              )
          }
          .contentShape(Rectangle())

          Button {
            isRegisterViewPresenting = true
            feedbackGenerator.impactOccurred()
          } label: {
            Text("Sign Up")
              .fontWeight(.bold)
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 50)
              .background(
                RoundedRectangle(cornerRadius: 30)
                  .fill(Color(red: 0.3, green: 0.1, blue: 0.8))
              )
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
      }
    }
    .fullScreenCover(isPresented: $isLoginViewPresenting) {
      LoginView(isPresenting: $isLoginViewPresenting)
    }
    .fullScreenCover(isPresented: $isRegisterViewPresenting) {
      RegisterView()
    }
    .environmentObject(authManager)
    .preferredColorScheme(.dark)
  }
}

#Preview {
  SplashScreenView()
    .environmentObject(AuthManager())
}

#Preview("Dark Mode") {
  SplashScreenView()
    .environmentObject(AuthManager())
    .preferredColorScheme(.dark)
}
