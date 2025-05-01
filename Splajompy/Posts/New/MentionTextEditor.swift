import SwiftUI
import UIKit



@MainActor
class MentionViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var attributedText = NSAttributedString()
    @Published var mentionSuggestions: [User] = []
    @Published var isShowingSuggestions = false
    @Published var facets: [Facet] = []
    
    private var service: ProfileServiceProtocol = ProfileService()
    private var mentionStartIndex: String.Index?
    private var mentionPrefix: String = ""
    private var lastFetchTask: DispatchWorkItem?
    
    func processTextChange() {
        lastFetchTask?.cancel()
        
        if let (startIndex, prefix) = findCurrentMentionPrefix(in: text) {
            mentionStartIndex = startIndex
            mentionPrefix = prefix
            
            let task = DispatchWorkItem { [weak self] in
                self?.fetchSuggestions(prefix: prefix)
            }
            
            lastFetchTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
        } else {
            isShowingSuggestions = false
            mentionStartIndex = nil
            mentionPrefix = ""
        }
        
        applyMentionHighlighting()
    }
    
    private func findCurrentMentionPrefix(in text: String) -> (startIndex: String.Index, prefix: String)? {
        let mentionPattern = "(?<=^|\\s)@([\\w]*)"
        guard let regex = try? NSRegularExpression(pattern: mentionPattern) else {
            return nil
        }
        
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        let matches = regex.matches(in: text, range: range)
        guard let lastMatch = matches.last else {
            return nil
        }
        
        let matchStartIndex = text.index(text.startIndex, offsetBy: lastMatch.range.location)
        let atSignIndex = matchStartIndex
        
        var prefix = ""
        if lastMatch.numberOfRanges > 1 {
            let prefixRange = lastMatch.range(at: 1)
            prefix = nsString.substring(with: prefixRange)
        }
        
        return (atSignIndex, prefix)
    }
    
    func fetchSuggestions(prefix: String) {
        Task {
            let response = await service.getUserFromUsernamePrefix(prefix: prefix)
            switch response {
            case .success(let users):
                self.mentionSuggestions = users
                self.isShowingSuggestions = !users.isEmpty
            case .error:
                print("error")
            }
        }
    }
    
    func selectUser(_ user: User) {
        guard let mentionStartIndex = mentionStartIndex else { return }
        
        let mentionPrefixEndIndex = text.index(mentionStartIndex, offsetBy: mentionPrefix.count + 1)
        let replaceRange = mentionStartIndex..<mentionPrefixEndIndex
        
        let fullMention = "@\(user.username)"
        text = text.replacingCharacters(in: replaceRange, with: fullMention)
        
        isShowingSuggestions = false
        
        // Create facet for the mention
        let startOffset = text.distance(from: text.startIndex, to: mentionStartIndex)
        let endOffset = startOffset + fullMention.count
        
        let newFacet = Facet(
            type: "mention",
            index: startOffset...endOffset-1,
            userId: user.userId
        )
        
        // Update facets, replacing any that overlap with this range
        facets = facets.filter { facet in
            !doRangesOverlap(facet.index, newFacet.index)
        }
        facets.append(newFacet)
        
        applyMentionHighlighting()
    }
    
    private func doRangesOverlap(_ range1: ClosedRange<Int>, _ range2: ClosedRange<Int>) -> Bool {
        return range1.overlaps(range2)
    }
    
    private func applyMentionHighlighting() {
        let attributedString = NSMutableAttributedString(string: text)
        
        // Apply highlighting for all facets
        for facet in facets {
            let range = NSRange(
                location: facet.index.lowerBound,
                length: facet.index.upperBound - facet.index.lowerBound + 1
            )
            
            attributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
            attributedString.addAttribute(.backgroundColor, value: UIColor.systemBlue.withAlphaComponent(0.1), range: range)
            attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize), range: range)
        }
        
        self.attributedText = attributedString
    }
    
    // Get facets for submission to API
    func getFacetsForSubmission() -> [Facet] {
        return facets
    }
    
    // Handle text editing that might affect facets
    func handleTextEdit(oldText: String, newText: String) {
        if oldText == newText { return }
        
        // Update facet indices based on text changes
        if !facets.isEmpty {
            let changes = calculateTextChanges(from: oldText, to: newText)
            updateFacetIndices(with: changes)
        }
    }
    
    private func calculateTextChanges(from oldText: String, to newText: String) -> [(offset: Int, delta: Int)] {
        // Simple implementation - can be enhanced for better performance
        // Returns a list of change offsets and their impact on indices
        
        // For simplicity, if the length changed dramatically, we'll rebuild facets
        if abs(oldText.count - newText.count) > 10 {
            facets = []
            return []
        }
        
        // Find common prefix
        var prefixLength = 0
        let minLength = min(oldText.count, newText.count)
        
        while prefixLength < minLength &&
              oldText[oldText.index(oldText.startIndex, offsetBy: prefixLength)] ==
              newText[newText.index(newText.startIndex, offsetBy: prefixLength)] {
            prefixLength += 1
        }
        
        // Calculate change
        let delta = newText.count - oldText.count
        return [(offset: prefixLength, delta: delta)]
    }
    
    private func updateFacetIndices(with changes: [(offset: Int, delta: Int)]) {
        var updatedFacets: [Facet] = []
        
        for facet in facets {
            var adjustedFacet = facet
            
            for change in changes {
                // If change affects this facet
                if change.offset <= facet.index.upperBound {
                    // If change occurs within facet
                    if change.offset >= facet.index.lowerBound {
                        // Facet might be broken - skip it
                        continue
                    } else {
                        // Change is before facet, adjust indices
                        let newLower = facet.index.lowerBound + change.delta
                        let newUpper = facet.index.upperBound + change.delta
                        
                        // Only keep valid facets
                        if newLower <= newUpper {
                            adjustedFacet = Facet(
                                type: facet.type,
                                index: newLower...newUpper,
                                userId: facet.userId
                            )
                        } else {
                            // Facet is no longer valid
                            continue
                        }
                    }
                }
            }
            
            // Only add if still valid
            if adjustedFacet.index.lowerBound <= adjustedFacet.index.upperBound {
                updatedFacets.append(adjustedFacet)
            }
        }
        
        facets = updatedFacets
    }
}

// Extension to make finding NSRange easier
//extension String {
//  func nsRange(of string: String, from startIndex: String.Index) -> NSRange? {
//    guard let range = self.range(of: string, range: startIndex..<self.endIndex) else {
//      return nil
//    }
//    
//    return NSRange(
//      location: self.distance(from: self.startIndex, to: range.lowerBound),
//      length: self.distance(from: range.lowerBound, to: range.upperBound)
//    )
//  }
//}

struct MentionTextEditor: View {
    @Binding var text: String
    @Binding var facets: [Facet]
    var onTextChange: ((String) -> Void)?
    
    @StateObject private var viewModel = MentionViewModel()
    @State private var textViewHeight: CGFloat = 150
    @State private var previousText: String = ""
    
    var body: some View {
        VStack {
            ZStack(alignment: .topLeading) {
                TextViewRepresentable(
                    text: $viewModel.text,
                    attributedText: viewModel.attributedText,
                    onTextChange: { newText in
                        viewModel.handleTextEdit(oldText: previousText, newText: newText)
                        previousText = newText
                        viewModel.processTextChange()
                        text = newText
                        facets = viewModel.facets
                        onTextChange?(newText)
                    },
                    height: $textViewHeight
                )
                .frame(height: textViewHeight)
                .padding(4)
                .onAppear {
                    viewModel.text = text
                    previousText = text
                    viewModel.processTextChange()
                }
                .onChange(of: text) { oldValue, newValue in
                    if viewModel.text != newValue {
                        viewModel.text = newValue
                        viewModel.processTextChange()
                    }
                }
                
                if viewModel.text.isEmpty {
                    Text("Type @ to mention someone...")
                        .foregroundColor(Color(.placeholderText))
                        .padding(8)
                        .allowsHitTesting(false)
                }
            }
            .border(Color.gray.opacity(0.3))
            
            if viewModel.isShowingSuggestions {
                suggestionView
            }
        }
    }
    
    private var suggestionView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.mentionSuggestions, id: \.userId) { user in
                    suggestionRow(for: user)
                }
            }
            .padding(8)
        }
        .frame(height: min(CGFloat(viewModel.mentionSuggestions.count * 44), 180))
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func suggestionRow(for user: User) -> some View {
        HStack {
            Text("@\(user.username)")
                .fontWeight(.medium)
            Text("• \(user.name ?? user.username)")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(4)
        .onTapGesture {
            viewModel.selectUser(user)
            text = viewModel.text
            facets = viewModel.facets
            onTextChange?(viewModel.text)
        }
    }
}
struct TextViewRepresentable: UIViewRepresentable {
  @Binding var text: String
  var attributedText: NSAttributedString
  var onTextChange: ((String) -> Void)?
  @Binding var height: CGFloat
  
  func makeUIView(context: Context) -> UITextView {
    let textView = UITextView()
    textView.delegate = context.coordinator
    textView.isScrollEnabled = true
    textView.isEditable = true
    textView.isUserInteractionEnabled = true
    textView.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
    textView.backgroundColor = .clear
    return textView
  }
  
  func updateUIView(_ uiView: UITextView, context: Context) {
    if text != uiView.text {
      // Only update if different to avoid cursor jumping
      let selectedRange = uiView.selectedRange
      uiView.attributedText = attributedText
      if selectedRange.location <= attributedText.length {
        uiView.selectedRange = selectedRange
      }
    }
    
    // Update height based on content
    DispatchQueue.main.async {
      let newSize = uiView.sizeThatFits(CGSize(width: uiView.frame.width, height: CGFloat.greatestFiniteMagnitude))
      if height != newSize.height {
        height = max(150, newSize.height) // Minimum height of 150
      }
    }
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text, onTextChange: onTextChange)
  }
  
  class Coordinator: NSObject, UITextViewDelegate {
    @Binding var text: String
    var onTextChange: ((String) -> Void)?
    
    init(text: Binding<String>, onTextChange: ((String) -> Void)?) {
      self._text = text
      self.onTextChange = onTextChange
    }
    
    func textViewDidChange(_ textView: UITextView) {
      text = textView.text
      onTextChange?(textView.text)
    }
  }
}
