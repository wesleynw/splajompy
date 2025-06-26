import SwiftUI

struct OneTimeCodeView: View {
  var identifier: String
  @Binding var isPresenting: Bool
  @Environment(\.dismiss) var dismiss
  @FocusState private var isFocused: Bool
  @State private var showError: Bool = false

  @State private var oneTimeCode: String = ""
  @EnvironmentObject private var authManager: AuthManager

  var body: some View {
    VStack(alignment: .leading) {
      TextField("Code", text: $oneTimeCode)
        .padding(12)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .stroke(
              isFocused ? Color.primary : Color.gray.opacity(0.75),
              lineWidth: 2
            )
        )
        .cornerRadius(8)
        .textContentType(.username)
        .autocapitalization(.none)
        .autocorrectionDisabled()
        .focused($isFocused)
        .textContentType(.oneTimeCode)
        .keyboardType(.numberPad)
        .onAppear { isFocused = true }

      Spacer()

      Button(action: {
        Task {
          let success = await authManager.verifyOneTimeCode(for: identifier, code: oneTimeCode)
          if !success {
            showError = true
          }
        }
      }
      ) {
        ZStack {
          HStack {
            Spacer()
            Text("Continue")
              .font(.system(size: 16, weight: .bold))
              .foregroundColor(
                oneTimeCode.isEmpty ? Color.white.opacity(0.4) : Color.white
              )
              .padding()
            Spacer()
          }

          //          if authManager.isLoading {
          //            HStack {
          //              Spacer()
          //              ProgressView()
          //                .progressViewStyle(CircularProgressViewStyle(tint: .white))
          //                .padding(.trailing, 16)
          //            }
          //          }
        }
        .background(
          oneTimeCode.isEmpty ? Color.gray.opacity(0.3) : Color.accentColor
        )
        .cornerRadius(10)
      }
      .disabled(authManager.isLoading || oneTimeCode.isEmpty)
      .padding(.bottom, 8)
    }
    .padding()
    .navigationTitle("Check your email")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(action: {
          isPresenting = false
        }) {
          Image(systemName: "xmark")
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.primary.opacity(0.5))
            .padding(8)
            .background(Color(.systemGray6))
            .clipShape(Circle())
        }
        .sensoryFeedback(.impact, trigger: isPresenting)
      }
    }
    .alert(isPresented: $showError) {
      Alert(
        title: Text("Sign In Failed"),
        message: Text("Incorrect code."),
        dismissButton: .default(Text("OK"))
      )
    }
  }
}

#Preview {
  @Previewable @State var isPresenting = true

  NavigationStack {
    OneTimeCodeView(identifier: "wesleynw", isPresenting: $isPresenting)
      .environmentObject(AuthManager())
  }
}

#Preview("Dark Mode") {
  @Previewable @State var isPresenting = true

  NavigationStack {
    OneTimeCodeView(identifier: "wesleynw", isPresenting: $isPresenting)
      .environmentObject(AuthManager())
  }
  .preferredColorScheme(.dark)
}
