//
//  TransactionView.swift
//  Jaidee
//
//  Created by Teerapat Kuanphuek on 3/12/2568 BE.
//

import SwiftUI
import Combine
internal import Auth
import PhotosUI

@MainActor
class TransactionViewModel: ObservableObject {
    @Published var post: Post?
    @Published var isLoading = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: Image? = nil
    
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
        } catch {
            print("Failed to fetch post", error)
            self.post = nil
        }
    }
    
    func uploadTransaction(userId: String?, postId: String) async -> Bool {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        
        // Validate amount as Int8 (per current DatabaseManager signature)
        let amtDouble = Double(amount)
        do {
            try await DatabaseManager.shared.uploadTransaction(
                post_id: postId,
                donor_id: userId,
                name: donorNameInput.isEmpty ? nil : donorNameInput,
                transaction_number: transactionRef.isEmpty ? nil : transactionRef,
                amount: amtDouble!,
                timestamp: date
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
    @State private var showConfirm = false
    @State private var showResult = false
    @State private var resultMessage = ""
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: Image? = nil
    
    var body: some View {
        ScrollView {
            VStack {
                // Summary
                HStack(alignment: .top, spacing: 16) {
                    Rectangle()
                        .foregroundColor(.green)
                        .frame(width: 120, height: 80)
                        .cornerRadius(8)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Rectangle()
                                .foregroundColor(.green)
                                .frame(width: 36, height: 36)
                                .cornerRadius(999)
                            Text(vm.post?.accounts?.name_display ?? "<Donee>")
                                .font(.caption)
                        }
                        Text(vm.post?.title ?? "<Title>")
                            .font(.headline)
                    }
                    Spacer()
                }
                .padding()
                
                // Bank info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("เลขที่บัญชี: \(vm.accountNumber)")
                        Spacer()
                        Button("Copy") {
                            UIPasteboard.general.string = vm.accountNumber
                        }
                    }
                    Text("ธนาคาร: \(vm.bankName)")
                }
                .padding(.horizontal)
                
                // Form
                Form {
                    Section(header: Text("อัพโหลดสลิป")) {
                        if let image = selectedImage {
                            image
                                .resizable()
                                .scaledToFit()
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
                                    if let data = try? await selectedItem?.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        selectedImage = Image(uiImage: uiImage)
                                    }
                                }
                                
                            }
                        
                    }
                    
                    Section(header: Text("ข้อมูลการโอน")) {
                        TextField("ชื่อผู้โอน", text: $vm.donorNameInput)
                        TextField("เลขที่รายการ", text: $vm.transactionRef)
                        TextField("จำนวนเงิน", text: $vm.amount)
                            .keyboardType(.decimalPad)
                        DatePicker("วันเวลาโอน", selection: $vm.date, displayedComponents: [.date, .hourAndMinute])
                    }
                    .disabled(true)
                    Section(header: Text("คำอวยพร")) {
                        TextField("เขียนคำอวยพร", text: $vm.comment, axis: .vertical)
                            .lineLimit(5...5)
                    }
                }
                .scrollDisabled(true)
                .frame(height: 900)
                
                Button {
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
                        let donorId = authVM.session?.user.id
                        let ok = await vm.uploadTransaction(userId: donorId?.uuidString, postId: String(postId))
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
