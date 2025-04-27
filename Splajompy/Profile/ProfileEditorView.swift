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
          viewModel.updateProfile(name: name, bio: bio)
          dismiss()
        } label: {

          Text("Save")
            .bold()
        }
        .disabled(name.count > 25 || bio.count > 400)
      }
      .padding()

      Divider()

      VStack(alignment: .leading) {
        HStack {
          Text("Display Name")
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(.primary.opacity(0.7))

          Spacer()

          Text("\(name.count)/25")
            .font(.subheadline)
            .foregroundStyle(name.count > 25 ? Color.red.opacity(0.7) : Color.primary.opacity(0.7))
        }

        Divider()

        TextEditor(text: $name)
          .focused($isFocused)
          .onAppear {
            isFocused = true
          }
          .frame(maxHeight: 100)

        HStack {
          Text("Bio")
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(.primary.opacity(0.7))

          Spacer()

          Text("\(bio.count)/400")
            .font(.subheadline)
            .foregroundStyle(bio.count > 400 ? Color.red.opacity(0.7) : Color.primary.opacity(0.7))
        }

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
  @Previewable @StateObject var viewModel = ProfileView.ViewModel(
    userId: 1, profileService: MockProfileService())

  ProfileEditorView(viewModel: viewModel)
}
