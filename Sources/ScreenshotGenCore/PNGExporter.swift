import SwiftUI
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

@MainActor
public func exportPNG(view: some View, spec: DeviceSpec, to url: URL) throws {
    let renderer = ImageRenderer(content: view.frame(
        width: spec.canvasWidth,
        height: spec.canvasHeight
    ))
    renderer.scale = spec.renderScale

    guard let cgImage = renderer.cgImage else {
        throw ExportError.renderFailed
    }

    let width = cgImage.width
    let height = cgImage.height

    guard width == spec.pixelWidth, height == spec.pixelHeight else {
        throw ExportError.unexpectedSize(
            expected: "\(spec.pixelWidth)x\(spec.pixelHeight)",
            got: "\(width)x\(height)"
        )
    }

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
              data: nil,
              width: width,
              height: height,
              bitsPerComponent: 8,
              bytesPerRow: width * 4,
              space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          ) else {
        throw ExportError.contextCreationFailed
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let opaqueImage = context.makeImage() else {
        throw ExportError.flattenFailed
    }

    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw ExportError.fileCreationFailed
    }

    CGImageDestinationAddImage(destination, opaqueImage, nil)

    guard CGImageDestinationFinalize(destination) else {
        throw ExportError.writeFailed
    }
}

public enum ExportError: LocalizedError {
    case renderFailed
    case unexpectedSize(expected: String, got: String)
    case contextCreationFailed
    case flattenFailed
    case fileCreationFailed
    case writeFailed

    public var errorDescription: String? {
        switch self {
        case .renderFailed:
            "ImageRenderer failed to produce a CGImage"
        case .unexpectedSize(let expected, let got):
            "Expected \(expected) but got \(got)"
        case .contextCreationFailed:
            "Failed to create CGContext for sRGB flattening"
        case .flattenFailed:
            "Failed to create opaque image from context"
        case .fileCreationFailed:
            "Failed to create PNG file destination"
        case .writeFailed:
            "Failed to write PNG data to file"
        }
    }
}
