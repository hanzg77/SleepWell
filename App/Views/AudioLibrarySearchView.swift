import SwiftUI

// MARK: - Constants (re-declared for clarity, or could be moved to a shared file)
private enum SearchViewConstants {
    enum Colors {
        static let background = Color.black
        static let searchBarBackground = Color(white: 0.2)
        static let textPrimary = Color.white
        static let textSecondary = Color.gray
    }
    
    enum Layout {
        static let spacing: CGFloat = 16
        static let cornerRadius: CGFloat = 12
    }
}

struct AudioLibrarySearchView: View {
    @StateObject private var viewModel = AudioLibraryViewModel()
    @Binding var selectedTab: Int
    @FocusState private var isSearchFocused: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var showEpisodeList = false
    @State private var selectedResourceForList: DualResource?
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.bottom, 8)
                .background(SearchViewConstants.Colors.background)

            ZStack {
                SearchViewConstants.Colors.background.edgesIgnoringSafeArea(.bottom)

                if viewModel.isYouTubeLoading {
                    ProgressView().scaleEffect(1.5)
                } else if viewModel.isLoading {
                    ProgressView().scaleEffect(1.5)
                } else if let error = viewModel.error {
                    errorView(error)
                } else if !viewModel.youtubeResources.isEmpty {
                    youtubeResultsList
                } else if !viewModel.searchQuery.isEmpty && viewModel.resources.isEmpty {
                    emptyStateView
                } else if viewModel.searchQuery.isEmpty {
                    searchPromptView
                } else {
                    resultsList
                }
            }
        }
        .background(SearchViewConstants.Colors.background.edgesIgnoringSafeArea(.top))
        .navigationBarHidden(true)
        .onAppear {
            isSearchFocused = true
        }
        .sheet(isPresented: $showEpisodeList) {
            if let resource = selectedResourceForList {
                EpisodeListView(resource: resource, selectedTab: $selectedTab)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(SearchViewConstants.Colors.textPrimary)
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(SearchViewConstants.Colors.textSecondary)
                
                TextField("library.search.placeholder".localized, text: $viewModel.searchQuery)
                    .foregroundColor(SearchViewConstants.Colors.textPrimary)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        viewModel.loadResources()
                    }
                
                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.searchQuery = ""
                        viewModel.resources = [] // Clear results
                        viewModel.youtubeResources = [] // Clear YouTube results as well
                        viewModel.error = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(SearchViewConstants.Colors.textSecondary)
                    }
                }
            }
            .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            .background(SearchViewConstants.Colors.searchBarBackground)
            .cornerRadius(SearchViewConstants.Layout.cornerRadius)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(viewModel.resources) { resource in
                    ResourceCard(resource: resource, onTap: {
                        handleResourceTap(resource)
                    }, viewModel: nil) // Pass nil for viewModel to hide progress bar
                }
            }
            .padding()
        }
    }

    private var youtubeResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                Text("youtube.search.results.header".localized)
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 10)

                ForEach(viewModel.youtubeResources) { resource in
                    ResourceCard(resource: resource, onTap: {
                        handleResourceTap(resource)
                    }, viewModel: nil) // Pass nil for viewModel to hide progress bar
                }
            }
            .padding()
        }
    }

    private func handleResourceTap(_ resource: DualResource) {
        isSearchFocused = false // Dismiss keyboard
        if resource.resourceType == .singleTrackAlbum {
            PlaylistController.shared.setPlaylist([resource])
            PlaylistController.shared.play(resource)
            GuardianController.shared.enableGuardianMode(GuardianController.shared.currentMode)
            selectedTab = 1
            dismiss()
        } else {
            selectedResourceForList = resource
            showEpisodeList = true
        }
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(SearchViewConstants.Colors.textSecondary)
            Text("error.loadFailed.title".localized)
                .font(.headline)
                .foregroundColor(SearchViewConstants.Colors.textPrimary)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(SearchViewConstants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(action: {
                viewModel.loadResources()
            }) {
                Text("action.retry".localized)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(20)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(SearchViewConstants.Colors.textSecondary)
            Text("library.search.empty.title".localized)
                .font(.headline)
                .foregroundColor(SearchViewConstants.Colors.textSecondary)
            Text("library.search.empty.message".localized)
                .font(.subheadline)
                .foregroundColor(SearchViewConstants.Colors.textSecondary)
            
            // "Search on YouTube" Button
            Button(action: {
                Task {
                    await viewModel.searchOnYouTube()
                }
            }) {
                HStack {
                    Image(systemName: "play.tv")
                    Text("youtube.search.button".localized)
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.red)
                .cornerRadius(SearchViewConstants.Layout.cornerRadius)
            }
            .padding(.top, 20)
        }
        .padding(.horizontal)
    }

    private var searchPromptView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.mic")
                .font(.system(size: 60))
                .foregroundColor(SearchViewConstants.Colors.textSecondary)
            Text("library.search.prompt.title".localized)
                .font(.headline)
                .foregroundColor(SearchViewConstants.Colors.textSecondary)
        }
        .padding(.horizontal)
    }
}
