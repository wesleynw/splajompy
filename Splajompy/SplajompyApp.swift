//
//  SplajompyApp.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/17/25.
//

import SwiftUI

@main
struct SplajompyApp: App {
  @StateObject private var authManager = AuthManager()
  @State private var isShowingNewPostView = false

  var body: some Scene {
    WindowGroup {
      Group {
        if authManager.isAuthenticated {
          let (userId, username) = authManager.getCurrentUser()
          TabView {
            Tab("Home", systemImage: "house") {
              NavigationStack {
                ScrollView {
                  FeedView(feedType: .home)
                    .toolbar {
                      Button(
                        "Post",
                        systemImage: "plus",
                        action: { isShowingNewPostView = true }
                      )
                      .labelStyle(.iconOnly)
                    }
                }
                .navigationTitle("Splajompy")
              }
            }

            Tab("Notifications", systemImage: "bell") {
              NavigationStack {
                Text("Notifications")
                  .font(.title3)
                  .navigationTitle("Notifications")
              }
            }

            Tab("All", systemImage: "globe") {
              NavigationStack {
                ScrollView {
                  FeedView(feedType: .all)
                    .navigationTitle("All")
                }
              }
            }

            Tab("Profile", systemImage: "person.circle") {
              ProfileView(
                userId: userId,
                username: username,
                isOwnProfile: true
              )
            }
          }
          .sheet(isPresented: $isShowingNewPostView) {
            NewPostView(onPost: { print("Post submitted") })
            //              .interactiveDismissDisabled()
          }
        } else {
          LoginView()
            .environmentObject(authManager)
        }
      }
    }
  }
}
