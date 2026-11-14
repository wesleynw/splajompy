import SwiftUI

struct UsernameEntryView: View {
  @Binding var viewModel: RegistrationViewModel
  @Environment(\.dismiss) private var dismiss

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

      if case .invalid(let error) = viewModel.usernameValidation {
        Text(error)
          .padding()
          .font(SJFont.body)
          .foregroundStyle(.red.secondary)
          .transition(.opacity)
      }
    }
    .animation(.default, value: viewModel.usernameValidation)
    .padding()
    .onAppear {
      isFocused = true
    }
    #if os(macOS)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          AsyncActionButton(
            title: "Continue",
            isLoading: viewModel.usernameAvailableCheckTask != nil,
            isDisabled: viewModel.username.count == 0
          ) {
            await viewModel.setUsername()
          }
        }
      }
    #elseif os(iOS)
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
        .disabled(viewModel.usernameValidation != .valid)
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
    #endif
  }
}

#Preview {
  @Previewable @State var viewModel: RegistrationViewModel =
    RegistrationViewModel()
  viewModel.email = "wesleynw@pm.me"

  return UsernameEntryView(viewModel: $viewModel)
}
