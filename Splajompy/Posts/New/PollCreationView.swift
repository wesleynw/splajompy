import SwiftUI

struct PollCreationView: View {
  @Binding var poll: PollCreationRequest?
  @Environment(\.dismiss) private var dismiss

  @State private var title = ""
  @State private var options: [String] = [""]
  @State private var optionIDs: [UUID] = [UUID()]
  @FocusState private var focusedField: Int?

  var body: some View {
    NavigationView {
      formContent
        .navigationTitle("Create Poll")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
              dismiss()
            }
          }

          ToolbarItem(placement: .navigationBarTrailing) {
            saveButton
          }

          ToolbarItem(placement: .topBarTrailing) {
            EditButton()
          }
        }
    }
    .interactiveDismissDisabled()
    .onAppear {
      if let existingPoll = poll {
        title = existingPoll.title
        options = existingPoll.options.isEmpty ? [""] : existingPoll.options
        optionIDs = options.map { _ in UUID() }
      }
    }
  }

  private var formContent: some View {
    Form {
      Section("Title") {
        TextField("What's your favorite color?", text: $title)
      }

      optionsSection
    }
    .background(
      Color.clear
        .contentShape(Rectangle())
        .onTapGesture {
          focusedField = nil
        }
    )
  }

  private var optionsSection: some View {
    Section {
      ForEach(Array(zip(optionIDs, options.enumerated())), id: \.0) {
        id,
        indexedOption in
        let (index, _) = indexedOption
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
      && options.filter {
        !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }.count >= 2
  }

  private var saveButton: some View {
    Button("Save") {
      savePoll()
    }
    .disabled(!isValidPoll)
  }

  private func optionRow(at index: Int) -> some View {
    HStack {
      TextField(
        "Option \(index + 1)",
        text: Binding(
          get: { options[index] },
          set: { newValue in
            options[index] = String(newValue.prefix(25))
          }
        )
      )
      .focused($focusedField, equals: index)

      if focusedField == index {
        Text("\(options[index].count)/25")
          .font(.caption2)
          .foregroundColor(options[index].count > 20 ? .orange : .secondary)
      }
    }
  }

  private var addOptionButton: some View {
    Button {
      withAnimation {
        options.append("")
        optionIDs.append(UUID())
      }
      focusedField = options.count - 1
    } label: {
      Label("Add Option", systemImage: "plus.circle")
    }
  }

  private func deleteOption(at offsets: IndexSet) {
    guard options.count > 1 else { return }
    withAnimation {
      options.remove(atOffsets: offsets)
      optionIDs.remove(atOffsets: offsets)
    }
  }

  private func moveOption(from source: IndexSet, to destination: Int) {
    options.move(fromOffsets: source, toOffset: destination)
    optionIDs.move(fromOffsets: source, toOffset: destination)
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
