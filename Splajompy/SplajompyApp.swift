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
//                    TabView {
//                        Tab("Home", systemImage: "house") {
                            HomeView()
//                        }
//                        Tab("Profile", systemImage: "person.circle") {
//                            LoginView()
//                                .environmentObject(authManager)
//                        }
//                    }
                } else {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
        }
    }
}
