//
//  ContentView.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/17/25.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = ViewModel()
    
    var body: some View {
        NavigationStack {
            Text("Splajompy").fontWeight(.black)
            
            ScrollView {
                if !viewModel.error.isEmpty {
                    Text(viewModel.error).padding(.top)
                } else if viewModel.isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                        Spacer()
                    }
                }
            
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.posts) {
                        post in PostView(post: post, onLikeButtonTapped: { viewModel.toggleLike(on: post) }).onAppear {
                            if post == viewModel.posts.last {
                                viewModel.loadMorePosts()
                            }
                        }
                    }
                }
            }
            .refreshable {
                viewModel.refreshPosts()
            }
        }
    }
}
