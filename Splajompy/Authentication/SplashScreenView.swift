import SwiftUI

struct SplashScreenView: View {
  @EnvironmentObject var authManager: AuthManager
  @State private var isLoginViewPresenting: Bool = false
  @State private var isRegisterViewPresenting: Bool = false

  var body: some View {
    ZStack {
      ZStack {
        LinearGradient(
          gradient: Gradient(colors: [
            Color(red: 0.08, green: 0.08, blue: 0.15),
            Color(red: 0.02, green: 0.02, blue: 0.08),
          ]),
          startPoint: .top,
          endPoint: .bottom
        )

        #if os(iOS)
          RadialGradient(
            gradient: Gradient(colors: [
              Color(red: 0.15, green: 0.2, blue: 0.4).opacity(0.3),
              Color.clear,
            ]),
            center: .init(x: 0.3, y: 0.2),
            startRadius: 0,
            endRadius: UIScreen.main.bounds.width * 0.6
          )
        #endif
      }
      .ignoresSafeArea()

      VStack {
        Spacer()
          .frame(height: 60)

        Image("Full_Logo")
          .resizable()
          .scaledToFit()
          .colorScheme(.dark)
          .frame(height: 40)
          .shadow(
            color: Color.black.opacity(0.3),
            radius: 10,
            x: 0,
            y: 4
          )
          .padding(.bottom, 24)

        Spacer()

        HStack(spacing: 16) {
          Button {
            isLoginViewPresenting = true
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
                    .stroke(
                      LinearGradient(
                        colors: [
                          Color.white.opacity(0.6), Color.white.opacity(0.3),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      ),
                      lineWidth: 2
                    )
                }
              )
          }
          .contentShape(Rectangle())
          .sensoryFeedback(.impact, trigger: isLoginViewPresenting)

          Button {
            isRegisterViewPresenting = true
          } label: {
            Text("Sign Up")
              .fontWeight(.bold)
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 50)
              .background(
                LinearGradient(
                  colors: [
                    Color(red: 0.4, green: 0.2, blue: 0.9),
                    Color(red: 0.2, green: 0.1, blue: 0.6),
                  ],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 30))
              )
              .shadow(
                color: Color(red: 0.3, green: 0.1, blue: 0.7).opacity(0.4),
                radius: 8,
                x: 0,
                y: 4
              )
          }
          .sensoryFeedback(.impact, trigger: isRegisterViewPresenting)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
      }
    }
    #if os(iOS)
      .fullScreenCover(isPresented: $isLoginViewPresenting) {
        LoginView(isPresenting: $isLoginViewPresenting)
      }
      .fullScreenCover(isPresented: $isRegisterViewPresenting) {
        RegisterView(isPresenting: $isRegisterViewPresenting)
      }
    #else
      .sheet(isPresented: $isLoginViewPresenting) {
        LoginView(isPresenting: $isLoginViewPresenting)
      }
      .sheet(isPresented: $isRegisterViewPresenting) {
        RegisterView(isPresenting: $isRegisterViewPresenting)
      }
    #endif
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
