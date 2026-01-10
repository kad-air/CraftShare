import SwiftUI

struct ShareView: View {
    let url: URL
    let credentials: CredentialsManager
    var onDismiss: () -> Void

    @StateObject private var viewModel: ShareViewModel

    init(url: URL, credentials: CredentialsManager, onDismiss: @escaping () -> Void) {
        self.url = url
        self.credentials = credentials
        self.onDismiss = onDismiss
        _viewModel = StateObject(wrappedValue: ShareViewModel(url: url, credentials: credentials))
    }

    var body: some View {
        ZStack {
            // 1. Liquid Background
            MeshGradientBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if let error = viewModel.errorMessage {
                    GlassCard {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            Text("Error: \(error)")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                            Button("Close", action: onDismiss)
                                .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                } else if viewModel.isEditing {
                    // Show the Editor
                    EditItemView(
                        schema: viewModel.currentSchema,
                        contentKey: viewModel.currentContentKey,
                        contentName: viewModel.currentContentName,
                        itemData: $viewModel.draftItem,
                        onSave: { viewModel.saveFinalItem(onDismiss: onDismiss) },
                        onCancel: { viewModel.cancelEditing() }
                    )
                    .transition(.move(edge: .trailing))
                } else if viewModel.isLoading || viewModel.selectedCollection != nil {
                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(viewModel.status)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Modern Collection List
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Save to Craft")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .padding(.horizontal)
                                .padding(.top, 20)

                            Text("Select a collection to store this link.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            ForEach(viewModel.collections) { collection in
                                Button(action: {
                                    viewModel.startProcessing(collection: collection)
                                }) {
                                    GlassCard {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(collection.name)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                Text("\(collection.itemCount) items")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .animation(.spring(), value: viewModel.isEditing)
        .animation(.spring(), value: viewModel.selectedCollection != nil)
        .overlay(
            Group {
                if !viewModel.isEditing {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding()
                }
            },
            alignment: .topTrailing
        )
        .onAppear {
            viewModel.fetchCollections()
        }
        .onDisappear {
            viewModel.cancelAll()
        }
    }
}

