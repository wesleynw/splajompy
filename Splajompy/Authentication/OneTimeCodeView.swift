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
      Text("You should receive a verification email momentarily.")
        .font(.body)
        .foregroundColor(.secondary)
        .padding(.bottom, 20)

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
        .autocorrectionDisabled()
        .focused($isFocused)
        .textContentType(.oneTimeCode)
        #if os(iOS)
          .keyboardType(.numberPad)
        #endif
        .onAppear { isFocused = true }

      Spacer()

      Button(action: {
        Task {
          let success = await authManager.verifyOneTimeCode(
            for: identifier,
            code: oneTimeCode
          )
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
                oneTimeCode.isEmpty ? Color.primary.opacity(0.4) : Color.white
              )
              .padding()
            Spacer()
          }

          if authManager.isLoading {
            HStack {
              Spacer()
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .padding(.trailing, 16)
            }
          }
        }
        .background(
          oneTimeCode.isEmpty ? Color.secondary.opacity(0.3) : Color.accentColor
        )
        .cornerRadius(10)
      }
      .disabled(authManager.isLoading || oneTimeCode.isEmpty)
      .padding(.bottom, 8)
    }
    .padding()
    .navigationTitle("Check your email")
    .toolbar {
      ToolbarItem(
        placement: {
          #if os(iOS)
            .topBarTrailing
          #else
            .primaryAction
          #endif
        }()
      ) {
        #if os(iOS)
          if #available(iOS 26.0, *) {
            Button(role: .close, action: { isPresenting = false })
          } else {
            Button {
              isPresenting = false
            } label: {
              Image(systemName: "xmark.circle.fill")
                .opacity(0.8)
            }
            .buttonStyle(.plain)
          }
        #else
          CloseButton(onClose: { isPresenting = false })
        #endif
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
