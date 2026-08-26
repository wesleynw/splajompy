import SwiftUI

struct AboutView: View {
  let appVersion =
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
  let buildNumber =
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

  var body: some View {
    Form {
      aboutSections
    }
    .formStyle(.grouped)
    .modify {
      #if os(iOS)
        $0.pageTitle("About")
      #endif
    }
  }

  @ViewBuilder
  private var aboutSections: some View {
    Section {
      VStack {
        Image("icon_snail")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 150, height: 150)
      }
      .frame(maxWidth: .infinity)
    }

    Section {
      HStack {
        Text("Version")
        Spacer()
        Text("\(appVersion) (Build \(buildNumber))")
          .font(.footnote)
          .fontWeight(.bold)
          .foregroundStyle(.secondary)
      }
    }

    Section {
      Link(
        destination: URL(string: "https://github.com/wesleynw/splajompy")!
      ) {
        HStack {
          Label(
            "Source Code",
            systemImage: "chevron.left.forwardslash.chevron.right"
          )
        }
      }
    }

    Section {
      Link(destination: URL(string: "https://splajompy.com/privacy")!) {
        HStack {
          Label("Privacy Policy", systemImage: "lock.shield")
          Spacer()
        }
      }
      Link(destination: URL(string: "https://splajompy.com/tos")!) {
        HStack {
          Label("Terms of Service", systemImage: "doc.text")
          Spacer()
        }
      }
    }

    #if os(iOS)
      Section {
        NavigationLink(destination: StatisticsView()) {
          Label("Statistics", systemImage: "chart.xyaxis.line")
        }
      }
    #endif

    StorageManager()
  }
}

#Preview {
  NavigationStack {
    AboutView()
  }
}
