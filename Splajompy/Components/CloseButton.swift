import SwiftUI

struct CloseButton: View {
  var dismiss: DismissAction

  var body: some View {
    #if os(iOS)
      if #available(iOS 26, *) {
        Button(role: .close) {
          dismiss()
        }
      } else {
        Button {
          dismiss()
        } label: {
          Text("Close")
            .font(SJFont.body)
        }
        .controlSize(.large)
        .modify {
          if #available(anyAppleOS 26, *) {
            $0.buttonStyle(.glass)
          }
        }
      }
    #else
      Button {
        dismiss()
      } label: {
        Text("Close")
          .font(SJFont.body)
      }
      .controlSize(.large)
      .modify {
        if #available(anyAppleOS 26, *) {
          $0.buttonStyle(.glass)
        }
      }
    #endif
  }
}
