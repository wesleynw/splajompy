import SwiftUI
import UIKit

struct MentionTextEditor: View {
  @Binding var text: NSAttributedString
  @StateObject private var viewModel: MentionViewModel

  init(text: Binding<NSAttributedString>) {
    self._text = text
    self._viewModel = StateObject(wrappedValue: MentionViewModel())
  }

  var body: some View {
    VStack {
      ZStack(alignment: .topLeading) {
        AttributedTextEditor(
          text: $text,
          cursorPosition: $viewModel.cursorPosition,
          onTextChange: { newText in
            viewModel.processTextChange(newText)
          },
          onCursorPositionChange: { position in
            viewModel.updateCursorPosition(position)
          }
        )

        if viewModel.plainText.isEmpty {
          Text("What's on your mind?")
            .foregroundColor(Color(.placeholderText))
            .padding(8)
            .allowsHitTesting(false)
        }
      }
      //      .border(Color.gray.opacity(0.3))

      if viewModel.isShowingSuggestions {
        suggestionView
      }
    }
    .onChange(of: text) { oldValue, newValue in
      viewModel.updateAttributedText(newValue)
    }
  }

  private var suggestionView: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 8) {
        ForEach(viewModel.mentionSuggestions, id: \.userId) { user in
          suggestionRow(for: user)
        }
      }
      .padding(8)
    }
    .frame(height: min(CGFloat(viewModel.mentionSuggestions.count * 44), 180))
    .background(Color(.secondarySystemBackground))
    .cornerRadius(8)
  }

  private func suggestionRow(for user: User) -> some View {
    HStack {
      Text("@\(user.username)")
        .fontWeight(.medium)
      Text("• \(user.name ?? user.username)")
        .foregroundColor(.secondary)
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.systemBackground))
    .cornerRadius(4)
    .onTapGesture {
      viewModel.insertMention(user)
      text = viewModel.attributedText
    }
  }
}
