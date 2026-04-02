import SwiftUI

/// Circular crop overlay — user can pan and zoom the image, then confirm.
struct ImageCropView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSize: CGFloat = 300

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Title
                Text("Move and Scale")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 20)

                Spacer()

                // Crop area
                GeometryReader { geo in
                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

                    ZStack {
                        // Movable/zoomable image
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cropSize * scale, height: cropSize * scale)
                            .offset(offset)
                            .gesture(dragGesture)
                            .gesture(magnificationGesture)

                        // Dark overlay with circular hole
                        CropMask(cropSize: cropSize, center: center, canvasSize: geo.size)
                            .fill(style: FillStyle(eoFill: true))
                            .foregroundStyle(.black.opacity(0.6))
                            .allowsHitTesting(false)

                        // Circle border
                        Circle()
                            .stroke(.white.opacity(0.5), lineWidth: 1)
                            .frame(width: cropSize, height: cropSize)
                            .position(center)
                            .allowsHitTesting(false)
                    }
                }

                Spacer()

                // Buttons
                HStack {
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.system(size: 17))
                    .foregroundStyle(.white)

                    Spacer()

                    Button("Choose") {
                        let cropped = performCrop()
                        onCrop(cropped)
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ColorTokens.gold)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = lastScale * value.magnification
                scale = max(1.0, min(newScale, 5.0))
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    // MARK: - Crop

    private func performCrop() -> UIImage {
        let imageSize = image.size
        let displaySize = cropSize * scale
        let scaleRatio = imageSize.width / displaySize

        let cropOriginX = ((displaySize / 2) - offset.width - (cropSize / 2)) * scaleRatio
        let cropOriginY = ((displaySize / 2) - offset.height - (cropSize / 2)) * scaleRatio
        let cropSizeScaled = cropSize * scaleRatio

        let cropRect = CGRect(
            x: max(0, cropOriginX),
            y: max(0, cropOriginY),
            width: min(cropSizeScaled, imageSize.width),
            height: min(cropSizeScaled, imageSize.height)
        )

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }

        let cropped = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)

        // Render as square
        let outputSize = CGSize(width: 500, height: 500)
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        return renderer.image { _ in
            cropped.draw(in: CGRect(origin: .zero, size: outputSize))
        }
    }
}

// MARK: - Crop Mask Shape

private struct CropMask: Shape {
    let cropSize: CGFloat
    let center: CGPoint
    let canvasSize: CGSize

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(CGRect(origin: .zero, size: canvasSize))
        path.addEllipse(in: CGRect(
            x: center.x - cropSize / 2,
            y: center.y - cropSize / 2,
            width: cropSize,
            height: cropSize
        ))
        return path
    }
}
