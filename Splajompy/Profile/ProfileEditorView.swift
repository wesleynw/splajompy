import SwiftUI

struct ProfileEditorView: View {
  @StateObject var viewModel: ProfileView.ViewModel
  @State private var name: String = ""
  @State private var bio: String = ""
  @State private var displayNameFont: ProfileFontChoiceEnum = .largeTitle2
  @Environment(\.dismiss) var dismiss

  private var currentProfile: DetailedUser? {
    switch viewModel.profileState {
    case .loaded(let profile):
      return profile
    default:
      return nil
    }
  }

  var body: some View {
    #if os(iOS)
      NavigationStack {
        VStack(alignment: .leading) {
          HStack {
            Text("Display Name")
              .font(.subheadline)
              .fontWeight(.bold)
              .foregroundStyle(.primary.opacity(0.7))
            Spacer()
            Text("\(name.count)/25")
              .font(.subheadline)
              .foregroundStyle(
                name.count > 25
                  ? Color.red.opacity(0.7) : Color.primary.opacity(0.7)
              )
          }
          Divider()
          Group {
            if let fontName = displayNameFont.fontName {
              TextEditor(text: $name)
                .font(Font.custom(fontName, size: displayNameFont.baselineSize))
            } else {
              TextEditor(text: $name)
                .font(.title2)
                .fontWeight(.bold)
            }
          }
          .frame(maxHeight: 100)

          ProfileDisplayNameFontPicker(
            displayName: name.isEmpty ? "Your Name" : name,
            displayNameFont: $displayNameFont
          )
          HStack {
            Text("Bio")
              .font(.subheadline)
              .fontWeight(.bold)
              .foregroundStyle(.primary.opacity(0.7))
            Spacer()
            Text("\(bio.count)/400")
              .font(.subheadline)
              .foregroundStyle(
                bio.count > 400
                  ? Color.red.opacity(0.7) : Color.primary.opacity(0.7)
              )
          }
          Divider()
          TextEditor(text: $bio)
        }
        .padding()
        .onAppear {
          name = currentProfile?.name ?? ""
          bio = currentProfile?.bio ?? ""
          if let fontChoiceId = currentProfile?.fontChoiceId,
             let fontChoice = ProfileFontChoiceEnum(rawValue: fontChoiceId) {
            displayNameFont = fontChoice
          }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            if #available(iOS 26.0, *) {
              Button(role: .close, action: { dismiss() })
            } else {
              Button {
                dismiss()
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .opacity(0.8)
              }
              .buttonStyle(.plain)
            }
          }

          ToolbarItem(placement: .topBarTrailing) {
            if #available(iOS 26, *) {
              Button {
                viewModel.updateProfile(name: name, bio: bio, fontChoiceId: displayNameFont.rawValue)
                dismiss()
              } label: {
                if viewModel.isLoading {
                  ProgressView()
                } else {
                  Label("Comment", systemImage: "checkmark")
                }
              }
              .disabled(name.count > 25 || bio.count > 400)
              .buttonStyle(.glassProminent)
            } else {
              Button {
                viewModel.updateProfile(name: name, bio: bio, fontChoiceId: displayNameFont.rawValue)
                dismiss()
              } label: {
                Image(systemName: "checkmark.circle")
                  .opacity(0.8)
              }
              .disabled(name.count > 25 || bio.count > 400)
            }
          }
        }
      }
    #endif
  }
}

#Preview {
  @Previewable @State var isPresenting: Bool = true
  let viewModel = ProfileView.ViewModel(userId: 0, postManager: PostManager())

  Color.clear
    .sheet(isPresented: $isPresenting) {
      ProfileEditorView(viewModel: viewModel)
    }
}
