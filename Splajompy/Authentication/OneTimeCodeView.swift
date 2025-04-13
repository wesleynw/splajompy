import SwiftUI

struct OneTimeCodeView: View {
  let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
  @Binding var isPresenting: Bool
  @Environment(\.dismiss) var dismiss
  @FocusState private var isFocused: Bool

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
      
      Spacer()
      
      Button(action: { print("sign in") }
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
          feedbackGenerator.impactOccurred()
          isPresenting = false
        }) {
          Image(systemName: "xmark")
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.primary.opacity(0.5))
            .padding(8)
            .background(Color(.systemGray6))
            .clipShape(Circle())
        }
      }
    }
  }
}

#Preview {
  @Previewable @State var isPresenting = true

  return NavigationStack {
    OneTimeCodeView(isPresenting: $isPresenting)
      .environmentObject(AuthManager())
  }
}

#Preview("Dark Mode") {
  @Previewable @State var isPresenting = true

  return NavigationStack {
    OneTimeCodeView(isPresenting: $isPresenting)
      .environmentObject(AuthManager())
  }
  .preferredColorScheme(.dark)
}
