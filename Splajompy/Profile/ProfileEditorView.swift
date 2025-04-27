import SwiftUI

struct ProfileEditorView: View {
  @StateObject var viewModel: ProfileView.ViewModel
  
  @State private var name: String = ""
  @State private var bio: String = ""

  @FocusState private var isFocused: Bool
  @Environment(\.dismiss) var dismiss

  var body: some View {
    VStack {

      HStack {
        Button("Cancel") {
          dismiss()
        }

        Spacer()

        Text("Profile")
          .font(.title3)
          .fontWeight(.bold)

        Spacer()

        Button {
//          name = nameCopy
//          bio = bioCopy
        } label: {

          Text("Save")
            .bold()
        }
      }
      .padding()

      Divider()

      VStack(alignment: .leading) {
        Text("Display Name")
          .font(.subheadline)
          .fontWeight(.bold)
          .foregroundStyle(.primary.opacity(0.7))

        Divider()

        TextEditor(text: $name)
          .focused($isFocused)
          .onAppear {
            isFocused = true
          }

        Text("Bio")
          .font(.subheadline)
          .fontWeight(.bold)
          .foregroundStyle(.primary.opacity(0.7))

        Divider()

        TextEditor(text: $bio)
      }
      .padding()
    }
    .onAppear {
      name = viewModel.profile?.name ?? ""
      bio = viewModel.profile?.bio ?? ""
    }
  }
}

#Preview {
  @Previewable @StateObject var viewModel = ProfileView.ViewModel(userId: 1, profileService: MockProfileService())

  ProfileEditorView(viewModel: viewModel)
}
