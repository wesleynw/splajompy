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
          ToolbarItem(placement: .topBarLeading) {
            if #available(iOS 26.0, *) {
              Button(role: .close, action: { dismiss() })
            } else {
              Button {
                dismiss()
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .opacity(0.8)
              }
              .buttonStyle(.plain)
            }
          }

          #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
              EditButton()
            }
          #endif

          ToolbarItem(placement: .topBarTrailing) {
            if #available(iOS 26, *) {
              Button(action: savePoll) {
                Text("Save")
              }
              .buttonStyle(.borderedProminent)
              .disabled(!isValidPoll)
            } else {
              Button(action: savePoll) {
                Image(systemName: "checkmark.circle.fill")
                  .opacity(0.8)
              }
              .disabled(!isValidPoll)
            }
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
    title.count <= 100
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

  #if os(iOS)
    @Environment(\.editMode) private var editMode
  #endif

  private func placeholder(for index: Int) -> String {
    let placeholders = ["Red", "Green", "Mauve", "Vermilion", "Periwinkle"]
    return index < placeholders.count ? placeholders[index] : "Option \(index + 1)"
  }

  var body: some View {
    Section {
      VStack(alignment: .leading) {
        TextField("What's your favorite color?", text: $title)
          #if os(iOS)
            .disabled(editMode?.wrappedValue == .active)
          #endif
        HStack {
          Spacer()
          Text("\(title.count)/100")
            .font(.caption2)
            .foregroundColor(title.count > 100 ? .orange : .secondary)
        }
      }
    } header: {
      Text("Title (Optional)")
    }

    Section {
      ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
        HStack {
          TextField(
            placeholder(for: index),
            text: Binding(
              get: { options[index].text },
              set: { newValue in
                options[index].text = newValue
              }
            )
          )
          .focused($focusedField, equals: index)
          #if os(iOS)
            .disabled(editMode?.wrappedValue.isEditing == true)
          #endif

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
