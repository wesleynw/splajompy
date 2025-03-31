//
//  ContentView.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/17/25.
//

import SwiftUI

enum FeedType {
    case Home
    case All
    case Profile
}

struct FeedView: View {
    var feedType: FeedType
    var userID: Int?
    @StateObject private var viewModel: ViewModel
    
    init(feedType: FeedType, userID: Int? = nil) {
        self.feedType = feedType
        self.userID = userID
        _viewModel = StateObject(wrappedValue: ViewModel(feedType: feedType, userID: userID))
    }
    
    var body: some View {
        ScrollView {
            // Main content
            VStack {
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                } else if viewModel.posts.isEmpty && !viewModel.error.isEmpty {
                    Text("Error: \(viewModel.error)")
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 100)
                } else if viewModel.posts.isEmpty {
                    Text("No posts yet")
                        .foregroundColor(.gray)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 100)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.posts, id: \.Post.PostID) { post in
                            PostView(post: post, onLikeButtonTapped: {
                                viewModel.toggleLike(on: post)
                            })
                            .onAppear {
                                if post == viewModel.posts.last {
                                    viewModel.loadMorePosts()
                                }
                            }
                            .id("post-\(post.Post.PostID)")
                        }
                        
                        if viewModel.isLoading && !viewModel.posts.isEmpty {
                            ProgressView()
                                .scaleEffect(1.2)
                                .padding()
                                .id("loading-indicator")
                        }
                    }
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            if viewModel.posts.isEmpty && !viewModel.isLoading {
                viewModel.refreshPosts()
            }
        }
        .refreshable {
            viewModel.refreshPosts()
        }
    }
}
