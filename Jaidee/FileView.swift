//
//  FileView.swift
//  Jaidee
//
//  Created by Teerapat Kuanphuek on 5/12/2568 BE.
//

import SwiftUI
import Combine
import Supabase

@MainActor
class FileViewModel: ObservableObject {
    private let authViewModel: AuthViewModel
    @Published var file: [File] = []
    @Published var isLoading = false

    // เก็บ Task ปัจจุบันเพื่อยกเลิกก่อนเริ่มอันใหม่
    private var currentLoadTask: Task<Void, Never>?

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    func loadComment(reset: Bool = false) async {
        // ยกเลิกงานก่อนหน้า
        currentLoadTask?.cancel()

        currentLoadTask = Task { [weak self] in
            guard let self else { return }
            if Task.isCancelled { return }

            // ตั้งสถานะโหลดก่อน เเละรีเซ็ตเมื่อร้องขอ
            isLoading = true
            if reset {
                self.file = [] // รีเซ็ตเพื่อให้ UI แสดงตัวโหลดแทนการ์ดเก่า
            }
            
            defer { isLoading = false }

            do {
                let uid = authViewModel.session?.user.id.uuidString ?? "7ce30b8d-acf9-4f98-9ee1-25f2961759f6"
                let fetched = try await DatabaseManager.shared.fetchFile(id: uid)
                if Task.isCancelled { return }
                self.file = fetched
            } catch {
                // มองข้ามกรณีถูกยกเลิก
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    return
                }
                print("Failed to fetch posts", error)
                // ถ้าอยากให้ว่างเมื่อ error ก็ปล่อยไว้, ตอนนี้คงเป็น [] อยู่แล้วเมื่อ reset
                // ถ้าไม่ reset ก็อย่าไปล้าง จะคงข้อมูลเดิมไว้ได้
            }
        }

        await currentLoadTask?.value
    }
}

struct FileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var vm: FileViewModel

    init(authViewModel: AuthViewModel) {
        _vm = StateObject(wrappedValue: FileViewModel(authViewModel: authViewModel))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 10) {
                if vm.isLoading && vm.file.isEmpty {
                    // แสดงตัวโหลดแทน ไม่ให้จอขาว
                    ProgressView("กำลังโหลด...")
                        .padding(.top, 24)
                } else if vm.file.isEmpty {
                    // สถานะว่างหลังโหลดเสร็จแล้วแต่ไม่มีข้อมูล
                    Text("ไม่มีไฟล์")
                        .foregroundColor(.secondary)
                        .padding(.top, 24)
                } else {
                    // แสดงการ์ดเมื่อมีข้อมูล
                    ForEach(vm.file, id: \.id) { file in
                        cardFile(file: file)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .task {
            // โหลดครั้งแรก รีเซ็ตและแสดงตัวโหลด
            await vm.loadComment(reset: true)
        }
        .refreshable {
            // รีเซ็ตและโหลดใหม่บน pull-to-refresh
            await vm.loadComment(reset: true)
        }
    }
}

struct cardFile: View {
    let file: File
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                FetchingPic.displayImage(
                    pic_url: file.post?.thumbnail_url,
                    cornerRadius: 12,
                    width: 120,
                    height: 80
                )
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(file.post?.title ?? "<Title>")
                            .font(.headline)
                        Text("\(file.amount!, specifier: "%.2f") บาท")
                            .font(.headline)
                        HStack {
                            Spacer()
                            if file.status == "1" {
                                Text("...Pending")
                                    .font(.body.bold())
                                    .foregroundColor(Color.orange)
                            }
                            else if file.status == "2" {
                                Text("Accept")
                                    .font(.body.bold())
                                    .foregroundColor(Color.green)
                            }
                            else if file.status == "3" {
                                Text("Reject")
                                    .font(.body.bold())
                                    .foregroundColor(Color.red)
                            }
                        }
                    }
                    Spacer()
                }
            }
            HStack {
                Spacer()
                ButtonView(file: file)
            }
        }
        .frame(width: 350, height: 150)
        .padding(.horizontal, 10)
        .padding(.vertical, 0)
        .background(Color(red: 0.73, green: 0.87, blue: 0.91))
        .cornerRadius(12)
    }
}

struct ButtonView: View {
    let file:File
    
    var body: some View {
        if file.status == "3" {
            Button {
                Task {
                    
                }
            }label: {
                Text("โปรดติดต่อมูลนิธิ")
                    .frame(width: 150)
                    .foregroundColor(.black.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.red.opacity(0.8), lineWidth: 3)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
        else if file.file == nil {
            Button {
                Task {
                    
                }
            }label: {
                Text("โปรดรอไฟล์หลักฐาน")
                    .frame(width: 150)
                    .foregroundColor(.black.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.orange.opacity(0.8), lineWidth: 3)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
        else {
            Button {
                Task {
                    await downloadPDF()
                }
            }label: {
                Text("โหลดไฟล์หลักฐาน")
                    .frame(width: 150)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(20)
            }
        }
    }

    func downloadPDF() async {
        
        do {
            //ดึงจากsupabaseใน  bucket file
            let data = try await supabase.storage
                .from("file")
                .download(path: file.file ?? "")//

            //อันนี้เอาใส่ในไฟล์แอปชั่วคราว
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(file.file ?? "หลักฐาน")
            try data.write(to: tempURL)

            // เปิด Share Sheet ให้ user เซฟ / เปิดไฟล์
            let av = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .first?.keyWindow?.rootViewController?
                .present(av, animated: true)

        } catch {
            print("Error:", error.localizedDescription)
        }
    }
}

#Preview {
    // For preview, construct and inject the same instance both ways.
    let authVM = AuthViewModel()
    return FileView(authViewModel: authVM)
        .environmentObject(authVM)
}
