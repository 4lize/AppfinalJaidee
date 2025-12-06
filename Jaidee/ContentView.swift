//
//  ContentView.swift
//  Jaidee
//
//  Created by Teerapat Kuanphuek on 2/12/2568 BE.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                HomeView()
            } else {
                LoginView()
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
        .environmentObject(AuthViewModel())
}

