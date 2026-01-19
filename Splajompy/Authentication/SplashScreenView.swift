import SwiftUI

struct SplashScreenView: View {
  @Environment(AuthManager.self) private var authManager
  @State private var isLoginViewPresenting: Bool = false
  @State private var isRegisterViewPresenting: Bool = false

  var body: some View {
    VStack {
      Image("Logo")
        .resizable()
        .scaledToFit()
        .frame(height: 130)
        .shadow(color: .white, radius: 1)

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
            .frame(maxWidth: .infinity)
        }
        .modify {
          if #available(iOS 26, macOS 26, *) {
            $0.buttonStyle(.glass)
          } else {
            $0.buttonStyle(.bordered)
          }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.extraLarge)
        .sensoryFeedback(.impact, trigger: isLoginViewPresenting)

        Button {
          isRegisterViewPresenting = true
        } label: {
          Text("Sign Up")
            .fontWeight(.black)
            .fontDesign(.rounded)
            .frame(maxWidth: .infinity)
        }
        .modify {
          if #available(iOS 26, macOS 26, *) {
            $0.buttonStyle(.glassProminent)
          } else {
            $0.buttonStyle(.borderedProminent)
          }
        }
        .controlSize(.extraLarge)
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
        RegisterView()
      }
    #else
      .sheet(isPresented: $isLoginViewPresenting) {
        LoginView()
      }
      .sheet(isPresented: $isRegisterViewPresenting) {
        RegisterView()
      }
    #endif
  }
}

#Preview {
  SplashScreenView()
}
