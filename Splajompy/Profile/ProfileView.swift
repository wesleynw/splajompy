//
//  ProfileView.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/28/25.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel: ViewModel
    
    init(userID: Int) {
        _viewModel = StateObject(wrappedValue: ViewModel(userID: userID))
    }
    
    var body: some View {
        Text("Profile")
    }
}
