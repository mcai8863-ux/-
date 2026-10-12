import SwiftUI

/// Vector artwork remains sharp at every display scale and needs no external image file.
struct GashaponMachine: View {
  let turn: Int
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private let ink = Color(red: 0.16, green: 0.31, blue: 0.28)
  private let mint = Color(red: 0.44, green: 0.74, blue: 0.62)

  var body: some View {
    ZStack {
      Ellipse().fill(.black.opacity(0.07)).frame(width: 156, height: 18).offset(y: 117)
      RoundedRectangle(cornerRadius: 22).fill(mint)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(ink, lineWidth: 3))
        .frame(width: 132, height: 112).offset(y: 59)
      RoundedRectangle(cornerRadius: 40).fill(Color(red: 0.94, green: 0.98, blue: 0.95))
        .overlay(RoundedRectangle(cornerRadius: 40).stroke(ink, lineWidth: 3))
        .frame(width: 152, height: 140).offset(y: -42)
      ZStack {
        capsule(.orange, x: -43, y: -17, angle: -25)
        capsule(.pink, x: 2, y: -28, angle: 30)
        capsule(.blue, x: 42, y: -14, angle: -15)
        capsule(.yellow, x: -24, y: 17, angle: 20)
        capsule(.green, x: 22, y: 15, angle: -30)
      }.offset(y: -35)
        .rotationEffect(.degrees(reduceMotion ? 0 : (turn.isMultiple(of: 2) ? -3 : 3)))
        .animation(.spring(response: 0.3, dampingFraction: 0.4), value: turn)
      Capsule().fill(.white.opacity(0.8)).frame(width: 9, height: 35)
        .rotationEffect(.degrees(20)).offset(x: -53, y: -74)
      RoundedRectangle(cornerRadius: 7).fill(mint)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(ink, lineWidth: 3))
        .frame(width: 114, height: 17).offset(y: -113)
      HStack(spacing: 14) {
        Circle().fill(ink).frame(width: 5, height: 7)
        Circle().fill(ink).frame(width: 5, height: 7)
      }.offset(y: 27)
      Circle().trim(from: 0.05, to: 0.45).stroke(
        ink, style: StrokeStyle(lineWidth: 2, lineCap: .round)
      )
      .frame(width: 10, height: 10).offset(y: 30)
      Circle().fill(Color.white.opacity(0.9)).overlay(Circle().stroke(ink, lineWidth: 2.5))
        .frame(width: 40, height: 40).offset(y: 58)
      Capsule().fill(mint).overlay(Capsule().stroke(ink, lineWidth: 2))
        .frame(width: 29, height: 10)
        .rotationEffect(.degrees(reduceMotion ? -30 : Double(turn) * 180 - 30))
        .animation(.easeInOut(duration: 0.35), value: turn).offset(y: 58)
      RoundedRectangle(cornerRadius: 8).fill(ink).frame(width: 48, height: 23).offset(y: 97)
      Capsule().fill(Color(red: 0.95, green: 0.77, blue: 0.36)).frame(width: 23, height: 13).offset(
        y: 98)
    }.frame(width: 180, height: 260).accessibilityHidden(true)
  }

  private func capsule(_ color: Color, x: CGFloat, y: CGFloat, angle: Double) -> some View {
    ZStack {
      Circle().fill(color.opacity(0.7))
      Circle().trim(from: 0, to: 0.5).fill(.white.opacity(0.65))
      Rectangle().fill(ink.opacity(0.35)).frame(height: 1.5)
    }.frame(width: 36, height: 36)
      .overlay(Circle().stroke(ink.opacity(0.65), lineWidth: 1.5))
      .rotationEffect(.degrees(angle)).offset(x: x, y: y)
  }
}
