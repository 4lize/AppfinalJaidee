//
//  ContentView.swift
//  Jaidee
//
//  Created by Teerapat Kuanphuek on 2/12/2568 BE.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    var body: some View {
        
        Group{
            if authViewModel.isAuthenticated {
                HomeView(authViewModel: authViewModel)
            } else {
                LoginView(authViewModel: authViewModel)
            }
        }
        .task {
            do {
                try await authViewModel.getInitialSession()
            } catch {
                print("Failed to get initial session: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
}
