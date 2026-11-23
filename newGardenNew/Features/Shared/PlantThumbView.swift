import SwiftUI

/// The plant's real photo when there is one, the design system's deterministic gradient
/// placeholder otherwise. Built with real photos as the primary path from the start — the
/// mockups use gradients only because there was no data yet, not as the intended final look
/// (see docs/ANALISIS_IMPLEMENTACION.md section 8, item 3).
struct PlantThumbView: View {
    let plant: Plant
    var size: CGFloat = 56
    var corner: CGFloat = DS.Radius.thumb

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: corner))
            } else {
                DSPlantThumb(name: plant.name, symbol: symbolForPlant, size: size, corner: corner)
            }
        }
        .task(id: plant.photoData) {
            guard let data = plant.photoData else { image = nil; return }
            image = await ThumbnailCache.shared.thumbnail(for: data, id: plant.id.uuidString, maxDimension: size)
        }
    }

    private var symbolForPlant: String {
        switch plant.functionalGroup {
        case .succulent: "drop.triangle.fill"
        case .tropicalIndoor: "leaf.fill"
        case .aromaticEdible: "fork.knife"
        case .outdoorShrub: "tree.fill"
        case .unknown, nil: "leaf.fill"
        }
    }
}
