import SwiftUI
import UIKit

struct MentionTextEditor: View {
  @Binding var text: NSAttributedString
  @StateObject private var viewModel: MentionViewModel
  @FocusState private var isFocused: Bool

  init(text: Binding<NSAttributedString>) {
    self._text = text
    self._viewModel = StateObject(wrappedValue: MentionViewModel())
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
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
          .focused($isFocused)
          .fixedSize(horizontal: false, vertical: true)
          if text.string.isEmpty {
            Text("What's on your mind?")
              .foregroundColor(Color(.placeholderText))
              .padding(8)
              .allowsHitTesting(false)
          }
        }
        if viewModel.isShowingSuggestions {
          suggestionView
        }
        Spacer()
      }
    }
    .onAppear {
      isFocused = true
    }
    .onChange(of: text) { oldValue, newValue in
      viewModel.updateAttributedText(newValue)
    }
  }

  private var suggestionView: some View {
    VStack(spacing: 0) {
      if viewModel.mentionSuggestions.isEmpty {
        Text("No users found")
          .foregroundColor(.gray)
          .frame(height: 44)
          .frame(maxWidth: .infinity, alignment: .center)
      } else {
        ForEach(viewModel.mentionSuggestions.prefix(5), id: \.userId) { user in
          suggestionRow(for: user)
          if user.userId != viewModel.mentionSuggestions.prefix(5).last?.userId {
            Divider().opacity(0.4)
          }
        }
      }
    }
    .frame(height: calculateHeight())
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
    )
    .cornerRadius(8)
    .opacity(viewModel.isShowingSuggestions ? 1 : 0)
  }

  private func calculateHeight() -> CGFloat {
    let rowHeight: CGFloat = 44
    let count =
      viewModel.mentionSuggestions.isEmpty ? 1 : min(viewModel.mentionSuggestions.count, 5)
    return CGFloat(count) * rowHeight
  }

  private func suggestionRow(for user: User) -> some View {
    HStack {
      Text("@\(user.username)")
        .fontWeight(.medium)
    }
    .padding(.horizontal, 12)
    .frame(height: 44)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
    .onTapGesture {
      viewModel.insertMention(user)
      text = viewModel.attributedText
    }
  }
}
