import SwiftUI

private let ink = Color(red: 0.16, green: 0.20, blue: 0.17)
private let accent = Color(red: 0.32, green: 0.40, blue: 0.29)

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A SMALL RITUAL FOR YOUR MAC").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(accent)
                    Text("Close with character.").font(.system(size: 32, weight: .semibold, design: .serif)).foregroundStyle(ink)
                    Text("A satisfying sound when the lid comes down.").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "laptopcomputer").font(.system(size: 38, weight: .ultraLight)).foregroundStyle(accent).padding(.top, 12)
            }
            HStack {
                Label(model.enabled ? "Lid sounds are on" : "Lid sounds are paused", systemImage: model.enabled ? "waveform" : "pause.circle")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Toggle("Enable lid sounds", isOn: $model.enabled).labelsHidden().toggleStyle(.switch)
            }.padding(14).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("PICK YOUR CLOSING NOTE").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5)
                    Spacer()
                    Text("All under a second").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                ForEach(SoundChoice.builtIns) { sound in soundRow(sound) }
                if model.customPath != nil {
                    soundRow(.init(id: "custom", title: "Your sound", detail: "A little something of your own.", symbol: "music.note"))
                }
                Button(action: model.importSound) { Label(model.customPath == nil ? "Add your own sound…" : "Replace your sound…", systemImage: "plus") }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .medium)).foregroundStyle(accent).padding(.top, 4)
            }

            HStack(spacing: 12) {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                Slider(value: $model.volume, in: 0...1).tint(accent).accessibilityLabel("Sound volume")
                Text("\(Int(model.volume * 100))%").monospacedDigit().font(.system(size: 12)).frame(width: 35, alignment: .trailing)
                Button { model.preview() } label: { Label("Preview", systemImage: "play.fill") }.controlSize(.large)
            }
            VStack(spacing: 12) {
                Toggle("Surprise me with a built-in sound", isOn: $model.shuffle)
                Toggle("Start at login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
            }.toggleStyle(.switch).font(.system(size: 12))
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Label(model.status, systemImage: "circle.fill").font(.system(size: 11)).foregroundStyle(accent)
                Text("Plays through your current audio output. macOS may cut audio short as it sleeps; short sounds work best.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(28).frame(width: 540)
        .background(Color(red: 0.96, green: 0.95, blue: 0.92))
        .preferredColorScheme(.light)
    }

    private func soundRow(_ sound: SoundChoice) -> some View {
        let selected = model.selectedSound == sound.id
        return HStack(spacing: 12) {
            Button {
                model.selectedSound = sound.id
                model.shuffle = false
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: sound.symbol).font(.system(size: 20, weight: .light)).frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(sound.title).font(.system(size: 13, weight: .semibold))
                        Text(sound.detail).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(accent) }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Select \(sound.title)")
            Button { model.preview(sound.id) } label: { Image(systemName: "play.circle").font(.system(size: 21, weight: .light)) }
                .buttonStyle(.plain).help("Preview \(sound.title)").accessibilityLabel("Preview \(sound.title)")
        }.padding(12).foregroundStyle(ink)
            .background(selected ? accent.opacity(0.10) : .white.opacity(0.55), in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected ? accent.opacity(0.45) : .clear, lineWidth: 1))
    }
}
