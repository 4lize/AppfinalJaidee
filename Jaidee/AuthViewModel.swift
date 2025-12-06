//
//  AuthViewModel.swift
//  Jaidee
//
//  Created by Teerapat Kuanphuek on 2/12/2568 BE.
//

import SwiftUI
import Supabase
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var session: Session?
    @Published var isAuthenticated = false
    
    @Published var Me: Me?
    func getMeInfo() async {
        do {
            let uid = session?.user.id.uuidString ?? ""
            let fetched = try await DatabaseManager.shared.fetchMe(id: uid)
            self.Me = fetched
        } catch {
            print("Failed to fetch post", error)
            self.Me = nil
        }
    }
    
    func getInitialSession() async throws{
        do{
            let current = try await supabase.auth.session
            self.session = current
            self.isAuthenticated = true
            dump(session?.user.id.uuidString)
            //let uid = session?.user.id.uuidString
            //self.Me = try await DatabaseManager.shared.fetchMe(id: uid!)
            await getMeInfo()
        } catch {
            print("No active session: \(error.localizedDescription)")
        }
    }
    
    func signUp(email: String, password: String) async throws{
        do {
            let result = try await supabase.auth.signUp(email: email, password: password)
            self.session = result.session
            self.isAuthenticated = self.session != nil}
        catch{
            print("Sign up failed: \(error.localizedDescription)")
        }
    }
    
    func signIn(email: String, password: String) async throws{
        do{
            let result = try await supabase.auth.signIn(email: email, password: password)
            self.session = result
            self.isAuthenticated = self.session != nil
            await getMeInfo()
        }
        catch{
            print("Sign in failed: \(error.localizedDescription)")
        }
    }
    
    func signOut() async throws{
        do{
            try await supabase.auth.signOut()
            self.session = nil
            self.isAuthenticated = false
        }
        catch{
            print("Sign out failed: \(error.localizedDescription)")
        }
    }
}
