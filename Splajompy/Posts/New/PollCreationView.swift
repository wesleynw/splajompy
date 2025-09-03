import SwiftUI

struct PollCreationView: View {
  @Binding var poll: PollCreationRequest?

  @Environment(\.dismiss) private var dismiss

  @State private var title = ""
  @State private var options: [(id: UUID, text: String)] = [(id: UUID(), text: "")]
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
        options =
          existingPoll.options.isEmpty
          ? [(id: UUID(), text: "")] : existingPoll.options.map { (id: UUID(), text: $0) }
      }
    }
  }

  private var formContent: some View {
    Form {
      PollFormContent(
        title: $title,
        options: $options,
        focusedField: $focusedField,
        addOptionButton: addOptionButton
      )
    }
  }

  private var isValidPoll: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && title.count <= 100
      && options.filter {
        !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }.count >= 2 && options.allSatisfy({ $0.text.count <= 25 })
  }

  private var addOptionButton: some View {
    Button {
      options.append((id: UUID(), text: ""))
      focusedField = options.count - 1
    } label: {
      Label("Add Option", systemImage: "plus.circle")
    }
  }

  private func savePoll() {
    let validOptions = options.compactMap { option in
      let trimmed = option.text.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
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

private struct PollFormContent<AddButton: View>: View {
  @Binding var title: String
  @Binding var options: [(id: UUID, text: String)]
  @FocusState.Binding var focusedField: Int?
  let addOptionButton: AddButton

  @Environment(\.editMode) private var editMode

  var body: some View {
    Section("Title") {
      VStack(alignment: .leading) {
        TextField("What's your favorite color?", text: $title)
          .disabled(editMode?.wrappedValue == .active)
        HStack {
          Spacer()
          Text("\(title.count)/100")
            .font(.caption2)
            .foregroundColor(title.count > 100 ? .orange : .secondary)
        }
      }
    }

    Section {
      ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
        HStack {
          TextField(
            "Option \(index + 1)",
            text: Binding(
              get: { options[index].text },
              set: { newValue in
                options[index].text = newValue
              }
            )
          )
          .focused($focusedField, equals: index)
          .disabled(editMode?.wrappedValue.isEditing == true)

          if focusedField == index || options[index].text.count > 25 {
            Text("\(options[index].text.count)/25")
              .font(.caption2)
              .foregroundColor(options[index].text.count > 25 ? .orange : .secondary)
          }
        }
      }
      .onMove { source, destination in
        withAnimation {
          options.move(fromOffsets: source, toOffset: destination)
        }
      }
      .onDelete { offsets in
        guard options.count > 1, offsets.allSatisfy({ $0 < options.count }) else {
          return
        }
        withAnimation {
          options.remove(atOffsets: offsets)
        }
      }

      if options.count < 5 {
        addOptionButton
      }
    } header: {
      Text("Options")
    }
  }
}
