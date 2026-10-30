import AVFoundation
import AppKit
import CoreVideo
import Foundation

let framesDirectory = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let frameRate = Int32(CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "12") ?? 12
let fileManager = FileManager.default
let urls = try fileManager.contentsOfDirectory(at: URL(fileURLWithPath: framesDirectory), includingPropertiesForKeys: nil)
    .filter { $0.lastPathComponent.hasSuffix(".png") }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard !urls.isEmpty else { fatalError("No PNG frames in \(framesDirectory)") }

let outputURL = URL(fileURLWithPath: outputPath)
try? fileManager.removeItem(at: outputURL)
let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: 1600,
    AVVideoHeightKey: 900,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 4_000_000]
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
let pixelAttributes: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: 1600,
    kCVPixelBufferHeightKey as String: 900,
    kCVPixelBufferCGImageCompatibilityKey as String: true,
    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
]
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: pixelAttributes)
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

for (index, url) in urls.enumerated() {
    guard let image = NSImage(contentsOf: url),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let pool = adaptor.pixelBufferPool else { fatalError("Could not load frame \(url.lastPathComponent)") }
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
    var optionalBuffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &optionalBuffer)
    guard let buffer = optionalBuffer else { fatalError("Could not allocate video frame") }
    CVPixelBufferLockBaseAddress(buffer, [])
    let context = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer),
        width: 1600,
        height: 900,
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
    )!
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1600, height: 900))
    CVPixelBufferUnlockBaseAddress(buffer, [])
    let time = CMTime(value: Int64(index), timescale: frameRate)
    guard adaptor.append(buffer, withPresentationTime: time) else { fatalError(writer.error?.localizedDescription ?? "Video frame append failed") }
}

input.markAsFinished()
let finished = DispatchSemaphore(value: 0)
writer.finishWriting { finished.signal() }
finished.wait()
guard writer.status == .completed else { fatalError(writer.error?.localizedDescription ?? "Video encoding failed") }
print("Wrote \(urls.count) frames to \(outputPath) at \(frameRate) fps")
