//
//  ProfileView.swift
//  Jaidee
//
//  Created by Teerapat Kuanphuek on 5/12/2568 BE.
//

import SwiftUI
import Combine
import Auth
import _PhotosUI_SwiftUI

class ProfileViewModel: ObservableObject {
    private let authViewModel: AuthViewModel
    var name_display: String
    var name_legal: String
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        self.name_display = authViewModel.Me?.name_display ?? ""
        self.name_legal = authViewModel.Me?.name_legal ?? ""
    }
    
    
    

}

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var vm: ProfileViewModel
    @State var resultMessage: String
    @State var showResult: Bool
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var pickedUIImage: UIImage? = nil
    
    
    init(authViewModel: AuthViewModel) {
        _vm = StateObject(wrappedValue: ProfileViewModel(authViewModel: authViewModel))
        self.resultMessage = ""
        self.showResult = false
    }
    
    var body: some View {
        VStack {
            HStack{
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images) {
                        //รูปที่แสดงอยู่(เป็นทั้งปุ่มทั้งรูป)
                        if let ui = pickedUIImage {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        } else {
                            FetchingPic.displayImage(
                                pic_url: authViewModel.Me?.profile_pic,
                                cornerRadius: 999,
                                width: 60,
                                height: 60
                                )
                            .overlay(
                                Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .onChange(of: selectedItem) { newValue in
                        Task {
                            do {
                                let uid = authViewModel.session?.user.id.uuidString
                                guard let data = try? await selectedItem?.loadTransferable(type: Data.self),
                                      let uiImage = UIImage(data: data) else { return }
                                
                                pickedUIImage = uiImage
                                
                                dump(data)
                                try await DatabaseManager.shared.updateProfile(id: uid!, imageData: data)
                                
                            } catch {
                                print(error)
                            }
                            try await Task.sleep(nanoseconds: 00_000_000_000)
                            authViewModel.Me?.profile_pic = nil
                            await authViewModel.getMeInfo()
                            
                        }
                    }
            
                
                VStack(alignment: .leading) {
                    Text(authViewModel.Me?.name_display ?? "Loading...")
                        .font(.body)
                    Text(authViewModel.Me?.name_legal ?? "Loading...")
                        .font(.subheadline)
                }
                Spacer()
            }
            .frame(width: 320)
            .padding(10)
            .background(Color(red: 0.73, green: 0.87, blue: 0.91))
            .cornerRadius(12)
            
            VStack(alignment: .leading) {
                Text("Display Name")
                    .font(.body)
                TextField(vm.name_display, text: $vm.name_display)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                Text("Legal Name")
                    .font(.body)
                TextField(vm.name_legal, text: $vm.name_legal)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                HStack {
                    Spacer()
                    Button {
                        Task {
                            do {
                                let uid = authViewModel.session?.user.id.uuidString
                                try await DatabaseManager.shared.updateMe(id: uid!, name_display: vm.name_display, name_legal: vm.name_legal)
                                self.resultMessage = "สำเร็จ"
                            } catch {
                                print("Sign up failed: \(error)")
                                self.resultMessage = "ล้มเหลว"
                            }
                            await authViewModel.getMeInfo()
                            showResult = true
                        }
                    } label: {
                        Text("แก้ไขข้อมูล")
                            .foregroundColor(.black)
                            .frame(width: 100)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.orange, lineWidth: 3)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .padding(10)
                    Spacer()
                }
            }
            .frame(width: 340)
            
            .alert(resultMessage, isPresented: $showResult) {
                Button("OK", role: .cancel) { }
            }
        }
    }
}

#Preview {
    let authVM = AuthViewModel()
    ProfileView(authViewModel: authVM)
        .environmentObject(authVM)
}
