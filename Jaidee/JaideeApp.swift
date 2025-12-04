//
//  JaideeApp.swift
//  Jaidee
//
//  Created by Teerapat Kuanphuek on 2/12/2568 BE.
//

import SwiftUI

@main
struct JaideeApp: App {
    @StateObject var authVM = AuthViewModel() //สร้าง
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM) //ส่งต่อ
        }
    }
}
