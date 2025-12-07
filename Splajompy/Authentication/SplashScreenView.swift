import SwiftUI

struct SplashScreenView: View {
  @EnvironmentObject var authManager: AuthManager
  @State private var isLoginViewPresenting: Bool = false
  @State private var isRegisterViewPresenting: Bool = false

  var body: some View {
    VStack {
      Image("Logo")
        .resizable()
        .scaledToFit()
        .frame(height: 130)
        .shadow(color: .white, radius: 3)

      Text("Splajompy")
        .fontWeight(.black)
        .font(.title)
        .fontDesign(.rounded)
        .shadow(color: .white, radius: 1)
    }
    .frame(maxHeight: .infinity)
    .frame(maxWidth: .infinity)
    .overlay(alignment: .bottom) {
      HStack(spacing: 16) {
        Button {
          isLoginViewPresenting = true
        } label: {
          Text("Log In")
            .fontWeight(.black)
            .fontDesign(.rounded)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
              RoundedRectangle(cornerRadius: 30)
                .fill(.clear)
                .stroke(.primary, lineWidth: 1)
                .shadow(color: .white, radius: 1)
            )
            .shadow(color: .accentColor, radius: 1)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .sensoryFeedback(.impact, trigger: isLoginViewPresenting)

        Button {
          isRegisterViewPresenting = true
        } label: {
          Text("Sign Up")
            .fontWeight(.black)
            .fontDesign(.rounded)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background {
              RoundedRectangle(cornerRadius: 30)
                .shadow(radius: 2)
            }
            .shadow(color: .white, radius: 1)
        }
        .sensoryFeedback(.impact, trigger: isRegisterViewPresenting)
      }
      .padding()
    }
    .preferredColorScheme(.dark)
    #if os(iOS)
      .fullScreenCover(isPresented: $isLoginViewPresenting) {
        LoginView()
      }
      .fullScreenCover(isPresented: $isRegisterViewPresenting) {
        RegisterView(isPresenting: $isRegisterViewPresenting)
      }
    #else
      .sheet(isPresented: $isLoginViewPresenting) {
        CredentialedLoginView(isPresenting: $isLoginViewPresenting)
      }
      .sheet(isPresented: $isRegisterViewPresenting) {
        RegisterView(isPresenting: $isRegisterViewPresenting)
      }
    #endif
    .environmentObject(authManager)
  }
}

#Preview {
  SplashScreenView()
    .environmentObject(AuthManager())
}
