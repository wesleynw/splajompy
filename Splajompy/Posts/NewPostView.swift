//
//  NewPostView.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 4/1/25.
//

import PhotosUI
import SwiftUI

struct NewPostView: View {
  var dismiss: () -> Void
  @StateObject private var viewModel: ViewModel

  init(dismiss: @escaping () -> Void) {
    self.dismiss = dismiss
    _viewModel = StateObject(wrappedValue: ViewModel(dismiss: dismiss))
  }

  @State private var text: String = ""

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button("Cancel") {
          dismiss()
        }

        Spacer()

        Button {
          viewModel.submitPost(text: text)
        } label: {
          if viewModel.isLoading {
            ProgressView()
          } else {
            Text("Post")
              .bold()
          }
        }
        .disabled(isPostButtonDisabled)
      }
      .padding()

      Divider()

      VStack(spacing: 15) {
        ZStack(alignment: .topLeading) {
          TextEditor(text: $text)
            .background(Color.gray)
          if text.isEmpty {
            Text("What's on your mind?")
              .foregroundColor(.gray.opacity(0.8))
              .padding(.horizontal, 5)
              .padding(.top, 8)
              .allowsHitTesting(false)
          }
        }

        PhotosPicker(selection: $viewModel.imageSelection, matching: .images) {
          Image(systemName: "photo.badge.plus")
        }

        if let photoState = viewModel.photoState {
          switch photoState {
            case .loading:
              ProgressView()
                .padding()
            case .success(let image):
              Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .cornerRadius(8)
                .padding()
            case .failed:
              Text("Failed to load image")
                .foregroundColor(.red)
                .padding()
          case .empty:
            Text("no image")
          }
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
    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || viewModel.isLoading
  }
}

struct NewPostView_Previews: PreviewProvider {
  static var previews: some View {
    NewPostView(dismiss: { print("posted!!!! xd") })
  }
}
