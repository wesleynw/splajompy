import SwiftUI
import UIKit

// MARK: - Rich Text Editor with @mention support
struct MentionTextEditor: UIViewRepresentable {
    @Binding var text: NSAttributedString
    var mentionValidator: (String) -> Bool
    var onTextChange: ((NSAttributedString) -> Void)?
    
    // Track editing state to prevent update loops
    @State private var isEditing = false
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 16)
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.isScrollEnabled = true
        textView.delegate = context.coordinator
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update if we're not already editing to prevent loops
        if !isEditing {
            textView.attributedText = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTextChange: { textView in
                // Set editing flag to prevent update loops
                isEditing = true
                
                // Save cursor position
                let selectedRange = textView.selectedRange
                
                // Process mentions
                let processedText = processText(textView.text ?? "", currentAttributes: textView.attributedText)
                
                // Update the text binding and notify callback
                text = processedText
                onTextChange?(processedText)
                
                // Apply processed text back to textView
                textView.attributedText = processedText
                
                // Restore cursor position
                if selectedRange.location <= processedText.length {
                    textView.selectedRange = selectedRange
                }
                
                // Clear editing flag
                isEditing = false
            }
        )
    }
    
    private func processText(_ plainText: String, currentAttributes: NSAttributedString) -> NSAttributedString {
        let attributedText = NSMutableAttributedString(attributedString: currentAttributes)
        
        // Reset styling
        let fullRange = NSRange(location: 0, length: attributedText.length)
        attributedText.removeAttribute(.foregroundColor, range: fullRange)
        attributedText.removeAttribute(.backgroundColor, range: fullRange)
        attributedText.addAttribute(.font, value: UIFont.systemFont(ofSize: 16), range: fullRange)
        
        // Find mentions using regex
        let pattern = "@([\\w\\d]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return attributedText
        }
        
        let matches = regex.matches(in: plainText, range: NSRange(location: 0, length: plainText.count))
        
        for match in matches {
            let mentionRange = match.range
            
            // Make sure we have a capture group
            guard match.numberOfRanges >= 2 else { continue }
            
            // Get the username part (without @)
            let usernameRange = match.range(at: 1)
            let username = (plainText as NSString).substring(with: usernameRange)
            
            // Check if username is valid
            if mentionValidator(username) {
                // Apply styling for valid mentions
                attributedText.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: mentionRange)
                attributedText.addAttribute(.backgroundColor, value: UIColor.systemBlue.withAlphaComponent(0.1), range: mentionRange)
                attributedText.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 16), range: mentionRange)
            }
        }
        
        return attributedText
    }
    
    // Minimal coordinator just to handle delegate methods
    class Coordinator: NSObject, UITextViewDelegate {
        var onTextChange: (UITextView) -> Void
        
        init(onTextChange: @escaping (UITextView) -> Void) {
            self.onTextChange = onTextChange
        }
        
        func textViewDidChange(_ textView: UITextView) {
            onTextChange(textView)
        }
    }
}

// MARK: - ViewModel (unchanged)
class MentionViewModel: ObservableObject {
    @Published var attributedText = NSAttributedString(string: "")
    @Published var validUsernames = ["john", "jane", "alex", "taylor"]
    
    func isValidUsername(_ username: String) -> Bool {
        return validUsernames.contains(username.lowercased())
    }
    
    func textDidChange(_ newText: NSAttributedString) {
        self.attributedText = newText
    }
}

// MARK: - ContentView (unchanged)
struct ContentView: View {
    @StateObject private var viewModel = MentionViewModel()
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Type @ to mention someone")
                .font(.caption)
                .foregroundColor(.secondary)
            
            MentionTextEditor(
                text: $viewModel.attributedText,
                mentionValidator: viewModel.isValidUsername,
                onTextChange: viewModel.textDidChange
            )
            .frame(minHeight: 150)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            Text("Valid usernames: \(viewModel.validUsernames.joined(separator: ", "))")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
