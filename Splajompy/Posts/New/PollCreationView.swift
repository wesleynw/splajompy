import SwiftUI

struct PollCreationView: View {
  @Binding var poll: PollCreationRequest?

  @Environment(\.dismiss) private var dismiss

  @State private var title = ""
  @State private var options: [String] = [""]
  @FocusState private var focusedField: Int?

  var body: some View {
    NavigationView {
      formContent
        .navigationTitle("New Poll")
        #if os(iOS)
          .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
          ToolbarItem(
            placement: {
              #if os(iOS)
                .navigationBarLeading
              #else
                .primaryAction
              #endif
            }()
          ) {
            Button("Cancel") {
              dismiss()
            }
          }

          #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
              EditButton()
            }
          #endif

          ToolbarItem(
            placement: {
              #if os(iOS)
                .navigationBarTrailing
              #else
                .primaryAction
              #endif
            }()
          ) {
            Button("Save") {
              savePoll()
            }
            .fontWeight(.semibold)
            .disabled(!isValidPoll)
          }

        }
    }
    .interactiveDismissDisabled()
    .onAppear {
      if let existingPoll = poll {
        title = existingPoll.title
        options = existingPoll.options.isEmpty ? [""] : existingPoll.options
      }
    }
  }

  private var formContent: some View {
    Form {
      Section("Title") {
        VStack(alignment: .leading) {
          TextField("What's your favorite color?", text: $title)
          HStack {
            Spacer()
            Text("\(title.count)/100")
              .font(.caption2)
              .foregroundColor(title.count > 100 ? .orange : .secondary)
          }
        }
      }

      optionsSection
    }
  }

  private var optionsSection: some View {
    Section {
      ForEach(options.indices, id: \.self) { index in
        optionRow(at: index)
      }
      .onMove(perform: moveOption)
      .onDelete(perform: deleteOption)

      if options.count < 5 {
        addOptionButton
      }
    } header: {
      Text("Options")
    }
  }

  private var isValidPoll: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && title.count <= 100
      && options.filter {
        !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }.count >= 2 && options.allSatisfy({ $0.count <= 25 })
  }

  private func optionRow(at index: Int) -> some View {
    HStack {
      TextField(
        "Option \(index + 1)",
        text: Binding(
          get: { options[index] },
          set: { newValue in
            options[index] = newValue
          }
        )
      )
      .focused($focusedField, equals: index)

      if focusedField == index || options[index].count > 25 {
        Text("\(options[index].count)/25")
          .font(.caption2)
          .foregroundColor(options[index].count > 25 ? .orange : .secondary)
      }
    }
  }

  private var addOptionButton: some View {
    Button {
      withAnimation {
        options.append("")
      }
      focusedField = options.count - 1
    } label: {
      Label("Add Option", systemImage: "plus.circle")
    }
  }

  private func deleteOption(at offsets: IndexSet) {
    guard options.count > 1, offsets.allSatisfy({ $0 < options.count }) else {
      return
    }
    withAnimation {
      options.remove(atOffsets: offsets)
    }
  }

  private func moveOption(from source: IndexSet, to destination: Int) {
    options.move(fromOffsets: source, toOffset: destination)
  }

  private func savePoll() {
    let validOptions = options.filter {
      !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    poll = PollCreationRequest(
      title: title.trimmingCharacters(in: .whitespacesAndNewlines),
      options: validOptions
    )
    dismiss()
  }
}

#Preview {
  @Previewable @State var poll: PollCreationRequest? = PollCreationRequest(
    title: "test poll",
    options: ["Option 1", "Option 2"]
  )

  PollCreationView(poll: $poll)
}
