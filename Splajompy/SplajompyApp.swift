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
                Text("Splajompy").fontWeight(.black)
                
                if authManager.isAuthenticated {
                    TabView {
                        NavigationStack {
                            FeedView(feedType: .Home)
                        }
                        .tabItem {
                            Label("Home", systemImage: "house")
                        }
                        
                        NavigationStack {
                            FeedView(feedType: .All)
                        }
                        .tabItem {
                            Label("All", systemImage: "globe")
                        }
                        
                        if let userID = authManager.getCurrentUser() {
                            NavigationStack {
                                ProfileView(userID: userID, isOwnProfile: true)
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
