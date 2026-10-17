import SwiftUI

private let ink = Color(red: 0.16, green: 0.20, blue: 0.17)
private let accent = Color(red: 0.32, green: 0.40, blue: 0.29)

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SOUND THAT MOVES WITH YOUR MAC").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.8).foregroundStyle(accent)
                    Text("Every tilt has a sound.").font(.system(size: 31, weight: .semibold, design: .serif)).foregroundStyle(ink)
                    Text("Move your screen. Hear the hinge come alive.").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "waveform").font(.system(size: 34, weight: .light)).foregroundStyle(accent).padding(.top, 15)
            }
            HStack(spacing: 20) {
                HingeIllustration(angle: model.angle ?? 90).frame(width: 110, height: 88)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.angle.map { "\(Int($0))°" } ?? "—°").font(.system(size: 39, weight: .light, design: .rounded)).monospacedDigit()
                        .accessibilityLabel("Live hinge angle: \(model.angle.map { String(Int($0)) } ?? "unavailable") degrees")
                    Text(model.motionLabel).font(.system(size: 12, weight: .medium)).foregroundStyle(accent)
                }
                Spacer()
                Toggle("Enable motion sounds", isOn: $model.enabled).labelsHidden().toggleStyle(.switch)
            }.padding(16).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 11) {
                Text("CHOOSE YOUR CHARACTER").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5)
                ForEach(MotionStyle.all) { style in
                    HStack(spacing: 12) {
                        Button { model.selectedStyle = style.id } label: {
                            HStack(spacing: 12) {
                                Image(systemName: style.symbol).font(.system(size: 23, weight: .light)).frame(width: 30)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(style.title).font(.system(size: 14, weight: .semibold))
                                    Text(style.detail).font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if model.selectedStyle == style.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(accent) }
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel("Select \(style.title)")
                        Button { model.preview(style.id) } label: { Image(systemName: "play.circle").font(.system(size: 23, weight: .light)) }
                            .buttonStyle(.plain).help("Preview \(style.title)").accessibilityLabel("Preview \(style.title)")
                    }.padding(16).foregroundStyle(ink)
                        .background(model.selectedStyle == style.id ? accent.opacity(0.1) : .white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.selectedStyle == style.id ? accent.opacity(0.4) : .clear, lineWidth: 1))
                }
            }
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.2").foregroundStyle(.secondary).frame(width: 22)
                    Slider(value: $model.volume, in: 0...1).tint(accent).accessibilityLabel("Sound volume")
                    Text("\(Int(model.volume * 100))%").monospacedDigit().font(.system(size: 12)).frame(width: 35)
                }
                HStack(spacing: 12) {
                    Text("Response").font(.system(size: 12))
                    Slider(value: $model.sensitivity, in: 0.4...2).tint(accent).accessibilityLabel("Motion sensitivity")
                    Text("\(model.sensitivity, specifier: "%.1f")×").monospacedDigit().font(.system(size: 12)).frame(width: 35)
                }
            }
            HStack {
                Toggle("Start at login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) })).toggleStyle(.switch).font(.system(size: 12))
                Spacer()
                Button { model.preview() } label: { Label("Preview motion", systemImage: "play.fill") }.controlSize(.large)
            }
            Divider()
            VStack(alignment: .leading, spacing: 7) {
                Label(model.error ?? model.status, systemImage: model.angle != nil ? "sensor.fill" : "info.circle")
                    .font(.system(size: 11)).foregroundStyle(accent).fixedSize(horizontal: false, vertical: true)
                Text("Sound follows screen movement in both directions, then fades to silence when you stop. Uses your current audio output.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(28).frame(width: 540).background(Color(red: 0.96, green: 0.95, blue: 0.92)).preferredColorScheme(.light)
    }
}

private struct HingeIllustration: View {
    let angle: Double
    var body: some View {
        Canvas { context, size in
            let pivot = CGPoint(x: size.width * 0.3, y: size.height * 0.8)
            let radians = min(max(angle,0),180) * .pi / 180
            let tip = CGPoint(x: pivot.x + cos(radians)*60, y: pivot.y - sin(radians)*60)
            var base = Path(); base.move(to: pivot); base.addLine(to: CGPoint(x: size.width*0.95,y:pivot.y))
            var screen = Path(); screen.move(to: pivot); screen.addLine(to: tip)
            context.stroke(base, with: .color(accent.opacity(0.5)), style: StrokeStyle(lineWidth: 7,lineCap: .round))
            context.stroke(screen, with: .color(accent), style: StrokeStyle(lineWidth: 7,lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x:pivot.x-4,y:pivot.y-4,width:8,height:8)),with:.color(ink))
        }.accessibilityHidden(true)
    }
}
