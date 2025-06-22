import SwiftUI

struct CoverImageView: View {
    let resource: DualResource?
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError = false
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if loadError {
                Color.gray.opacity(0.2)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            } else {
                Color.gray.opacity(0.2)
            }
            
            if isLoading {
                ProgressView()
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let resource = resource, let url = URL(string: resource.coverImageUrl) else {
            isLoading = false
            loadError = true
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("加载封面图片失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadError = true
                }
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = image
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadError = true
                }
            }
        }.resume()
    }
} 
