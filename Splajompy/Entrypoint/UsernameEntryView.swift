import SwiftUI

struct UsernameEntryView: View {
  @Binding var viewModel: RegistrationViewModel

  @FocusState var isFocused

  var body: some View {
    ScrollView {
      Text("Pick a username")
        .font(SJFont.title)
        .padding()

      TextField("Username", text: $viewModel.username)
        .textContentType(.nickname)
        .padding()
        .background {
          RoundedRectangle(cornerRadius: 10)
            .stroke()
        }
        #if os(iOS)
          .textInputAutocapitalization(.none)
          .autocapitalization(.none)
          .autocorrectionDisabled()
        #else
          .textFieldStyle(.plain)
        #endif
        .focused($isFocused)
        .onChange(of: viewModel.username) {
          Task {
            await viewModel.scheduleUsernameAvailabilityCheck()
          }
        }

      HStack {
        if case .pending = viewModel.usernameValidation {
          ProgressView()
        } else if case .invalid(let error) = viewModel.usernameValidation {
          Text(error)
            .padding()
            .font(SJFont.body)
            .foregroundStyle(.red.secondary)
            .transition(.opacity)
        }
      }
      .animation(.default, value: viewModel.usernameValidation)
    }
    .padding()
    .onAppear {
      isFocused = true
    }
    .safeAreaInset(edge: .bottom) {
      Button {
        Task {
          await viewModel.setUsername()
        }
      } label: {
        Text("Continue")
          .font(SJFont.body)
          .frame(maxWidth: .infinity)
      }
      .disabled(viewModel.email.count == 0)
      .controlSize(.extraLarge)
      .modify {
        if #available(anyAppleOS 26, *) {
          $0.buttonStyle(.glassProminent)
        } else {
          $0.buttonStyle(.borderedProminent)
        }
      }
      .padding()
    }
  }
}

#Preview {
  @Previewable @State var viewModel: RegistrationViewModel =
    RegistrationViewModel()
  viewModel.email = "wesleynw@pm.me"

  return UsernameEntryView(viewModel: $viewModel)
}
