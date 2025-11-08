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
                if let fontName = choice.fontName {
                  Text(displayName)
                    .font(Font.custom(fontName, size: choice.baselineSize))
                } else {
                  Text(displayName)
                    .font(.title2)
                    .fontWeight(.bold)
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
            Button("Done") {
              showingFontPicker = false
            }
          }
        }
      }
      .presentationDetents([.medium, .large])
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
