//
//  HomeView.swift
//  Jaidee
//
//  Created by Teerapat Kuanphuek on 2/12/2568 BE.
//

import SwiftUI
import Combine

class HomeViewModel: ObservableObject {
    // ดึงมาเป็นArray ตามโครงสร้าง'Post'
    @Published var posts: [Post] = []

    @MainActor
    func loadPosts() async {
        do {
            let fetched = try await DatabaseManager.shared.fetchPost()
            self.posts = fetched
        } catch {
            print("Failed to fetch posts", error)
            self.posts = []
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack{
            VStack(spacing: 16) {
                HeaderView()
                ZStack{
                    if viewModel.posts.isEmpty {
                        ProgressView("Loading...")
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .center, spacing: 20) {
                                ForEach(viewModel.posts, id: \.id) { post in
                                    PostCard(post: post)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                            .padding(.horizontal, 0)
                        }
                        .padding()
                    }
                }

                Button("Sign Out") {
                    Task {
                        do {
                            try await authViewModel.signOut()
                        } catch {
                            print("Sign out failed: \(error)")
                        }
                    }
                }
            }
        }
        .background(Color.white)
        .ignoresSafeArea()
        .task {
            await viewModel.loadPosts()
        }
        .refreshable {
            await viewModel.loadPosts()
        }
    }
}

//โครงสร้าง
struct PostCard: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FetchingPic.displayImage(pic_url: post.thumbnail_url, cornerRadius: 0,width: .infinity, height: 230)
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    FetchingPic.displayImage(pic_url: post.accounts!.profile_pic!, cornerRadius: 999,width: 36, height: 36)
                    Text(post.accounts!.name_display!)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                Text(post.title!)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text(post.content!)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(3)

                NavigationLink {
                    FullPostView(postId: post.id)
                } label: {
                    Text("ดูรายละเอียด")
                        .padding(.vertical, 7)
                        .frame(width: 197, height: 33)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.73, green: 0.87, blue: 0.91))
        .cornerRadius(12)
    }
}
//หัวจอ
struct HeaderView: View {
    var body: some View {
        HStack {
            Text("Jaidee")
                .font(.largeTitle)
            Spacer()
            Rectangle()
                .foregroundColor(.green)
                .frame(width: 36, height: 36)
                .cornerRadius(999)
        }
        .padding()
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}

