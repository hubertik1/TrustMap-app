import SwiftUI

struct PhotoGridView: View {
    let assets: [PhotoAsset]
    let imageDataProvider: (PhotoAsset) -> Data?

    var body: some View {
        if !assets.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(assets, id: \.id) { asset in
                        if let data = imageDataProvider(asset), let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
