import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var credentials = CredentialsManager()
    
    var body: some View {
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
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
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
                                    SecureField("sk_...", text: $credentials.craftToken)
                                        .textFieldStyle(.plain)
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
                                    SecureField("AIza...", text: $credentials.geminiKey)
                                        .textFieldStyle(.plain)
                                        .padding(10)
                                        .background(Color.primary.opacity(0.05))
                                        .cornerRadius(10)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Model Guidance")
                                        .font(.caption)
                                    TextEditor(text: $credentials.userGuidance)
                                        .frame(minHeight: 120, maxHeight: .infinity)
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
                                // Trigger a save (redundant but reassuring)
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
    
    @State private var showSavedMessage = false
}

// Reuse the visual components from the other view (duplicated here since they are in different modules/files)
// In a real app, you'd move these to a shared DesignSystem file.

struct GlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 10)
    }
}

struct MeshGradientBackground: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground) // Base
            
            GeometryReader { proxy in
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -50, y: -100)
                
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: proxy.size.width - 200, y: proxy.size.height / 3)
                
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 250, height: 250)
                    .blur(radius: 50)
                    .offset(x: 50, y: proxy.size.height - 200)
            }
        }
    }
}