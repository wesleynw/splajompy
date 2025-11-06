import SwiftUI

struct ProfileDisplayNameFontPicker: View {
  var displayName: String
  @Binding var displayNameFont: ProfileFontChoiceEnum
  @State private var showingFontPicker = false

  var body: some View {
    Button {
      showingFontPicker = true
    } label: {
      HStack {
        Text("Font")
        Image(systemName: "chevron.up.chevron.down")
          .font(.caption)
        Spacer()
        if let fontName = displayNameFont.fontName {
          Text(displayName)
            .font(
              Font.custom(fontName, size: displayNameFont.baselineSize * 0.6)
            )
        } else {
          Text(displayName)
            .font(.callout)
            .fontWeight(.bold)
        }
      }
      .padding()
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
        .navigationBarTitleDisplayMode(.inline)
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
