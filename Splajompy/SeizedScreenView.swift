#if os(iOS)
  import SwiftUI

  struct SeizedScreenView: View {
    var body: some View {
      ZStack {
        Color(red: 0.0, green: 0.16, blue: 0.41)
          .ignoresSafeArea()

        Image(systemName: "shield.fill")
          .resizable()
          .scaledToFit()
          .foregroundColor(.white.opacity(0.06))
          .scaleEffect(1.4)
          .ignoresSafeArea()
          .allowsHitTesting(false)

        ScrollView {
          VStack(spacing: 0) {
            topBanner

            VStack(alignment: .leading, spacing: 16) {
              sealsRow
              bodyText
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)

            footer
          }
          .padding(.top)
        }
        .ignoresSafeArea(edges: .bottom)
      }
    }

    // MARK: - Top Banner

    private var topBanner: some View {
      VStack(spacing: 0) {
        Rectangle()
          .fill(Color(red: 0.83, green: 0.68, blue: 0.21))
          .frame(height: 3)

        ZStack {
          Color.black.opacity(0.35)
          VStack(spacing: 2) {
            Text("THIS APP HAS BEEN SEIZED")
              .font(.system(size: 24, weight: .black))
              .foregroundColor(.white)
              .tracking(1)
            Text("FEDERAL BUREAU OF INVESTIGATION")
              .font(.system(size: 16, weight: .bold))
              .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
              .tracking(1)
          }
          .padding(.vertical, 5)
          .padding(.horizontal, 20)
        }

        Rectangle()
          .fill(Color(red: 0.83, green: 0.68, blue: 0.21))
          .frame(height: 3)
      }
    }

    // MARK: - Seals

    private var sealsRow: some View {
      HStack(alignment: .top, spacing: 8) {
        sealImage("seal-doj")
        sealImage("seal-fbi")
        sealImage("seal-ncis")
      }
      .frame(maxWidth: .infinity)
    }

    private func sealImage(_ name: String) -> some View {
      Image(name)
        .resizable()
        .scaledToFit()
        .frame(width: 88, height: 88)
    }

    // MARK: - Body

    private var bodyText: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("NOTICE OF SEIZURE")
          .font(.system(size: 15, weight: .bold))
          .foregroundColor(.white)
          .underline()

        Text(
          "This application has been seized by the Federal Bureau of Investigation in accordance with a seizure warrant issued by the United States District Court for the District of Columbia as part of a joint law enforcement operation and action by:"
        )
        .font(.system(size: 16))
        .foregroundColor(.white)
        .lineSpacing(3)

        VStack(alignment: .leading, spacing: 6) {
          bulletRow("Federal Bureau of Investigation (FBI)")
          bulletRow("Department of Justice (DOJ)")
          bulletRow("Naval Criminal Investigative Service (NCIS)")
          bulletRow("U.S. Attorney's Office, District of Columbia")
        }

        Rectangle()
          .fill(Color.white.opacity(0.3))
          .frame(height: 1)

        Text(
          "Persons who use this application may be subject to investigation for violations of federal law, including but not limited to 18 U.S.C. § 1030 (Computer Fraud and Abuse Act)."
        )
        .font(.system(size: 15))
        .foregroundColor(.white.opacity(0.8))
        .lineSpacing(3)
      }
    }

    private func bulletRow(_ text: String) -> some View {
      HStack(alignment: .top, spacing: 6) {
        Text("-")
          .font(.system(size: 16))
          .foregroundColor(.white)
        Text(text)
          .font(.system(size: 16))
          .foregroundColor(.white)
      }
    }

    // MARK: - Footer

    private var footer: some View {
      VStack(spacing: 0) {
        Rectangle()
          .fill(Color(red: 0.83, green: 0.68, blue: 0.21))
          .frame(height: 3)
        HStack {
          Text("justice.gov")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(
              Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.8)
            )
          Spacer()
          Text("ic3.gov")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(
              Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.8)
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
      }
      .background(Color.black.opacity(0.4).ignoresSafeArea())
    }
  }

  #Preview {
    SeizedScreenView()
  }
#endif
