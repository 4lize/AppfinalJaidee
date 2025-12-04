//
//  TransactionView.swift
//  Jaidee
//
//  Created by Teerapat Kuanphuek on 3/12/2568 BE.
//

import SwiftUI
import Combine
import Auth
import PhotosUI

@MainActor
class TransactionViewModel: ObservableObject {
    @Published var post: Post?
    @Published var isLoading = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    // Injected from the View
    var donorId: String?
    
    // Form fields
    @Published var amount: String = ""
    @Published var transactionRef: String = ""
    @Published var donorNameInput: String = ""
    @Published var date: Date = Date()
    @Published var comment: String = ""
    
    // Static bank info for display
    let bankName: String = "ธนาคารกรุงเทพ"
    let accountNumber: String = "123-4-56789-0"
    
    func load(postId: Int64) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await DatabaseManager.shared.fetchSpecificPost(id: postId)
            self.post = fetched
            dump(post)
        } catch {
            print("Failed to fetch post", error)
            self.post = nil
        }
    }
    
    //ส่งTransaction
    func uploadTransaction(postId: String) async -> Bool {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        print(donorId)
        
        // Validate amount as Int8 (per current DatabaseManager signature)
        let amtDouble = Double(amount)
        do {
            try await DatabaseManager.shared.uploadTransaction(
                post_id: postId,
                donor_id: donorId,
                name: donorNameInput.isEmpty ? nil : donorNameInput,
                transaction_number: transactionRef.isEmpty ? nil : transactionRef,
                amount: amtDouble!,
                timestamp: date,
                comment: comment
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

struct TransactionView: View {
    let postId: Int64
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = TransactionViewModel()
    @StateObject private var om = OCRViewModel()
    
    @State private var showConfirm = false
    @State private var showResult = false
    @State private var resultMessage = ""
    
    //ส่วนรูปภาพ
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: Image? = nil
    @State private var selectedUIImage: UIImage? = nil
    
    var body: some View {
        ScrollView {
            VStack {
                // Summary
                if vm.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                    Spacer(minLength: 0)
                } else if let post = vm.post {
                    VStack {
                        HStack(alignment: .top, spacing: 16) {
                            FetchingPic.displayImage(pic_url: post.thumbnail_url, cornerRadius: 12, width: 120, height: 80)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    FetchingPic.displayImage(pic_url: post.accounts?.profile_pic, cornerRadius: 999, width: 36, height: 36)
                                    Text(post.accounts?.name_display ?? "<Donee>")
                                        .font(.caption)
                                }
                                Text(post.title ?? "<Title>")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .padding()
                        
                        // Bank info
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("เลขที่บัญชี: \(post.bank_number!)")
                                Spacer()
                                Button("Copy") {
                                    UIPasteboard.general.string = post.bank_number!
                                }
                            }
                            Text("ธนาคาร: \(post.bank!)")
                        }
                        .padding(.horizontal)
                    }
                }
                
                
                // Form
                Form {
                    Section(header: Text("อัพโหลดสลิป")) {
                        if let image = selectedImage {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                                .overlay(Text("ยังไม่ได้เลือกภาพ"))
                        }
                        
                        //ปุ่ม
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images,
                            photoLibrary: .shared()) {
                                Text("เลือกภาพ")
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .onChange(of: selectedItem) {
                                Task {
                                    guard let data = try? await selectedItem?.loadTransferable(type: Data.self),
                                          let uiImage = UIImage(data: data) else { return }
                                    selectedUIImage = uiImage
                                    selectedImage = Image(uiImage: uiImage)
                                    await om.process(image: uiImage)
                                }
                                
                            }
                    }
                    
                    Section(header: Text("ข้อมูลการโอน")) {
                        if om.isProcessing {
                            ProgressView("กำลังอ่านตัวอักษร...")
                        }
                        TextField("ชื่อผู้โอน", text: $vm.donorNameInput)
                        TextField("เลขที่รายการ", text: $vm.transactionRef)
                        TextField("จำนวนเงิน", text: $vm.amount)
                            .keyboardType(.decimalPad)
                        DatePicker("วันเวลาโอน", selection: $vm.date, displayedComponents: [.date, .hourAndMinute])
                    }
                    .disabled(om.isProcessing)
                    .onChange(of: om.senderName) { newValue in
                        if !newValue.isEmpty {
                            vm.donorNameInput = newValue
                        }
                    }
                    .onChange(of: om.transactionId) { newValue in
                        if !newValue.isEmpty {
                            vm.transactionRef = newValue
                        }
                    }
                    .onChange(of: om.amount) { newValue in
                        if !newValue.isEmpty {
                            vm.amount = newValue.replacingOccurrences(of: ",", with: "")
                        }
                    }
                    .onChange(of: om.stimestamp) { newDate in
                        vm.date = newDate
                    }
                    
                    Section(header: Text("คำอวยพร")) {
                        TextField("เขียนคำอวยพร", text: $vm.comment, axis: .vertical)
                            .lineLimit(5...5)
                    }
                }
                .scrollDisabled(true)
                .frame(height: 900)
                
                Button {
                    print(authVM.session?.user.id.uuidString)
                    showConfirm = true
                } label: {
                    Text("ยืนยันบริจาค")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(.blue)
                .clipShape(RoundedRectangle(cornerRadius:10))
                .foregroundColor(.white)
                .padding(.horizontal)
                .disabled(vm.isProcessing)
            }
            .navigationTitle("บริจาค")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await vm.load(postId: postId)
            }
            
            .alert("ยืนยันการส่งข้อมูล", isPresented: $showConfirm) {
                Button("ยืนยัน", role: .destructive) {
                    Task {
                        vm.donorId = authVM.session?.user.id.uuidString
                        let ok = await vm.uploadTransaction(postId: String(postId))
                        resultMessage = ok ? "ส่งข้อมูลสำเร็จ" : (vm.errorMessage ?? "ไม่สำเร็จ")
                        showResult = true
                    }
                }
                Button("ยกเลิก", role: .cancel) {}
            } message: {
                Text("จะส่งแล้ว มั่นใจแล้วใช่หรือไม่")
            }
            .alert(resultMessage, isPresented: $showResult) {
                Button("OK", role: .cancel) { }
            }
        }}
}

#Preview {
    TransactionView(postId: 1)
        .environmentObject(AuthViewModel())
}
