import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @ObservedObject var credentials: CredentialsManager
    @State private var currentTab = 0
    @State private var showCraftToken = false
    @State private var showGeminiKey = false

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
                        description: "Get a Developer Token and Space ID from the Craft Developer Portal, then enter them below.",
                        linkTitle: "Get Craft Credentials",
                        linkUrl: "https://developer.craft.do/portal"
                    ) {
                        VStack(spacing: 12) {
                            HStack {
                                Group {
                                    if showCraftToken {
                                        TextField("Developer Token", text: $credentials.craftToken)
                                    } else {
                                        SecureField("Developer Token", text: $credentials.craftToken)
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
                            .padding(12)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(10)

                            TextField("Space ID", text: $credentials.spaceId)
                                .textFieldStyle(.plain)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 40)
                    }
                    .tag(1)

                    // Step 3: Gemini Setup
                    OnboardingStep(
                        image: "brain.head.profile",
                        title: "Power with Gemini",
                        description: "Get a free API Key from Google AI Studio to enable the magic.",
                        linkTitle: "Get Gemini Key",
                        linkUrl: "https://aistudio.google.com/app/apikey"
                    ) {
                        HStack {
                            Group {
                                if showGeminiKey {
                                    TextField("Gemini API Key", text: $credentials.geminiKey)
                                } else {
                                    SecureField("Gemini API Key", text: $credentials.geminiKey)
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
                        .padding(12)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(10)
                        .padding(.horizontal, 40)
                    }
                    .tag(2)

                    // Step 4: Ready
                    OnboardingStep(
                        image: "square.and.arrow.up",
                        title: "Ready to Share",
                        description: credentials.isValid
                            ? "You're all set! Tap Get Started, then use the Share button in Safari to clip anything."
                            : "Go back and fill in your credentials to continue.",
                        isLastStep: true,
                        isComplete: credentials.isValid,
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

struct OnboardingStep<Content: View>: View {
    let image: String
    let title: String
    let description: String
    var linkTitle: String? = nil
    var linkUrl: String? = nil
    var isLastStep: Bool = false
    var isComplete: Bool = true
    var onComplete: (() -> Void)? = nil
    let content: Content

    init(
        image: String,
        title: String,
        description: String,
        linkTitle: String? = nil,
        linkUrl: String? = nil,
        isLastStep: Bool = false,
        isComplete: Bool = true,
        onComplete: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) {
        self.image = image
        self.title = title
        self.description = description
        self.linkTitle = linkTitle
        self.linkUrl = linkUrl
        self.isLastStep = isLastStep
        self.isComplete = isComplete
        self.onComplete = onComplete
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: image)
                .font(.system(size: 80))
                .foregroundStyle(.tint)
                .padding()
                .glassEffect(.regular, in: .circle)

            VStack(spacing: 12) {
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
                    .fontWeight(.semibold)
                }
            }

            content

            Spacer()

            if isLastStep {
                Button(action: { onComplete?() }) {
                    Text("Get Started")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
                .disabled(!isComplete)
                .opacity(isComplete ? 1.0 : 0.5)
            } else {
                Color.clear.frame(height: 60).padding(.bottom, 50)
            }
        }
    }
}
