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

  var body: some Scene {
    WindowGroup {
      Group {
        if authManager.isAuthenticated {
          TabView {
            NavigationStack {
              FeedView(feedType: .home)
                .navigationTitle("Splajompy")
            }
            .tabItem {
              Label("Home", systemImage: "house")
            }

            NavigationStack {
              FeedView(feedType: .all)
                .navigationTitle("All")
            }
            .tabItem {
              Label("All", systemImage: "globe")
            }

            if let userId = authManager.getCurrentUser() {
              NavigationStack {
                ProfileView(userId: userId, isOwnProfile: true)
                  .environmentObject(authManager)
              }
              .tabItem {
                Label("Profile", systemImage: "person.circle")
              }
            }
          }
        } else {
          LoginView()
            .environmentObject(authManager)
        }
      }
    }
  }
}
