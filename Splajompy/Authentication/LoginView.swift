import SwiftUI

struct LoginView: View {
    @State private var identifier = ""
    @State private var password = ""
    @State private var isUsingPassword = true
    @State private var showRegistration = false
    
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.colorScheme) var colorScheme

    
    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Image(colorScheme == .dark ? "S_transparent_white" : "S_transparent_black")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .shadow(color: .white.opacity(0.4), radius: 15, x: 0, y: 0)
                    .padding(.bottom, 28)
                
                Text("Sign in")
                    .font(.system(size: 24, weight: .black))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 20)
                
                VStack(alignment: .leading, spacing: 5) {
                    TextField("Email or Username", text: $identifier)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                .padding(.bottom, 10)
                
                if isUsingPassword {
                    VStack(alignment: .leading, spacing: 5) {
                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .textContentType(.password)
                    }
                    .padding(.bottom, 10)
                }
                
                // TODO
//                HStack {
//                    Spacer()
//                    Button(action: {
//                        isUsingPassword.toggle()
//                    }) {
//                        Text("Sign in with \(isUsingPassword ? "username or email" : "password")")
//                            .font(.system(size: 14, weight: .bold))
//                    }
//                }
//                .padding(.bottom, 16)
                
                Button(action: signIn) {
                    HStack {
                        Text("Continue")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .padding(.bottom, 16)
                
                // TODO
//                HStack(spacing: 10) {
//                    Text("New here?")
//                        .fontWeight(.bold)
//                    
//                    Button(action: {
//                        showRegistration = true
//                    }) {
//                        Text("Register")
//                            .fontWeight(.bold)
//                            .underline()
//                    }.fullScreenCover(isPresented: $showRegistration) {
//                        RegistrationView()
//                            .environmentObject(authManager)
//                    }
//                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }
    
    func signIn() {
        Task {
            if isUsingPassword {
                let authError = await authManager.signInWithPassword(identifier: identifier, password: password)
                if authError == .None {
                    print("Authentication successful!")
                } else {
                    switch authError {
                    case .IncorrectPassword:
                        print("Wrong password")
                    case .AccountNonexistent:
                        print("Account doesn't exist")
                    default:
                        print("Authentication error: \(authError)")
                    }
                }
            } else {
                // TODO
                print("Requesting email authentication for: \(identifier)")
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
