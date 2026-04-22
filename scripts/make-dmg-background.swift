#!/usr/bin/env swift
//
// DMG 배경 PNG 생성 스크립트.
//
// 사용법:
//   swift scripts/make-dmg-background.swift output.png
//
// 결과:
//   600x400 PNG. 옅은 회색 그라디언트 + 가운데 화살표 +
//   하단 "Drag PortKiller to Applications" 안내.
//
// 구현 노트:
//   commandline swift는 GUI 컨텍스트가 없어서 NSImage.lockFocus가 자주 실패함.
//   NSBitmapImageRep를 미리 만들고 그 위에 NSGraphicsContext를 직접 묶어서 그림.

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    print("usage: \(CommandLine.arguments[0]) <output.png>")
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let width = 600
let height = 400

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    print("ERROR: NSBitmapImageRep 생성 실패")
    exit(1)
}

guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    print("ERROR: NSGraphicsContext 생성 실패")
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let bounds = NSRect(x: 0, y: 0, width: width, height: height)

// 1. 배경: 위→아래 옅은 회색 그라디언트
let gradient = NSGradient(colors: [
    NSColor(white: 0.99, alpha: 1.0),
    NSColor(white: 0.94, alpha: 1.0),
])!
gradient.draw(in: bounds, angle: -90)

// 2. 가운데 화살표
//    아이콘 위치 (150, 200) / (450, 200) 사이를 잇는 화살표.
//    Finder 좌표는 좌하단 원점이라 y 그대로 사용.
let arrowColor = NSColor(white: 0.55, alpha: 1.0)
arrowColor.setStroke()

let arrowPath = NSBezierPath()
arrowPath.lineWidth = 3
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round

let yMid: CGFloat = 200
let xStart: CGFloat = 230
let xEnd: CGFloat = 370

arrowPath.move(to: NSPoint(x: xStart, y: yMid))
arrowPath.line(to: NSPoint(x: xEnd, y: yMid))

// 화살촉
arrowPath.move(to: NSPoint(x: xEnd - 12, y: yMid + 9))
arrowPath.line(to: NSPoint(x: xEnd, y: yMid))
arrowPath.line(to: NSPoint(x: xEnd - 12, y: yMid - 9))

arrowPath.stroke()

// 3. 하단 안내 텍스트
let labelText = "Drag PortKiller to Applications"
let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.alignment = .center

let labelAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor(white: 0.45, alpha: 1.0),
    .paragraphStyle: paragraphStyle,
]
let labelString = NSAttributedString(string: labelText, attributes: labelAttrs)
let labelRect = NSRect(x: 0, y: 60, width: width, height: 20)
labelString.draw(in: labelRect)

NSGraphicsContext.restoreGraphicsState()

// 4. PNG 인코딩 + 저장
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    print("ERROR: PNG 인코딩 실패")
    exit(1)
}

let url = URL(fileURLWithPath: outputPath)
try png.write(to: url)
print("✓ 생성: \(outputPath) (\(png.count) bytes)")
