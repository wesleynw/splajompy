import SwiftUI

struct MentionTextField: View {
    @Binding var text: String
    let placeholder: String
    
    @State private var showSuggestions = false
    @State private var mentionQuery = ""
    @State private var mentionRange: Range<String.Index>?
    
    // Your users data source - replace with actual implementation
    let users: [User] // Assuming you have this data available
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .padding(4)
                .onChange(of: text) { _ in
                    detectMention()
                }
            
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.gray.opacity(0.8))
                    .padding(8)
                    .allowsHitTesting(false)
            }
            
            if showSuggestions {
                VStack {
                    Spacer().frame(height: 40)
                    
                    // Filter users based on query
                    let filteredUsers = users.filter {
                        $0.username.lowercased().contains(mentionQuery.lowercased())
                    }.prefix(5) // Limit to 5 suggestions
                    
                    if filteredUsers.isEmpty {
                        Text("No users found")
                            .padding(8)
                    } else {
                        ForEach(Array(filteredUsers), id: \.userId) { user in
                            Button {
                                insertMention(user)
                            } label: {
                                Text(user.username)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Divider()
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(radius: 2)
                .frame(width: 200)
                .zIndex(1)
            }
        }
    }
    
    private func detectMention() {
        // Find @ symbol followed by text without spaces
        if let atIndex = text.lastIndex(of: "@") {
            let textAfterAt = text[text.index(after: atIndex)...]
            
            if !textAfterAt.isEmpty && !textAfterAt.contains(" ") {
                mentionQuery = String(textAfterAt)
                mentionRange = atIndex..<text.endIndex
                showSuggestions = true
                return
            }
        }
        
        showSuggestions = false
    }
    
    private func insertMention(_ user: User) {
        guard let range = mentionRange else { return }
        
        // Replace @query with @username format
        let replacement = "@\(user.username) "
        text.replaceSubrange(range, with: replacement)
        
        showSuggestions = false
    }
}

// Integration with your NewPostView
extension NewPostView {
    var mentionField: some View {
        MentionTextField(
            text: $text,
            placeholder: "What's on your mind?",
            users: viewModel.users // Assuming you have a way to get users
        )
        .frame(height: 150)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
