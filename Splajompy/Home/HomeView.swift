//
//  ContentView.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/17/25.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = ViewModel()

    // TODO this should be removed after testing
    @EnvironmentObject private var authManager: AuthManager

    
    var body: some View {
        NavigationStack {
            Text("Splajompy").fontWeight(.black)
            Button(action: {
                authManager.signOut()
            }) {
                Text("Sign Out")
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.posts) {
                        post in PostView(post: post, onLikeButtonTapped: { viewModel.toggleLike(on: post) }).onAppear {
                            if post == viewModel.posts.last {
                                viewModel.loadMorePosts()
                            }
                        }
                    }
                }
            }.refreshable {
                viewModel.refreshPosts()
            }
        }
    }
}

#Preview {
    HomeView()
}
