// Pulls still frames out of a video as PNGs (sim-shots.sh uses it for the harvest, which is over
// before a simulator screenshot would be).
// Usage: xcrun swift video-frames.swift <video> <output folder> <name=seconds>...
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
let generator = AVAssetImageGenerator(asset: AVURLAsset(url: URL(fileURLWithPath: arguments[1])))
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
generator.appliesPreferredTrackTransform = true

for wanted in arguments.dropFirst(3) {
    let parts = wanted.split(separator: "=")
    guard parts.count == 2, let seconds = Double(parts[1]) else {
        print("skipped \(wanted)")
        continue
    }
    do {
        let image = try generator.copyCGImage(at: CMTime(seconds: seconds, preferredTimescale: 600), actualTime: nil)
        let url = URL(fileURLWithPath: arguments[2]).appendingPathComponent("\(parts[0]).png")
        guard let file = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { continue }
        CGImageDestinationAddImage(file, image, nil)
        print(CGImageDestinationFinalize(file) ? "frame \(parts[0]) at \(seconds)s" : "could not write \(parts[0])")
    } catch {
        print("no frame for \(wanted): \(error.localizedDescription)")
    }
}
