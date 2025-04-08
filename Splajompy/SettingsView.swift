//
//  SettingsView.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 4/6/25.
//

import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var authManager: AuthManager

  var body: some View {
    List {
      Button(action: authManager.signOut) {
        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
      }
      .listStyle(.plain)
    }
    .navigationTitle("Settings")
  }
}

#Preview {
  SettingsView()
}
