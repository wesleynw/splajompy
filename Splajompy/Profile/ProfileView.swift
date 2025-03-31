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
                        VStack(alignment: .leading, spacing: 2) {
                            if !user.Name.isEmpty {
                                Text(user.Name)
                                    .font(.title2)
                                    .fontWeight(.black)
                                    .lineLimit(1)
                                
                                Text("@\(user.Username)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                            } else {
                                Text("@\(user.Username)")
                                    .font(.title3)
                                    .fontWeight(.black)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        HStack {
                            Spacer()
                            
                            if isOwnProfile {
                                Button("Sign Out") { authManager.signOut() }
                                    .buttonStyle(.bordered)
                            } else {
                                Button(viewModel.profile?.IsFollowing ?? false ? "Unfollow" : "Follow") { // TODO this is bad
                                    // Toggle follow status
                                    // viewModel.toggle()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        if user.IsFollower {
                            Text("Follows You")
                                .fontWeight(.bold)
                                .foregroundColor(Color.gray.opacity(0.4))
                        }
                        
                        if !user.Bio.isEmpty {
                            Text(user.Bio)
                                .padding(.vertical, 10)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    VStack {
                        FeedView(feedType: .Profile, userID: self.userID)
                            .padding(.horizontal, -16) // Remove horizontal padding from posts
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
