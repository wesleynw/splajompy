import SwiftUI

struct ProfileDisplayNameFontPicker: View {
  var displayName: String
  @Binding var displayNameFont: ProfileFontChoiceEnum
  @State private var showingFontPicker = false

  var body: some View {
    Button {
      showingFontPicker = true
    } label: {
      Label("Display Name Style", systemImage: "textformat")
    }
    .buttonStyle(.bordered)
    .sheet(isPresented: $showingFontPicker) {
      NavigationStack {
        List {
          ForEach(ProfileFontChoiceEnum.allCases) { choice in
            Button {
              displayNameFont = choice
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
                if displayNameFont == choice {
                  Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
                }
              }
            }
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
                showingFontPicker = false
              }
            } else {
              Button("Done") {
                showingFontPicker = false
              }
            }
          }

          ToolbarItem(placement: .cancellationAction) {
            if #available(iOS 26, macOS 26, *) {
              Button(role: .cancel) {
                showingFontPicker = false
              }
            } else {
              Button("Cancel") {
                showingFontPicker = false
              }
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
    displayNameFont: $displayNameFont
  )
}
