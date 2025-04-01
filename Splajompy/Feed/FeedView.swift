//
//  ContentView.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/17/25.
//

import SwiftUI

enum FeedType {
  case home
  case all
  case profile
}

struct FeedView: View {
  var feedType: FeedType
  var userId: Int?
  @StateObject private var viewModel: ViewModel

  init(feedType: FeedType, userId: Int? = nil) {
    self.feedType = feedType
    self.userId = userId
    _viewModel = StateObject(wrappedValue: ViewModel(feedType: feedType, userId: userId))
  }

  var body: some View {
    ScrollView {
      feedContent
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

  private var feedContent: some View {
    VStack {
      if viewModel.isLoading && viewModel.posts.isEmpty {
        loadingPlaceholder
      } else if !viewModel.error.isEmpty && viewModel.posts.isEmpty {
        errorMessage
      } else if viewModel.posts.isEmpty {
        emptyMessage
      } else {
        postsList
      }
    }
  }

  private var loadingPlaceholder: some View {
    ProgressView()
      .scaleEffect(1.5)
      .padding()
      .frame(maxWidth: .infinity)
  }

  private var errorMessage: some View {
    Text("Error: \(viewModel.error)")
      .foregroundColor(.red)
      .padding()
      .frame(maxWidth: .infinity, minHeight: 100)
  }

  private var emptyMessage: some View {
    Text("No posts yet")
      .foregroundColor(.gray)
      .padding()
      .frame(maxWidth: .infinity, minHeight: 100)
  }

  private var postsList: some View {
    LazyVStack(spacing: 0) {
      postsContent

      if viewModel.isLoading && !viewModel.posts.isEmpty {
        ProgressView()
          .scaleEffect(1.2)
          .padding()
          .id("loading-indicator")
      }
    }
  }

  private var postsContent: some View {
    ForEach(viewModel.posts) { post in
      PostView(
        post: post,
        showAuthor: feedType != .profile,
        onLikeButtonTapped: { viewModel.toggleLike(on: post) }
      )
      .id("post-\(feedType)_\(post.post.postId)")
      .onAppear {
        if post == viewModel.posts.last {
          viewModel.loadMorePosts()
        }
      }
    }
  }
}
