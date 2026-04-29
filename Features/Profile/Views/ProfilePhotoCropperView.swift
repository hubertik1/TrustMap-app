import ImageIO
import SwiftUI
import UIKit

struct ProfilePhotoCropperView: View {
    let image: UIImage
    var isPreparingPhoto = false
    let errorMessage: String?
    let onCancel: () -> Void
    let onUsePhoto: (UIImage) -> Void
    let onCropError: () -> Void
    let onDismissError: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var cropFrameSize: CGFloat = 1

    private let maxScale: CGFloat = 5
    private let outputMaxPixelSize: CGFloat = 1_024

    var body: some View {
        GeometryReader { proxy in
            let safeAreaInsets = resolvedSafeAreaInsets(from: proxy.safeAreaInsets)
            let topInset = max(safeAreaInsets.top, 16)
            let bottomInset = max(safeAreaInsets.bottom, 12)
            let toolbarHeight: CGFloat = 54
            let helperHeight: CGFloat = 44
            let stageTopReserve = topInset + toolbarHeight + 12
            let stageBottomReserve = bottomInset + helperHeight + 12
            let stageSize = CGSize(
                width: max(proxy.size.width - 40, 1),
                height: max(proxy.size.height - stageTopReserve - stageBottomReserve, 1)
            )
            let resolvedCropFrameSize = resolvedCropFrameSize(for: stageSize)

            ZStack {
                Color.black
                    .ignoresSafeArea()

                cropStage(
                    stageSize: stageSize,
                    cropFrameSize: resolvedCropFrameSize
                )
                .frame(width: stageSize.width, height: stageSize.height)
                .position(
                    x: proxy.size.width / 2,
                    y: stageTopReserve + stageSize.height / 2
                )
                .onAppear {
                    updateCropFrameSize(resolvedCropFrameSize)
                }
                .onChange(of: resolvedCropFrameSize) { _, newValue in
                    updateCropFrameSize(newValue)
                }

                VStack(spacing: 0) {
                    toolbar
                        .padding(.horizontal, 20)
                        .frame(height: toolbarHeight)
                        .padding(.top, topInset)
                        .background(Color.black.opacity(0.92).ignoresSafeArea(edges: .top))

                    Spacer(minLength: 0)

                    helperText
                        .padding(.horizontal, 20)
                        .frame(minHeight: helperHeight)
                        .padding(.bottom, bottomInset)
                        .background(Color.black.opacity(0.92).ignoresSafeArea(edges: .bottom))
                }
            }
        }
        .alert(
            "Unable to Use Photo",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { onDismissError() } }
            )
        ) {
            Button("OK", role: .cancel) {
                onDismissError()
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var helperText: some View {
        Text("Drag to reposition. Pinch to zoom.")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.78))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var toolbar: some View {
        ZStack {
            Text("Adjust Photo")
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 96)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .disabled(isPreparingPhoto)
                .accessibilityLabel("Cancel")

                Spacer(minLength: 8)

                Button {
                    usePhoto()
                } label: {
                    Group {
                        if isPreparingPhoto {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Text("Use Photo")
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .frame(minWidth: 74, alignment: .trailing)
                }
                .disabled(isPreparingPhoto)
                .accessibilityLabel("Use Photo")
            }
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(.white)
        .frame(minHeight: 44)
    }

    private func resolvedSafeAreaInsets(from geometryInsets: EdgeInsets) -> EdgeInsets {
        let windowInsets = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets ?? .zero

        return EdgeInsets(
            top: max(geometryInsets.top, windowInsets.top),
            leading: max(geometryInsets.leading, windowInsets.left),
            bottom: max(geometryInsets.bottom, windowInsets.bottom),
            trailing: max(geometryInsets.trailing, windowInsets.right)
        )
    }

    private func cropStage(stageSize: CGSize, cropFrameSize: CGFloat) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .frame(
                    width: renderedImageSize(for: cropFrameSize, scale: scale).width,
                    height: renderedImageSize(for: cropFrameSize, scale: scale).height
                )
                .offset(offset)

            SquareCropDimOverlay(cropFrameSize: cropFrameSize)
                .fill(Color.black.opacity(0.56), style: FillStyle(eoFill: true))

            SquareCropGrid()
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                .frame(width: cropFrameSize, height: cropFrameSize)

            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: cropFrameSize, height: cropFrameSize)
        }
        .frame(width: stageSize.width, height: stageSize.height)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Photo crop area")
        .clipped()
        .simultaneousGesture(dragGesture(cropFrameSize: cropFrameSize))
        .simultaneousGesture(magnifyGesture(cropFrameSize: cropFrameSize))
        .disabled(isPreparingPhoto)
    }

    private func dragGesture(cropFrameSize: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposedOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clampedOffset(proposedOffset, cropFrameSize: cropFrameSize, scale: scale)
            }
            .onEnded { _ in
                offset = clampedOffset(offset, cropFrameSize: cropFrameSize, scale: scale)
                lastOffset = offset
            }
    }

    private func magnifyGesture(cropFrameSize: CGFloat) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(lastScale * value.magnification, 1), maxScale)
                offset = clampedOffset(offset, cropFrameSize: cropFrameSize, scale: scale)
            }
            .onEnded { _ in
                scale = min(max(scale, 1), maxScale)
                lastScale = scale
                offset = clampedOffset(offset, cropFrameSize: cropFrameSize, scale: scale)
                lastOffset = offset
            }
    }

    private func usePhoto() {
        guard let croppedImage = croppedImage() else {
            onCropError()
            return
        }

        onUsePhoto(croppedImage)
    }

    private func updateCropFrameSize(_ newValue: CGFloat) {
        guard newValue > 0 else {
            return
        }

        cropFrameSize = newValue
        scale = min(max(scale, 1), maxScale)
        lastScale = min(max(lastScale, 1), maxScale)
        offset = clampedOffset(offset, cropFrameSize: newValue, scale: scale)
        lastOffset = clampedOffset(lastOffset, cropFrameSize: newValue, scale: scale)
    }

    private func resolvedCropFrameSize(for stageSize: CGSize) -> CGFloat {
        let availableWidth = max(stageSize.width, 1)
        let availableHeight = max(stageSize.height, 1)
        return max(1, min(availableWidth * 0.84, availableHeight * 0.86))
    }

    private func baseScale(for cropFrameSize: CGFloat) -> CGFloat {
        let imageSize = imagePixelSize
        guard imageSize.width > 0, imageSize.height > 0 else {
            return 1
        }

        return max(cropFrameSize / imageSize.width, cropFrameSize / imageSize.height)
    }

    private func renderedImageSize(for cropFrameSize: CGFloat, scale: CGFloat) -> CGSize {
        let imageSize = imagePixelSize
        let effectiveScale = baseScale(for: cropFrameSize) * scale
        return CGSize(
            width: imageSize.width * effectiveScale,
            height: imageSize.height * effectiveScale
        )
    }

    private func clampedOffset(_ proposedOffset: CGSize, cropFrameSize: CGFloat, scale: CGFloat) -> CGSize {
        let renderedImageSize = renderedImageSize(for: cropFrameSize, scale: scale)
        let horizontalLimit = max(0, (renderedImageSize.width - cropFrameSize) / 2)
        let verticalLimit = max(0, (renderedImageSize.height - cropFrameSize) / 2)

        return CGSize(
            width: min(max(proposedOffset.width, -horizontalLimit), horizontalLimit),
            height: min(max(proposedOffset.height, -verticalLimit), verticalLimit)
        )
    }

    private func croppedImage() -> UIImage? {
        let normalizedImage = image.normalizedForCropping()
        guard let cgImage = normalizedImage.cgImage else {
            return nil
        }

        let sourceSize = CGSize(width: cgImage.width, height: cgImage.height)
        let effectiveScale = baseScale(for: cropFrameSize) * scale
        guard effectiveScale > 0 else {
            return nil
        }

        let cropSide = min(cropFrameSize / effectiveScale, sourceSize.width, sourceSize.height)
        guard cropSide >= 1 else {
            return nil
        }

        let centerX = sourceSize.width / 2
        let centerY = sourceSize.height / 2
        let originX = centerX - (offset.width / effectiveScale) - (cropSide / 2)
        let originY = centerY - (offset.height / effectiveScale) - (cropSide / 2)
        let clampedOriginX = min(max(originX, 0), sourceSize.width - cropSide)
        let clampedOriginY = min(max(originY, 0), sourceSize.height - cropSide)
        let integralSide = max(1, min(Int(cropSide.rounded(.down)), cgImage.width, cgImage.height))
        let integralOriginX = min(max(0, Int(clampedOriginX.rounded(.down))), cgImage.width - integralSide)
        let integralOriginY = min(max(0, Int(clampedOriginY.rounded(.down))), cgImage.height - integralSide)
        let cropRect = CGRect(
            x: integralOriginX,
            y: integralOriginY,
            width: integralSide,
            height: integralSide
        )

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return nil
        }

        return UIImage(cgImage: croppedCGImage, scale: 1, orientation: .up)
            .resizedSquareForAvatarCrop(maxPixelSize: outputMaxPixelSize)
    }

    private var imagePixelSize: CGSize {
        if let cgImage = image.cgImage {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }

        return CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
    }
}

private struct SquareCropDimOverlay: Shape {
    let cropFrameSize: CGFloat

    func path(in rect: CGRect) -> Path {
        let cropRect = CGRect(
            x: rect.midX - cropFrameSize / 2,
            y: rect.midY - cropFrameSize / 2,
            width: cropFrameSize,
            height: cropFrameSize
        )

        var path = Path()
        path.addRect(rect)
        path.addRect(cropRect)
        return path
    }
}

private struct SquareCropGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let thirdWidth = rect.width / 3
        let thirdHeight = rect.height / 3

        path.move(to: CGPoint(x: rect.minX + thirdWidth, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + thirdWidth, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX + thirdWidth * 2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + thirdWidth * 2, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + thirdHeight))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + thirdHeight))
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + thirdHeight * 2))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + thirdHeight * 2))

        return path
    }
}

enum ProfilePhotoCropperImageLoader {
    private static let maxCropperPixelSize = 4_096

    static func image(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)?.normalizedForCropping(maxPixelSize: CGFloat(maxCropperPixelSize))
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: maxCropperPixelSize
        ]

        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        }

        return UIImage(data: data)?.normalizedForCropping(maxPixelSize: CGFloat(maxCropperPixelSize))
    }
}

extension UIImage {
    func normalizedForCropping(maxPixelSize: CGFloat? = nil) -> UIImage {
        let largestDimension = max(size.width, size.height)
        let scaleFactor: CGFloat

        if let maxPixelSize, largestDimension > maxPixelSize {
            scaleFactor = maxPixelSize / largestDimension
        } else {
            scaleFactor = 1
        }

        if imageOrientation == .up, scaleFactor == 1, scale == 1 {
            return self
        }

        let targetSize = CGSize(
            width: max(1, (size.width * scaleFactor).rounded()),
            height: max(1, (size.height * scaleFactor).rounded())
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    fileprivate func resizedSquareForAvatarCrop(maxPixelSize: CGFloat) -> UIImage {
        guard size.width > maxPixelSize || size.height > maxPixelSize else {
            return normalizedForCropping()
        }

        let targetSize = CGSize(width: maxPixelSize, height: maxPixelSize)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
