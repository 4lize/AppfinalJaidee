//
//  Supabase.swift
//  Jaidee
//
//  Created by Teerapat Kuanphuek on 2/12/2568 BE.
//

import Supabase
import Foundation
import Combine
import SwiftUI

//อันนี้สำคัญ ไว้เชื่อDatabase
let supabase = SupabaseClient(supabaseURL: URL(string: "https://ebnamplbvcoxazbjylxl.supabase.co")!, supabaseKey: "publickeyAPI")

struct Post: Codable, Identifiable {
    let id: Int64
    let created_at: String
    let author: String?
    let title: String?
    let content: String?
    let accounts: Account?
    let thumbnail_url: String?
    let bank: String?
    let bank_number: String?
    
    struct Account: Codable {
        let name_display: String?
        let profile_pic: String?
    }
}

struct NewTransaction: Encodable {
    let post_id: String
    let donor_id: String?
    let name: String?
    let transaction_number: String?
    let amount: Double?
    let timestamp: Date?
    let comment: String?
}

struct Comment: Codable, Identifiable {
    let id: Int64
    let post_id: Int64
    let donor_id: String?
    let accounts: Account?
    let comment: String?
    let status: String?
    
    struct Account: Codable {
        let name_display: String?
        let profile_pic: String?
    }
}

struct Me: Codable, Identifiable {
    let id: String?
    let name_display: String?
    let name_legal: String?
    let profile_pic: String?
}

//Function Fetch กับ Create
class DatabaseManager {
    static let shared = DatabaseManager()
    
    private init() {}
    
    func fetchPost() async throws -> [Post] {
        try await supabase
            .from("post")
            .select("id, created_at, author, title, content, accounts(name_display, profile_pic), thumbnail_url, bank, bank_number")
            .execute()
            .value
    }
    
    /*
    func createPost(title: String, author: String?) async throws {
        let response = try await supabase
            .from("post")
            .insert([
                "title": title,
                "author": author
            ])
            .execute()
        
        print("Status:", response.status)
    }*/
    
    // fetchเฉพาะโพสที่จะดู
    func fetchSpecificPost(id: Int64) async throws -> Post {
        try await supabase
            .from("post")
            .select("id, created_at, author, title, content, accounts(name_display, profile_pic), thumbnail_url, bank, bank_number")
            .eq("id", value: Int(id)) // or .eq("id", value: String(id))
            .single()
            .execute()
            .value
    }
    
    func uploadTransaction(post_id: String, donor_id: String?, name: String?, transaction_number: String?, amount: Double, timestamp: Date, comment: String? ) async throws {
        let payload = NewTransaction(
            post_id: post_id,
            donor_id: donor_id,
            name: name,
            transaction_number: transaction_number,
            amount: amount,
            timestamp: timestamp,
            comment: comment
        )
        let response = try await supabase
            .from("transaction")
            .insert(payload)
            .execute()
        print("Transaction insert status:", response.status)
    }
    
    func fetchComment(post_id: Int64) async throws -> [Comment] {
        try await supabase
            .from("transaction")
            .select("id, post_id, donor_id, comment, status, accounts(name_display, profile_pic)")
            .eq("post_id", value: Int(post_id))
            .eq("status", value: "2")
            .not("comment", operator: .is, value: Optional<String>.none)//ไม่เป็นnull
            .execute()
            .value
    }
    
    func fetchMe(id: String) async throws -> Me {
        try await supabase
            .from("accounts")
            .select("id, name_display, name_legal, profile_pic")
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }
}


//FunctiongเรียกรูปจากUrl (ใส่ตัวเต็มมันยาวเกิน)
public struct FetchingPic {
    
    /// ฟังก์ชัน public สำหรับแสดงรูปจาก URL
    /// - Parameters:
    ///   - pic_url: URL ของรูป (String)
    ///   - cornerRadius: มุมโค้งของภาพ
    ///   - height: ความสูงของภาพ
    /// - Returns: some View
    public static func displayImage(pic_url: String?, cornerRadius: CGFloat = 0,width: CGFloat = .infinity, height: CGFloat = 230) -> some View {
        
        guard let urlString = pic_url,
              let url = URL(string: urlString) else {
            // กรณี URL ไม่ถูกต้อง
            return AnyView(
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: height)
                    .foregroundColor(.gray)
            )
        }
        
        return AnyView(
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: width, height: height)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipped()
                        .cornerRadius(cornerRadius)
                case .failure:
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: width,height: height)
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
        )
    }
}
