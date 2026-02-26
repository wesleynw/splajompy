import SwiftUI

struct ProfileDisplayNameFontPicker: View {
  var displayName: String
  var displayNameFont: ProfileFontChoiceEnum
  var onChange: (ProfileFontChoiceEnum) -> Void

  @State private var selectedFont: ProfileFontChoiceEnum
  @Environment(\.dismiss) private var dismiss

  init(
    displayName: String,
    displayNameFont: ProfileFontChoiceEnum,
    onChange: @escaping (ProfileFontChoiceEnum) -> Void
  ) {
    self.displayName = displayName
    self.displayNameFont = displayNameFont
    self.onChange = onChange
    self._selectedFont = State(initialValue: displayNameFont)
  }

  var body: some View {
    NavigationStack {
      List {
        ForEach(ProfileFontChoiceEnum.allCases) { choice in
          Button {
            selectedFont = choice
          } label: {
            HStack {
              if choice.fontName != nil {
                Text(
                  choice.fontNormalized(for: displayName, isLargeTitle: false)
                )
              } else {
                HStack(alignment: .firstTextBaseline) {
                  Text(displayName)
                    .font(.title2)
                    .fontWeight(.black)

                  Text("Default")
                    .foregroundStyle(.secondary)
                }
              }
              Spacer()
              if selectedFont == choice {
                Image(systemName: "checkmark")
                  .foregroundStyle(.blue)
              }
            }
          }
          .buttonStyle(.plain)
          .foregroundStyle(.primary)
        }
      }
      .navigationTitle("Choose Font")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          if #available(iOS 26, macOS 26, *) {
            Button("Done", systemImage: "checkmark", role: .confirm) {
              onChange(selectedFont)
              dismiss()
            }
          } else {
            Button("Done") {
              onChange(selectedFont)
              dismiss()
            }
          }
        }

        ToolbarItem(placement: .cancellationAction) {
          if #available(iOS 26, macOS 26, *) {
            Button(role: .cancel) {
              dismiss()
            }
          } else {
            Button("Cancel") {
              dismiss()
            }
          }
        }
      }
    }
  }
}

#Preview {
  @Previewable @State var displayNameFont: ProfileFontChoiceEnum = .sixtyFour

  ProfileDisplayNameFontPicker(
    displayName: "Wesley",
    displayNameFont: displayNameFont,
    onChange: { newFont in print("new font: \(newFont)") }
  )
}
