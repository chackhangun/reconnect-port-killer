#!/usr/bin/env swift
//
// DMG 배경 PNG 생성 스크립트.
//
// 사용법:
//   swift scripts/make-dmg-background.swift output.png
//
// 결과:
//   600x400 PNG.
//   - 상단: 드래그 UX (PortKiller.app → Applications) + 화살표 + 안내
//   - 하단: Install.command 사용 안내 (Gatekeeper 회피)
//
// 구현 노트:
//   commandline swift는 GUI 컨텍스트가 없어서 NSImage.lockFocus가 자주 실패함.
//   NSBitmapImageRep + NSGraphicsContext로 직접 그림.
//   좌표는 모두 Cocoa 표준(좌하단 원점). DMG의 아이콘 위치 좌표와 동일.

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

// 1. 배경: 위→아래 옅은 그라디언트
let gradient = NSGradient(colors: [
    NSColor(white: 0.99, alpha: 1.0),
    NSColor(white: 0.94, alpha: 1.0),
])!
gradient.draw(in: bounds, angle: -90)

// 2. 상단 화살표 — PortKiller.app(130, 230) → Applications(470, 230) 사이
let arrowColor = NSColor(white: 0.55, alpha: 1.0)
arrowColor.setStroke()

let arrowPath = NSBezierPath()
arrowPath.lineWidth = 3
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round

let yArrow: CGFloat = 230
let xStart: CGFloat = 220
let xEnd: CGFloat = 380

arrowPath.move(to: NSPoint(x: xStart, y: yArrow))
arrowPath.line(to: NSPoint(x: xEnd, y: yArrow))
arrowPath.move(to: NSPoint(x: xEnd - 12, y: yArrow + 9))
arrowPath.line(to: NSPoint(x: xEnd, y: yArrow))
arrowPath.line(to: NSPoint(x: xEnd - 12, y: yArrow - 9))
arrowPath.stroke()

// 3. 상단 안내 텍스트: "Drag PortKiller to Applications"
let centerStyle = NSMutableParagraphStyle()
centerStyle.alignment = .center

let mainAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor(white: 0.45, alpha: 1.0),
    .paragraphStyle: centerStyle,
]
NSAttributedString(string: "Drag PortKiller to Applications", attributes: mainAttrs)
    .draw(in: NSRect(x: 0, y: 165, width: width, height: 20))

// 4. 구분선 (가운데)
NSColor(white: 0.85, alpha: 1.0).setStroke()
let divider = NSBezierPath()
divider.lineWidth = 1
divider.move(to: NSPoint(x: 80, y: 140))
divider.line(to: NSPoint(x: 250, y: 140))
divider.move(to: NSPoint(x: 350, y: 140))
divider.line(to: NSPoint(x: 520, y: 140))
divider.stroke()

let orAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
    .foregroundColor: NSColor(white: 0.6, alpha: 1.0),
    .paragraphStyle: centerStyle,
]
NSAttributedString(string: "또는", attributes: orAttrs)
    .draw(in: NSRect(x: 0, y: 132, width: width, height: 16))

// 5. 하단 안내: Install.command
let subAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
    .foregroundColor: NSColor(white: 0.45, alpha: 1.0),
    .paragraphStyle: centerStyle,
]
NSAttributedString(string: "Install.command 더블클릭 (자동 설치 + 보안 경고 우회)", attributes: subAttrs)
    .draw(in: NSRect(x: 0, y: 40, width: width, height: 18))

NSGraphicsContext.restoreGraphicsState()

// PNG 저장
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    print("ERROR: PNG 인코딩 실패")
    exit(1)
}

let url = URL(fileURLWithPath: outputPath)
try png.write(to: url)
print("✓ 생성: \(outputPath) (\(png.count) bytes)")
