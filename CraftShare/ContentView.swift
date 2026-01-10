import SwiftUI
import UIKit
import Combine

struct ContentView: View {
    @StateObject private var credentials = CredentialsManager()
    @AppStorage("isOnboardingComplete") private var isOnboardingComplete = false
    @State private var showSavedMessage = false
    @State private var showOnboardingSheet = false
    @State private var showCraftToken = false
    @State private var showGeminiKey = false
    
    var body: some View {
        if !isOnboardingComplete {
            OnboardingView(isOnboardingComplete: $isOnboardingComplete)
        } else {
            ZStack {
                // 1. Liquid Background
                MeshGradientBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            // Header (More compact)
                            HStack(spacing: 15) {
                                Image(systemName: "square.and.arrow.up.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("CraftShare")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                    Text("AI-Powered Craft Clipper")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                
                                Button(action: { showOnboardingSheet = true }) {
                                    Image(systemName: "questionmark.circle")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                            .sheet(isPresented: $showOnboardingSheet) {
                                OnboardingView(isOnboardingComplete: Binding(
                                    get: { !showOnboardingSheet },
                                    set: { _ in showOnboardingSheet = false }
                                ))
                            }
                            
                            // 2. Craft Configuration Card
                            GlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("CRAFT API", systemImage: "key.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        Text("Token")
                                            .font(.caption)
                                            .frame(width: 50, alignment: .leading)
                                        HStack {
                                            Group {
                                                if showCraftToken {
                                                    TextField("sk_...", text: $credentials.craftToken)
                                                } else {
                                                    SecureField("sk_...", text: $credentials.craftToken)
                                                }
                                            }
                                            .textFieldStyle(.plain)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()

                                            Button(action: { showCraftToken.toggle() }) {
                                                Image(systemName: showCraftToken ? "eye.slash" : "eye")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(10)
                                        .background(Color.primary.opacity(0.05))
                                        .cornerRadius(10)
                                    }
                                    
                                    HStack {
                                        Text("Space")
                                            .font(.caption)
                                            .frame(width: 50, alignment: .leading)
                                        TextField("ID...", text: $credentials.spaceId)
                                            .textFieldStyle(.plain)
                                            .padding(10)
                                            .background(Color.primary.opacity(0.05))
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            
                            // 3. Gemini Configuration Card
                            GlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("GEMINI AI", systemImage: "sparkles")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        Text("API Key")
                                            .font(.caption)
                                            .frame(width: 50, alignment: .leading)
                                        HStack {
                                            Group {
                                                if showGeminiKey {
                                                    TextField("AIza...", text: $credentials.geminiKey)
                                                } else {
                                                    SecureField("AIza...", text: $credentials.geminiKey)
                                                }
                                            }
                                            .textFieldStyle(.plain)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()

                                            Button(action: { showGeminiKey.toggle() }) {
                                                Image(systemName: showGeminiKey ? "eye.slash" : "eye")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(10)
                                        .background(Color.primary.opacity(0.05))
                                        .cornerRadius(10)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Model Guidance")
                                            .font(.caption)
                                        TextEditor(text: $credentials.userGuidance)
                                            .frame(minHeight: 120, maxHeight: .infinity)
                                        // Workaround for background color in TextEditor
                                            .onAppear {
                                                UITextView.appearance().backgroundColor = .clear
                                            }
                                            .padding(4)
                                            .background(Color.primary.opacity(0.05))
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            .frame(maxHeight: .infinity)
                            
                            // 4. Status & Save
                            VStack(spacing: 16) {
                                if showSavedMessage {
                                    Text("Settings Saved!")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                                
                                Button(action: {
                                    // Trigger a save
                                    credentials.objectWillChange.send() 
                                    // Hide Keyboard
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    // Show confirmation
                                    withAnimation { showSavedMessage = true }
                                    // Hide after delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation { showSavedMessage = false }
                                    }
                                }) {
                                    Text("Save Settings")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(16)
                                        .shadow(radius: 5)
                                }
                                .padding(.horizontal)
                                
                                if credentials.isValid {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Ready to Share")
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 8)
                                }
                            }
                            
                            Spacer(minLength: 50)
                        }
                        .frame(maxWidth: 600) // Keep the UI centered and narrow on iPad
                        Spacer()
                    }
                    .padding()
                }
            }
        }
    }
}
