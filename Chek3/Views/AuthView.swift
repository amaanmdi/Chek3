//
//  AuthView.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import SwiftUI

struct AuthView: View {
    @StateObject private var authService = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isSignUp = false
    @State private var showEmailError = false
    @State private var validationTimer: Timer?
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isSignUp ? "Sign Up" : "Sign In")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .onChange(of: email) { _, newValue in
                            debounceEmailValidation()
                            clearErrors()
                        }
                    
                    if showEmailError && !email.isEmpty {
                        Text("Please enter a valid email address")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Name fields - only show during sign up
                if isSignUp {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("First Name", text: $firstName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: firstName) { _, newValue in
                                    clearErrors()
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Last Name", text: $lastName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: lastName) { _, newValue in
                                    clearErrors()
                                }
                        }
                    }
                }
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: password) { _, newValue in
                        clearErrors()
                    }
                
                Button(action: {
                    #if DEBUG
                    print("🎯 AuthView: Auth button tapped - Mode: \(isSignUp ? "Sign Up" : "Sign In")")
                    #endif
                    Task {
                        if isSignUp {
                            #if DEBUG
                            print("📝 AuthView: Calling signUp function")
                            #endif
                            await authService.signUp(email: email, password: password, firstName: firstName, lastName: lastName)
                        } else {
                            #if DEBUG
                            print("🔑 AuthView: Calling signIn function")
                            #endif
                            await authService.signIn(email: email, password: password)
                        }
                    }
                }) {
                    HStack {
                        if authService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isSignUp ? "Sign Up" : "Sign In")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(authService.isLoading || email.isEmpty || password.isEmpty)
                
                // Email verification message for sign-ups
                if isSignUp && authService.errorMessage?.contains("check your email") == true {
                    VStack(spacing: 8) {
                        Text(authService.errorMessage ?? "")
                            .foregroundColor(.orange)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                        
                        Button("Resend Verification Email") {
                            Task {
                                await authService.resendEmailVerification()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                }
                
                Button(action: {
                    #if DEBUG
                    print("🔄 AuthView: Switching auth mode from \(isSignUp ? "Sign Up" : "Sign In") to \(isSignUp ? "Sign In" : "Sign Up")")
                    #endif
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isSignUp.toggle()
                        clearErrors()
                        // Clear name fields when switching modes
                        if !isSignUp {
                            firstName = ""
                            lastName = ""
                        }
                    }
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            
            // Only show error message if it's not the email verification message
            if let errorMessage = authService.errorMessage, 
               !errorMessage.contains("check your email") {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            #if DEBUG
            print("👀 AuthView: View appeared")
            #endif
        }
    }
    
    // MARK: - Helper Functions
    private func debounceEmailValidation() {
        validationTimer?.invalidate()
        validationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            showEmailError = !email.isEmpty && !ValidationUtils.isValidEmail(email)
        }
    }
    
    private func clearErrors() {
        if !authService.errorMessage.isNilOrEmpty {
            authService.errorMessage = nil
        }
        showEmailError = false
    }
}

#Preview {
    AuthView()
}
