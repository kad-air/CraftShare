import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentTab = 0
    
    var body: some View {
        ZStack {
            MeshGradientBackground()
                .ignoresSafeArea()
            
            VStack {
                TabView(selection: $currentTab) {
                    // Step 1: Welcome
                    OnboardingStep(
                        image: "sparkles",
                        title: "Welcome to CraftShare",
                        description: "Your AI-powered clipper for Craft Docs. Instantly save web pages as structured data."
                    )
                    .tag(0)
                    
                    // Step 2: Craft Setup
                    OnboardingStep(
                        image: "key.fill",
                        title: "Connect Craft",
                        description: "You'll need a Developer Token and Space ID from the Craft Developer Portal.",
                        linkTitle: "Get Craft Credentials",
                        linkUrl: "https://developer.craft.do/portal"
                    )
                    .tag(1)
                    
                    // Step 3: Gemini Setup
                    OnboardingStep(
                        image: "brain.head.profile",
                        title: "Power with Gemini",
                        description: "Get a free API Key from Google AI Studio to enable the magic.",
                        linkTitle: "Get Gemini Key",
                        linkUrl: "https://aistudio.google.com/app/apikey"
                    )
                    .tag(2)
                    
                    // Step 4: Ready
                    OnboardingStep(
                        image: "square.and.arrow.up",
                        title: "Ready to Share",
                        description: "Once configured, just tap the Share button in Safari to clip anything!",
                        isLastStep: true,
                        onComplete: {
                            withAnimation {
                                isOnboardingComplete = true
                            }
                        }
                    )
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
        }
    }
}

struct OnboardingStep: View {
    let image: String
    let title: String
    let description: String
    var linkTitle: String? = nil
    var linkUrl: String? = nil
    var isLastStep: Bool = false
    var onComplete: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: image)
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding()
                .background(.ultraThinMaterial, in: Circle())
                .shadow(radius: 10)
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 30)
            }
            
            if let linkTitle = linkTitle, let linkUrl = linkUrl, let url = URL(string: linkUrl) {
                Link(destination: url) {
                    HStack {
                        Text(linkTitle)
                        Image(systemName: "arrow.up.right")
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            Spacer()
            
            if isLastStep {
                Button(action: { onComplete?() }) {
                    Text("Get Started")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(16)
                        .shadow(radius: 5)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            } else {
                // Placeholder to keep spacing consistent
                Color.clear.frame(height: 60).padding(.bottom, 50)
            }
        }
    }
}
