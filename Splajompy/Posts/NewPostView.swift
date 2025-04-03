//
//  NewPostView.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 4/1/25.
//

import Combine
import SwiftUI

struct NewPostView: View {
  //    let user: User
  var onPost: () -> Void

  @State private var textValue: String = ""
  @State private var images: [UIImage] = []
  @State private var isLoading: Bool = false
  @State private var error: String? = nil

  var body: some View {
    VStack(spacing: 15) {
      // Text Input
      TextEditor(text: $textValue)
        .frame(minHeight: 100)
        .padding(8)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.gray, lineWidth: 1)
        )
        .overlay(
          Group {
            if textValue.isEmpty {
              Text("What change do you wish to see in the world?")
                .foregroundColor(.gray)
                .padding(.leading, 12)
                .padding(.top, 12)
                .frame(
                  maxWidth: .infinity,
                  maxHeight: .infinity,
                  alignment: .topLeading
                )
            }
          }
        )

      // Image Carousel
      if !images.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            ForEach(0..<images.count, id: \.self) { index in
              ZStack(alignment: .topTrailing) {
                Image(uiImage: images[index])
                  .resizable()
                  .scaledToFill()
                  .frame(width: 100, height: 100)
                  .cornerRadius(8)
                  .clipped()

                Button {
                  removeImage(at: index)
                } label: {
                  Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
                }
                .padding(5)
              }
            }
          }
          .padding(.vertical, 10)
        }
        .frame(height: 120)
      }

      // Bottom Controls
      HStack {
        Button {
          showImagePicker()
        } label: {
          Image(systemName: "photo")
            .font(.title2)
            .foregroundColor(.blue)
        }

        Spacer()

        Button {
          submitPost()
        } label: {
          if isLoading {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle())
          } else {
            Text("Post")
              .bold()
              .foregroundColor(.white)
              .padding(.horizontal, 20)
              .padding(.vertical, 10)
              .background(
                (textValue.trimmingCharacters(
                  in: .whitespacesAndNewlines
                ).isEmpty && images.isEmpty) || error != nil
                  ? Color.gray
                  : Color.blue
              )
              .cornerRadius(8)
          }
        }
        .disabled(
          (textValue.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty && images.isEmpty) || error != nil || isLoading
        )
      }

      if let errorText = error {
        Text(errorText)
          .foregroundColor(.red)
          .font(.caption)
      }
    }
    .padding()
    .background(Color(UIColor.systemBackground))
    .cornerRadius(12)
    .shadow(radius: 2)
  }

  private func showImagePicker() {
    // In a real implementation, this would show a UIImagePickerController
    // using UIViewControllerRepresentable. Simplified for this example.
    print("Show image picker")
  }

  private func removeImage(at index: Int) {
    images.remove(at: index)
  }

  private func submitPost() {
    guard !isLoading else { return }
    guard error == nil else { return }

    isLoading = true

    // Simulating network request
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      // In a real implementation, you would:
      // 1. Create post with text
      // 2. Upload images
      // 3. Link images to post

      textValue = ""
      images = []
      isLoading = false
      onPost()
    }
  }
}

// Preview provider for SwiftUI canvas
struct NewPostView_Previews: PreviewProvider {
  static var previews: some View {
    NewPostView(

      onPost: { print("Post submitted") }
    )
  }
}
