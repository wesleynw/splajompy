import SwiftUI

struct UsernameEntryView: View {
  @Binding var viewModel: RegistrationViewModel
  @Environment(\.dismiss) private var dismiss

  @FocusState var isFocused

  var errorStyle: any ShapeStyle {
    switch viewModel.usernameValidation {
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
        .onChange(of: viewModel.username) {
          Task {
            await viewModel.setUsername()
          }
        }

      HStack {
        if viewModel.usernameValidation == .pending {
          ProgressView()
            .controlSize(.small)
          Text("Checking if username is available...")
            .font(SJFont.body)
        } else if viewModel.usernameValidation == .valid {
          Image(systemName: "checkmark.circle.fill")
          Text("This username is available")
        } else if case .invalid(let error) = viewModel.usernameValidation {
          Image(systemName: "exclamationmark.triangle")
          Text(error)
            .font(SJFont.body)
        }
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        AnyShapeStyle(errorStyle),
        in: RoundedRectangle(cornerRadius: 35)
      )
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
            isLoading: false,
            isDisabled: viewModel.usernameValidation != .valid
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
