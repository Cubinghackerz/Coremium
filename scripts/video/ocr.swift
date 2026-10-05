#!/usr/bin/env swift

import AppKit
import Foundation
import Vision

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: ocr.swift image.png\n".utf8))
    exit(64)
}

let path = CommandLine.arguments[1]
guard let image = NSImage(contentsOfFile: path) else {
    FileHandle.standardError.write(Data("Could not read image: \(path)\n".utf8))
    exit(66)
}

var proposedRect = NSRect(origin: .zero, size: image.size)
guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
    FileHandle.standardError.write(Data("Could not decode image: \(path)\n".utf8))
    exit(65)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = false

let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
do {
    try handler.perform([request])
} catch {
    FileHandle.standardError.write(Data("OCR failed: \(error)\n".utf8))
    exit(70)
}

let width = Double(cgImage.width)
let height = Double(cgImage.height)
for observation in (request.results ?? []).compactMap({ $0 as? VNRecognizedTextObservation }) {
    guard let candidate = observation.topCandidates(1).first else { continue }
    let box = observation.boundingBox
    let centerX = (box.origin.x + box.size.width / 2.0) * width
    let centerY = (1.0 - box.origin.y - box.size.height / 2.0) * height
    print(String(format: "%.0f\t%.0f\t%@", centerX, centerY, candidate.string))
}
