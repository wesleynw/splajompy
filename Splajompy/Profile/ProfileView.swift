import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel: ViewModel
    @EnvironmentObject private var authManager: AuthManager
    
    let userID: Int
    let isOwnProfile: Bool
    
    init(userID: Int, isOwnProfile: Bool) {
        self.userID = userID
        self.isOwnProfile = isOwnProfile
        _viewModel = StateObject(wrappedValue: ViewModel(userID: userID))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isLoadingProfile {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                }
                if let user = viewModel.profile {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.Name ?? "")
                            .font(.title)
                            .fontWeight(.black)
                        
                        HStack {
                            Text("@\(user.Username)")
                                .font(user.Name != nil ? .body : .title3)
                                .fontWeight(.black)
                                .foregroundColor(user.Name != nil ? Color.gray.opacity(0.6) : .primary)
                            
                            Spacer()
                            
                            if isOwnProfile {
                                Button("Sign Out") { authManager.signOut() }
                                    .buttonStyle(.bordered)
                            } else {
                                Button(viewModel.profile?.IsFollowing ?? false ? "Unfollow" : "Follow") { // TODO this is bad
                                    // Toggle follow status
                                    //                                    viewModel.toggle()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        if user.IsFollower {
                            Text("Follows You")
                                .fontWeight(.bold)
                                .foregroundColor(Color.gray.opacity(0.4))
                        }
                        
                        if let bio = user.Bio, !bio.isEmpty {
                            Text(bio)
                                .padding(.vertical, 10)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    VStack(spacing: 0) {
                        if viewModel.isLoadingPosts && !viewModel.isLoadingProfile {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if viewModel.posts.isEmpty {
                            Text("No posts available")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.posts) { post in
                                    PostView(post: post)
                                }
                            }
                            .padding(.horizontal, -16) // Remove horizontal padding from posts
                        }
                    }
                } else if !viewModel.isLoadingProfile {
                    Text("This user doesn't exist.")
                        .font(.title)
                        .fontWeight(.black)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
        }
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .top
        )
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView(userID: 1, isOwnProfile: false)
    }
}
