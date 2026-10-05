#!/usr/bin/env swift

import ApplicationServices
import CoreGraphics
import Foundation

private let travelDuration = 0.6
private let hoverDwell = 0.5
private let framesPerSecond = 120.0

private func fail(_ message: String, code: Int32 = 64) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

private func easeInOutCubic(_ value: Double) -> Double {
    value < 0.5
        ? 4.0 * value * value * value
        : 1.0 - pow(-2.0 * value + 2.0, 3.0) / 2.0
}

private func mouseLocation() -> CGPoint {
    CGEvent(source: nil)?.location ?? .zero
}

private func postMouseMove(to point: CGPoint) {
    guard let event = CGEvent(
        mouseEventSource: nil,
        mouseType: .mouseMoved,
        mouseCursorPosition: point,
        mouseButton: .left
    ) else {
        fail("Could not create a mouse-move event.")
    }
    event.post(tap: .cghidEventTap)
}

private func moveSmoothly(to destination: CGPoint) {
    let origin = mouseLocation()
    let frameCount = max(1, Int(travelDuration * framesPerSecond))

    for frame in 1...frameCount {
        let progress = Double(frame) / Double(frameCount)
        let eased = easeInOutCubic(progress)
        let point = CGPoint(
            x: origin.x + (destination.x - origin.x) * eased,
            y: origin.y + (destination.y - origin.y) * eased
        )
        postMouseMove(to: point)
        Thread.sleep(forTimeInterval: travelDuration / Double(frameCount))
    }
}

private func click(at point: CGPoint) {
    guard
        let down = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        ),
        let up = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        )
    else {
        fail("Could not create mouse-click events.")
    }

    down.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.08)
    up.post(tap: .cghidEventTap)
}

private func scrollSlowly(at point: CGPoint, by totalDelta: Int32) {
    moveSmoothly(to: point)

    let frameCount: Int32 = 90
    var delivered: Int32 = 0
    for frame in 1...frameCount {
        let targetDelivered = Int32(
            (Double(totalDelta) * Double(frame) / Double(frameCount)).rounded()
        )
        let frameDelta = targetDelivered - delivered
        delivered = targetDelivered

        if frameDelta != 0,
            let event = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 1,
                wheel1: frameDelta,
                wheel2: 0,
                wheel3: 0
            )
        {
            event.post(tap: .cghidEventTap)
        }
        Thread.sleep(forTimeInterval: 2.0 / Double(frameCount))
    }
}

private func activeDisplays() -> [CGDirectDisplayID] {
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(0, nil, &count) == .success else {
        fail("Could not enumerate displays.")
    }

    var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
    guard CGGetActiveDisplayList(count, &displays, &count) == .success else {
        fail("Could not read display geometry.")
    }
    return Array(displays.prefix(Int(count)))
}

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments == ["--preflight"] {
    let trusted = AXIsProcessTrusted()
    print(trusted ? "ACCESSIBILITY_OK" : "ACCESSIBILITY_REQUIRED")
    exit(trusted ? 0 : 77)
}

if arguments == ["--request-accessibility"] {
    let options = [
        kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
    ] as CFDictionary
    let trusted = AXIsProcessTrustedWithOptions(options)
    print(trusted ? "ACCESSIBILITY_OK" : "ACCESSIBILITY_PROMPTED")
    exit(trusted ? 0 : 77)
}

guard AXIsProcessTrusted() else {
    fail(
        "ACCESSIBILITY_REQUIRED: enable your terminal/agent host in System Settings > Privacy & Security > Accessibility, then rerun.",
        code: 77
    )
}

var actionArguments = arguments
var displayIndex = 1

if actionArguments.first == "--display" {
    guard actionArguments.count >= 2, let parsedIndex = Int(actionArguments[1]) else {
        fail("--display requires a 1-based display index.")
    }
    displayIndex = parsedIndex
    actionArguments.removeFirst(2)
}

let displays = activeDisplays()
guard displays.indices.contains(displayIndex - 1) else {
    fail("Display index \(displayIndex) is unavailable; found \(displays.count) active display(s).")
}

let targetDisplayBounds = CGDisplayBounds(displays[displayIndex - 1])
let notchPoint = CGPoint(x: targetDisplayBounds.midX, y: targetDisplayBounds.minY + 2.0)

if actionArguments == ["--hover-only"] {
    moveSmoothly(to: notchPoint)
    Thread.sleep(forTimeInterval: hoverDwell)
    print(
        "Hovered the notch at (\(Int(notchPoint.x)), \(Int(notchPoint.y))) "
            + "on display \(displayIndex)."
    )
    exit(0)
}

if actionArguments.first == "--scroll" {
    guard
        actionArguments.count == 4,
        let x = Double(actionArguments[1]),
        let y = Double(actionArguments[2]),
        let delta = Int32(actionArguments[3])
    else {
        fail("--scroll requires x y delta.")
    }

    let scrollPoint = CGPoint(x: x, y: y)
    guard targetDisplayBounds.contains(scrollPoint) else {
        fail(
            "Scroll point (\(Int(scrollPoint.x)), \(Int(scrollPoint.y))) is outside display \(displayIndex) bounds \(targetDisplayBounds)."
        )
    }

    moveSmoothly(to: notchPoint)
    Thread.sleep(forTimeInterval: hoverDwell)
    scrollSlowly(at: scrollPoint, by: delta)
    print(
        "Scrolled by \(delta) at (\(Int(scrollPoint.x)), \(Int(scrollPoint.y))) "
            + "on display \(displayIndex)."
    )
    exit(0)
}

let destination: CGPoint
switch actionArguments.count {
case 0:
    destination = notchPoint
case 2:
    guard let x = Double(actionArguments[0]), let y = Double(actionArguments[1]) else {
        fail("Usage: mouse.swift [--display n] [x y | --hover-only | --scroll x y delta] | --preflight | --request-accessibility")
    }
    destination = CGPoint(x: x, y: y)
default:
    fail("Usage: mouse.swift [--display n] [x y | --hover-only | --scroll x y delta] | --preflight | --request-accessibility")
}

guard targetDisplayBounds.contains(destination) else {
    fail(
        "Destination (\(Int(destination.x)), \(Int(destination.y))) is outside display \(displayIndex) bounds \(targetDisplayBounds)."
    )
}

moveSmoothly(to: notchPoint)
Thread.sleep(forTimeInterval: hoverDwell)
moveSmoothly(to: destination)
click(at: destination)

print(
    "Clicked (\(Int(destination.x)), \(Int(destination.y))) after hovering the notch at "
        + "(\(Int(notchPoint.x)), \(Int(notchPoint.y))) on display \(displayIndex)."
)
