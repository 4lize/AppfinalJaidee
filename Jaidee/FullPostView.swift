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
    @Published var comments: [Comment] = []
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
    
    func loadComment(postId: Int64) async {
        do {
            let fetched = try await DatabaseManager.shared.fetchComment(post_id: postId)
            self.comments = fetched
        } catch {
            print("Failed to fetch posts", error)
            self.comments = []
        }
    }

}

struct FullPostView: View {
    let postId: Int64
    @StateObject private var vm = FullPostViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .center, spacing: 0) {
                        if vm.isLoading {
                            ProgressView("Loading...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if let error = vm.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                            Spacer(minLength: 0)
                        } else if let post = vm.post {
                            // แสดงรายละเอียดโพสต์พื้นฐาน
                            VStack(alignment: .center, spacing: 12) {
                                // Thumbnail
                                FetchingPic.displayImage(pic_url: post.thumbnail_url, cornerRadius: 0, width: .infinity, height: 200)
                                VStack(alignment: .leading) {
                                    // Donee/Author
                                    HStack(spacing: 10) {
                                        FetchingPic.displayImage(pic_url: post.accounts?.profile_pic, cornerRadius: 999, width: 36, height: 36)
                                        
                                        Text(post.accounts?.name_display ?? "Unknown")
                                            .font(.callout)
                                    }
                                    
                                    Text(post.title ?? "No Title")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .padding(.top, 8)
                                        .padding(.bottom, 8)
                                    
                                    Text(post.content ?? "")
                                        .font(.body)
                                }
                                .padding(.top)
                                .frame(width: 350)
                            }
                            
                            // Comments
                            VStack(alignment: .center, spacing: 12) {
                                HStack {
                                    Text("คำอวยพรจากผู้บริจาคทุกท่าน")
                                        .padding(.vertical, 20)
                                        .padding(.top, 5)
                                        .font(.title3.bold())
                                        .foregroundColor(Color(red: 0.4, green: 0.68, blue: 0.78))
                                    Spacer()
                                }
                                
                                LazyVStack(alignment: .center, spacing: 20) {
                                    ForEach(vm.comments, id: \.id) { comment in
                                        CommentRowView(comment: comment)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                    }
                                }
                                .padding(.bottom, 12)
                            }
                            .frame(width: 350)
                        } else {
                            Text("ไม่มีข้อมูลโพสต์")
                                .padding()
                            Spacer(minLength: 0)
                        }
                    }
                }
                
                // Button placed directly under the ScrollView, no extra gap
                NavigationLink {
                    TransactionView(postId: postId)
                } label: {
                    Text("บริจาค")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.4, green: 0.68, blue: 0.78))
                        .foregroundColor(.white)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await vm.load(postId: postId)
                await vm.loadComment(postId: postId)
                dump(vm.comments)
            }
        }
    }
}

struct CommentRowView: View {
    let comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                FetchingPic.displayImage(pic_url: comment.accounts?.profile_pic, cornerRadius: 999, width: 40, height: 40)
                Text(comment.accounts!.name_display!)
                    .font(.callout)
            }
            Text(comment.comment!)
                .font(.body)
            Rectangle()
                .foregroundColor(.clear)
                .frame(height: 0)
                .overlay(Rectangle().stroke(Color(.systemGray3), lineWidth: 0.25))
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Color(red: 0.73, green: 0.87, blue: 0.91))
        .frame(width: 370)
        .cornerRadius(12)
    }
}
    
#Preview {
    // ตัวอย่าง Preview ด้วย id สมมติ (ต้องมีโพสต์ id นี้ในฐานข้อมูลจริงถึงจะโหลดเจอ)
    FullPostView(postId: 1)
}
