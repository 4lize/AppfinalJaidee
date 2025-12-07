//
//  LoginView.swift
//  Jaidee
//
//  Created by Teerapat Kuanphuek on 2/12/2568 BE.
//

import SwiftUI
import Combine

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack(alignment: .topLeading) {

                    // 🔵 พื้นหลังบนสุด
                    Color(red: 0.11, green: 0.30, blue: 0.54)
                        .edgesIgnoringSafeArea(.all)

                    VStack(alignment: .leading, spacing: 0) {
                        // ------ Title ด้านบน ------ //
                        Text("Sign in")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, 40)
                            .padding(.leading, 20)

                        Spacer().frame(height: 30)

                        // ------ การ์ดสีขาวด้านล่าง ------ //
                        VStack(spacing: 30) {

                            Text("Welcome to Jaidee")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(red: 0.11, green: 0.30, blue: 0.54))

                            Rectangle()
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 220, height: 1)

                            Text("Hello there, sign in to continue")
                                .font(.system(size: 16))
                                .foregroundColor(.black.opacity(0.8))

                            // ------ Email ------ //
                            TextField("Email", text: $email)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                                )
                                .frame(height: 55)

                            // ------ Password ------ //
                            SecureField("Password", text: $password)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                                )
                                .frame(height: 55)

                            // ------ Sign in Button ------ //
                            Button(action: {
                                Task {
                                    do {
                                        try await authViewModel.signIn(email: email, password: password)
                                    } catch {
                                        print("Sign in failed: \(error)")
                                    }
                                }
                            }) {
                                Text("Sign in")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 55)
                                    .background(Color(red: 0.11, green: 0.30, blue: 0.54))
                                    .cornerRadius(18)
                            }
                            .padding(.bottom, 20)

                            // ------ Sign up Button ------ //
                            Button(action: {
                                Task {
                                    do {
                                        try await authViewModel.signUp(email: email, password: password)
                                    } catch {
                                        print("Sign up failed: \(error)")
                                    }
                                }
                            }) {
                                Text("Sign up")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 55)
                                    .background(Color(red: 0.37, green: 0.52, blue: 0.67))
                                    .cornerRadius(18)
                            }
                            .padding(.bottom, 20)

                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 40)
                        .padding(.bottom, 220)
                        .background(
                            RoundedRectangle(cornerRadius: 40)
                                .fill(Color.white)
                                .edgesIgnoringSafeArea(.bottom)
                        )
                    }
                }
        /*
        VStack(spacing: 12) {
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            /*
            Button {
                Task {
                    do {
                        try await authViewModel.signIn(email: email, password: password)
                    } catch {
                        print("Sign in failed: \(error)")
                    }
                }
            } label: {
                Text("Sign In")
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .cornerRadius(20)
            }

            Button {
                Task {
                    do {
                        try await authViewModel.signUp(email: email, password: password)
                    } catch {
                        print("Sign up failed: \(error)")
                    }
                }
            } label: {
                Text("Sign Up")
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.orange, lineWidth: 3)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
             */
        }
        .padding()*/
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}

