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
        .colorScheme(.dark)
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
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
              RoundedRectangle(cornerRadius: 30)
                .fill(.clear)
                .stroke(.white, lineWidth: 1)
                .shadow(color: .white, radius: 1)
            )
            .shadow(color: .white, radius: 1)
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
    #if os(iOS)
      .fullScreenCover(isPresented: $isLoginViewPresenting) {
        CredentialedLoginView(isPresenting: $isLoginViewPresenting)
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
    .preferredColorScheme(.dark)
  }
}

#Preview {
  SplashScreenView()
    .environmentObject(AuthManager())
}
