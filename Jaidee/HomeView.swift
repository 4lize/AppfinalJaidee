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
        TabView {
            HomeContentView(viewModel: viewModel)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            FileView(authViewModel: authViewModel)
                .tabItem {
                    Label("Files", systemImage: "doc.text")
                }
            ProfileView(authViewModel: authViewModel)
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
        .task {
            await viewModel.loadPosts()
        }
        .refreshable {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            viewModel.posts = []
            await viewModel.loadPosts()
        }
    }
}

// เนื้อหาหลักของ Home เดิม แยกออกมาเพื่อใช้ใน Tab แรก
struct HomeContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        NavigationStack{
            VStack(spacing: 0) {
                HeaderView()
                ZStack{
                    if viewModel.posts.isEmpty {
                        ProgressView("Loading...")
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .center, spacing: 20) {
                                ForEach(viewModel.posts, id: \.id) { post in
                                    PostCard(post: post)
                                        .frame(alignment: .center)
                                }
                            }
                            .padding(.horizontal, 0)
                        }
                        .padding()
                    }
                }
                
                
            }
        }
        .background(Color.white)
        .ignoresSafeArea()
    }
}

//โครงสร้าง
struct PostCard: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FetchingPic.displayImage(pic_url: post.thumbnail_url, cornerRadius: 0,width: 350, height: 230)
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
                        .foregroundColor(Color(red: 0.4, green: 0.68, blue: 0.78))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(Color(red: 0.73, green: 0.87, blue: 0.91))
        .cornerRadius(12)
        .frame(width: 350)
    }
}

//หัวจอ
struct HeaderView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        HStack {
            Text("Jaidee")
                .font(.largeTitle)
                .padding(0)
            Spacer()
            FetchingPic.displayImage(pic_url: authViewModel.Me?.profile_pic, cornerRadius: 999, width: 36, height: 36)
                .padding(0)
        }
        .padding(.top)
        .padding(.horizontal)
        .padding(.bottom, 0)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
