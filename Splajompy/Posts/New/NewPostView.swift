import PhotosUI
import SwiftUI

struct NewPostView: View {

  @State private var text = NSAttributedString(string: "")
  @State private var facets: [Facet] = []

  @StateObject private var viewModel: ViewModel
  @FocusState private var isFocused: Bool

  @Environment(\.dismiss) private var dismiss

  init(onPostCreated: @escaping () -> Void = {}) {
    _viewModel = StateObject(
      wrappedValue: ViewModel(onPostCreated: onPostCreated)
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button("Cancel") {
          dismiss()
        }

        Spacer()

        Button {
          viewModel.submitPost(text: String(text.string)) {
            dismiss()
          }
        } label: {
          if viewModel.isLoading {
            ProgressView()
          } else {
            Text("Jomp").bold()
          }
        }
        .disabled(
          isPostButtonDisabled || text.string.count > 1000
        )
      }
      .padding()

      Divider()

      VStack(spacing: 15) {
        MentionTextEditor(
          text: $text
        )

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(0..<viewModel.selectedImages.count, id: \.self) { i in
              ZStack(alignment: .topTrailing) {
                viewModel.selectedImages[i]
                  .resizable()
                  .scaledToFill()
                  .frame(width: 100, height: 100)
                  .clipShape(RoundedRectangle(cornerRadius: 12))
                  .overlay(
                    RoundedRectangle(cornerRadius: 12)
                      .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                  )

                Button {
                  viewModel.removeImage(index: i)
                } label: {
                  ZStack {
                    Circle()
                      .fill(Color.white)
                      .frame(width: 22, height: 22)
                      .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 2,
                        x: 0,
                        y: 1
                      )

                    Image(systemName: "xmark")
                      .font(.system(size: 10, weight: .bold))
                      .foregroundColor(.gray)
                  }
                }
                .padding(6)
              }
              .padding(4)
            }
          }
          .padding(.horizontal)
        }

        Divider()

        HStack {
          PhotosPicker(
            selection: $viewModel.selectedItems,
            maxSelectionCount: 10,
            selectionBehavior: .ordered,
            matching: .images
          ) {
            Image(systemName: "photo.badge.plus")
              .padding(.leading)
          }

          Spacer()

          Text("\(text.string.count)/1000")
            .foregroundStyle(
              text.string.count > 1000
                ? Color.red.opacity(0.7) : Color.primary.opacity(0.5)
            )
        }

        if let errorText = viewModel.errorDisplay {
          Text(errorText)
            .foregroundColor(.red)
            .font(.caption)
        }
      }
      .padding()
    }
  }

  private var isPostButtonDisabled: Bool {
    (text.string.isEmpty
      && viewModel.selectedImages.count == 0)
      || viewModel.isLoading
  }
}

struct NewPostView_Previews: PreviewProvider {
  static var previews: some View {
    NewPostView()
  }
}
