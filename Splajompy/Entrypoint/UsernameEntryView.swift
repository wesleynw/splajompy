import SwiftUI

struct UsernameEntryView: View {
  @Binding var viewModel: RegistrationViewModel
  @Environment(\.dismiss) private var dismiss

  @FocusState var isFocused

  var errorStyle: any ShapeStyle {
    switch viewModel.usernameValidation {
    case .valid:
      return .green.tertiary
    case .invalid(_):
      return .red.tertiary
    case .pending:
      return .yellow.tertiary
    default:
      return .clear
    }
  }

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
        .onAppear {
          isFocused = true
        }
        .onChange(of: viewModel.username) {
          Task {
            await viewModel.setUsername()
          }
        }

      HStack {
        if viewModel.usernameValidation == .pending {
          ProgressView()
            .controlSize(.small)
          Text("Checking if username is available")
        } else if viewModel.usernameValidation == .valid {
          Image(systemName: "checkmark.circle.fill")
          Text("This username is available")
        } else if case .invalid(let error) = viewModel.usernameValidation {
          Image(systemName: "exclamationmark.triangle")
          Text(error)
        }
      }
      .font(SJFont.body)
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        AnyShapeStyle(errorStyle),
        in: RoundedRectangle(cornerRadius: 35)
      )
    }
    .pageTitle("Register")
    .animation(.default, value: viewModel.usernameValidation)
    .padding()
    .toolbar {
      #if os(macOS)
        ToolbarItem(placement: .confirmationAction) {
          continueButton
        }
      #endif
    }
    #if os(iOS)
      .safeAreaInset(edge: .bottom) {
        continueButton
        .padding()
      }
    #endif
  }

  @ContentBuilder
  private var continueButton: some View {
    AsyncActionButton(
      title: "Continue",
      isLoading: false,
      isDisabled: viewModel.usernameValidation != .valid
    ) {
      viewModel.acceptUsername()
    }
  }
}

#Preview {
  @Previewable @State var viewModel: RegistrationViewModel =
    RegistrationViewModel()
  viewModel.email = "wesleynw@pm.me"

  return UsernameEntryView(viewModel: $viewModel)
}
