import PostHog
import SwiftUI

/// Allows users to edit their display name, bio, and display name font.
struct ProfileEditorView: View {
  var viewModel: ProfileView.ViewModel
  @State private var name: String = ""
  @State private var bio: String = ""
  @State private var isShowingFontPicker: Bool = false
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
    NavigationStack {
      ScrollView {
        TextField("Name", text: $name)
          .textFieldStyle(.plain)
          .lineLimit(1)
          .padding()
          .background {
            RoundedRectangle(cornerRadius: 10)
              .stroke(.primary.quaternary)
          }

        Text("\(name.count)/25")
          .font(.subheadline)
          .foregroundStyle(
            name.count > 25
              ? Color.red.opacity(0.7) : Color.primary.opacity(0.7)
          )
          .frame(maxWidth: .infinity, alignment: .trailing)

        Button {
          isShowingFontPicker = true
        } label: {
          HStack {
            Image(systemName: "textformat")
            Text("Font Style")
          }
        }
        .controlSize(.large)
        .padding(.vertical, 5)
        .modify {
          if #available(iOS 26, macOS 26, *) {
            $0.buttonStyle(.glass)
          } else {
            $0.buttonStyle(.bordered)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .disabled(name.isEmpty)

        TextField("Bio", text: $bio, axis: .vertical)
          .textFieldStyle(.plain)
          .lineLimit(5...10)
          .padding()
          .background {
            RoundedRectangle(cornerRadius: 10)
              .stroke(.primary.quaternary)
          }

        Text("\(bio.count)/400")
          .font(.subheadline)
          .foregroundStyle(
            bio.count > 400
              ? Color.red.opacity(0.7) : Color.primary.opacity(0.7)
          )
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .padding()
      .onAppear {
        name = currentProfile?.name ?? ""
        bio = currentProfile?.bio ?? ""
        if let fontChoiceId = currentProfile?.displayProperties.fontChoiceId,
          let fontChoice = ProfileFontChoiceEnum(rawValue: fontChoiceId)
        {
          displayNameFont = fontChoice
        }
      }
      .navigationTitle("Edit Profile")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .sheet(isPresented: $isShowingFontPicker) {
        ProfileDisplayNameFontPicker(
          displayName: name,
          displayNameFont: displayNameFont,
          onChange: { newFont in displayNameFont = newFont }
        )
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          if #available(iOS 26.0, macOS 26, *) {
            Button(role: .cancel, action: { dismiss() })
          } else {
            Button("Cancel") {
              dismiss()
            }
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          if #available(iOS 26, macOS 26, *) {
            Button(role: .confirm) {
              viewModel.updateProfile(
                name: name,
                bio: bio,
                displayProperties: UserDisplayProperties(
                  fontChoiceId: displayNameFont.rawValue
                )
              )
              dismiss()
            }
            .disabled(name.count > 25 || bio.count > 400)
            #if os(macOS)
              .keyboardShortcut(.return, modifiers: .command)
            #endif
          } else {
            Button("Done") {
              viewModel.updateProfile(
                name: name,
                bio: bio,
                displayProperties: UserDisplayProperties(
                  fontChoiceId: displayNameFont.rawValue
                )
              )
              dismiss()
            }
            .disabled(name.count > 25 || bio.count > 400)
            #if os(macOS)
              .keyboardShortcut(.return, modifiers: .command)
            #endif
          }
        }
      }
    }
  }
}

#Preview {
  @Previewable @State var isPresenting: Bool = true
  let viewModel = ProfileView.ViewModel(userId: 0, postManager: PostStore())

  Color.clear
    .sheet(isPresented: $isPresenting) {
      ProfileEditorView(viewModel: viewModel)
    }
}
