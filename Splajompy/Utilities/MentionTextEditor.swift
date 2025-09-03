import SwiftUI
import UIKit

struct MentionTextEditor: View {
  @Binding var text: NSAttributedString
  @StateObject private var viewModel: MentionViewModel
  @FocusState private var isFocused: Bool
  @State private var textViewHeight: CGFloat = 0
  @State private var editorFrame: CGRect = .zero
  let showSuggestionsOnTop: Bool

  init(text: Binding<NSAttributedString>, showSuggestionsOnTop: Bool = false) {
    self._text = text
    self._viewModel = StateObject(wrappedValue: MentionViewModel())
    self.showSuggestionsOnTop = showSuggestionsOnTop
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if showSuggestionsOnTop {
        Spacer()
          .frame(
            height: viewModel.isShowingSuggestions ? calculateHeight() + 8 : 0
          )
          .animation(
            .easeInOut(duration: 0.2),
            value: viewModel.isShowingSuggestions
          )
      }

      ZStack(alignment: .topLeading) {
        AttributedTextEditor(
          text: $text,
          height: $textViewHeight,
          cursorPosition: $viewModel.cursorPosition,
          onTextChange: { newText in
            viewModel.processTextChange(newText)
          },
          onCursorPositionChange: { position in
            viewModel.updateCursorPosition(position)
          }
        )
        .frame(height: textViewHeight)
        .frame(maxWidth: .infinity)
        .focused($isFocused)
        .background(
          GeometryReader { geometry in
            Color.clear
              .onAppear {
                editorFrame = geometry.frame(in: .global)
              }
              .onChange(of: geometry.frame(in: .global)) { _, newFrame in
                editorFrame = newFrame
              }
          }
        )

        if text.string.isEmpty {
          Text("What's on your mind?")
            .foregroundColor(Color(.placeholderText))
            .padding(8)
        }
      }
      .padding()

      if !showSuggestionsOnTop && viewModel.isShowingSuggestions {
        suggestionView
      }
    }
    .padding(.horizontal)
    .frame(maxWidth: .infinity)
    .overlay(
      Group {
        if showSuggestionsOnTop && viewModel.isShowingSuggestions {
          suggestionView
            .offset(x: 16, y: editorFrame.minY - calculateHeight() - 8)
            .animation(
              .easeInOut(duration: 0.2),
              value: viewModel.isShowingSuggestions
            )
        }
      }
    )
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
    .frame(maxWidth: .infinity)
    .background(Color(.systemBackground))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
    )
    .cornerRadius(8)
    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
  }

  private func calculateHeight() -> CGFloat {
    let rowHeight: CGFloat = 44
    let count =
      viewModel.mentionSuggestions.isEmpty
      ? 1 : min(viewModel.mentionSuggestions.count, 5)
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
