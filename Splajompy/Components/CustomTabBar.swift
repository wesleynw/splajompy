import SwiftUI

struct CustomTabBar: View {
  @Binding var selectedIndex: Int
  @State private var isPresentingNewPost = false

  var body: some View {
    ZStack(alignment: .bottom) {
      HStack(spacing: 0) {
        TabBarButton(
          icon: "house",
          title: "Home",
          isSelected: selectedIndex == 0
        ) { selectedIndex = 0 }
        .frame(maxWidth: .infinity)

        TabBarButton(
          icon: "magnifyingglass",
          title: "Search",
          isSelected: selectedIndex == 1
        ) { selectedIndex = 1 }
        .frame(maxWidth: .infinity)

        ZStack {
          Color.clear.frame(height: 1)
          VStack {
            ZStack {
              Circle()
                .fill(Color.accentColor)
                .frame(width: 50, height: 50)
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 6)
              Image(systemName: "plus")
                .foregroundColor(.white)
                .font(.system(size: 20, weight: .bold))
            }
            .onTapGesture { isPresentingNewPost = true }
            .offset(y: -5)
            .sheet(
              isPresented: $isPresentingNewPost,
              onDismiss: { selectedIndex = 0 }
            ) {
              NewPostView()
            }
          }
        }
        .frame(maxWidth: .infinity)

        TabBarButton(
          icon: "bell",
          title: "Notifications",
          isSelected: selectedIndex == 2
        ) { selectedIndex = 2 }
        .frame(maxWidth: .infinity)

        TabBarButton(
          icon: "person.circle",
          title: "Profile",
          isSelected: selectedIndex == 3
        ) { selectedIndex = 3 }
        .frame(maxWidth: .infinity)
      }
      .padding(.horizontal, 0)
      .padding(.vertical, 12)
      .overlay(
        Rectangle()
          .frame(height: 1)
          .foregroundColor(Color.gray.opacity(0.2)),
        alignment: .top
      )
    }
  }
}

struct TabBarButton: View {
  let icon: String
  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 24))
        Text(title)
          .font(.system(size: 12))
      }
      .foregroundColor(isSelected ? .primary : Color.gray.opacity(0.5))
      .frame(maxWidth: .infinity)
    }
  }
}

#Preview {
  @Previewable @State var selected = 0
  CustomTabBar(selectedIndex: $selected)
}
