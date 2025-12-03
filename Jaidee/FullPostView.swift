//
//  FullPostView.swift
//  Jaidee
//
//  Created by Teerapat Kuanphuek on 3/12/2568 BE.
//

import SwiftUI
import Combine

@MainActor
final class FullPostViewModel: ObservableObject {
    @Published var post: Post?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(postId: Int64) async {
        isLoading = true
        do {
            let fetched = try await DatabaseManager.shared.fetchSpecificPost(id: postId)
            self.post = fetched
        } catch {
            print("Failed to fetch post", error)
            self.post = nil
        }
        isLoading = false
    }
}

struct FullPostView: View {
    let postId: Int64
    @StateObject private var vm = FullPostViewModel()

    var body: some View {
        NavigationStack{
            VStack(spacing: 0) {
                if vm.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                    Spacer()
                } else if let post = vm.post {
                    // แสดงรายละเอียดโพสต์พื้นฐาน (ยังไม่สน comments)
                    NavigationStack{
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                // Thumbnail (ถ้ามี)
                                if let urlString = post.thumbnail_url, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        case .failure:
                                            Color.gray.opacity(0.2)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                    .frame(height: 200)
                                    .clipped()
                                }
                                
                                // Donee/Author (ถ้ามี)
                                HStack(spacing: 10) {
                                    if let profile = post.accounts?.profile_pic,
                                       let url = URL(string: profile) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                Color.gray.opacity(0.2)
                                            case .success(let image):
                                                image.resizable().scaledToFill()
                                            case .failure:
                                                Color.gray.opacity(0.2)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        .frame(width: 36, height: 36)
                                        .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 36, height: 36)
                                    }
                                    
                                    Text(post.accounts?.name_display ?? "Unknown")
                                        .font(.caption)
                                }
                                
                                Text(post.title ?? "No Title")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text(post.content ?? "")
                                    .font(.body)
                            }
                            .padding()
                        }
                    }
                } else {
                    Text("ไม่มีข้อมูลโพสต์")
                        .padding()
                    Spacer()
                }
                NavigationLink {
                    TransactionView(postId: postId)
                } label: {
                    Text("บริจาค")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(Color.accentColor)
                .foregroundColor(.white)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await vm.load(postId: postId)
            }
        }
    }
}

#Preview {
    // ตัวอย่าง Preview ด้วย id สมมติ (ต้องมีโพสต์ id นี้ในฐานข้อมูลจริงถึงจะโหลดเจอ)
    FullPostView(postId: 1)
}
