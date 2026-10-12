import SwiftData
import SwiftUI

@main
struct DailyBetterApp: App {
  var body: some Scene {
    WindowGroup("日进") {
      ContentView()
        .frame(minWidth: 1180, minHeight: 680)
        .tint(Color(red: 0.16, green: 0.46, blue: 0.35))
    }
    .modelContainer(for: [
      RecordObservation.self, Item.self, ExperienceGroup.self, Experience.self,
      ImprovementRecord.self, InspirationDecision.self, InspirationExposure.self,
    ])
    .windowStyle(.hiddenTitleBar)
    .defaultSize(width: 1280, height: 760)

    Settings {
      SettingsView()
    }
  }
}

struct SettingsView: View {
  var body: some View {
    Form {
      LabeledContent("数据位置", value: "本机 SwiftData")
      LabeledContent("建议来源", value: "内置候选库")
    }
    .formStyle(.grouped)
    .frame(width: 420, height: 180)
    .padding()
  }
}
