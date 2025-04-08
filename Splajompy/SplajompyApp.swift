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
  @StateObject private var feedRefreshManager = FeedRefreshManager()
  @State private var isShowingNewPostView = false

  var body: some Scene {
    WindowGroup {
      Group {
        if authManager.isAuthenticated {
          let (userId, username) = authManager.getCurrentUser()
          TabView {
            Tab("Home", systemImage: "house") {
              NavigationStack {
                FeedView(feedType: .home)
                  .environmentObject(feedRefreshManager)
                  .environmentObject(authManager)
                  .toolbar {
                    Button(
                      "Post",
                      systemImage: "plus",
                      action: { isShowingNewPostView = true }
                    )
                    .labelStyle(.iconOnly)
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
                FeedView(feedType: .all)
                  .environmentObject(feedRefreshManager)
                  .environmentObject(authManager)
                  .navigationTitle("All")
              }
            }

            Tab("Profile", systemImage: "person.circle") {
              NavigationStack {
                ProfileView(
                  userId: userId,
                  username: username
                )
                .environmentObject(feedRefreshManager)
                .environmentObject(authManager)
                .toolbar {
                  NavigationLink(
                    destination: SettingsView().environmentObject(authManager)
                  ) {
                    Image(systemName: "gearshape")
                  }
                }
              }
            }
          }
          .sheet(isPresented: $isShowingNewPostView) {
            NewPostView(
              dismiss: { isShowingNewPostView = false },
              onPostCreated: { feedRefreshManager.triggerRefresh() }
            )
            .interactiveDismissDisabled()
          }
        } else {
          LoginView()
            .environmentObject(authManager)
        }
      }
    }
  }
}
