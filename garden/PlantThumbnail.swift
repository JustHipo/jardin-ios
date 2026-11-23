import SwiftUI

/// The plant's real photo when it has one, a leaf placeholder otherwise — same fallback the
/// app itself uses (`DSPlantThumb`), just without a dependency on the app's design system.
struct PlantThumbnail: View {
    let plant: WidgetPlantInfo
    let size: CGFloat

    var body: some View {
        Group {
            if let data = plant.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else {
                Color.gardenBrand.opacity(0.15)
                    .overlay(
                        Image(systemName: "leaf.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundStyle(Color.gardenBrand)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.27))
    }
}
