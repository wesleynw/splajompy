import SwiftUI
import UIKit

struct FilterState: Codable, Equatable {
  var mode: FilterMode = .all

  enum FilterMode: String, Codable, Hashable {
    case all, following
  }
}

class FilterStateManager: ObservableObject {
  @Published var state: FilterState {
    didSet {
      if let encoded = try? JSONEncoder().encode(state) {
        UserDefaults.standard.set(encoded, forKey: "feedFilterState")
      }
      onStateChange?(state)
    }
  }

  var onStateChange: ((FilterState) -> Void)?

  init(initialState: FilterState? = nil) {
    if let initialState = initialState {
      self.state = initialState
    } else if let savedState = UserDefaults.standard.data(forKey: "feedFilterState"),
      let decodedState = try? JSONDecoder().decode(FilterState.self, from: savedState)
    {
      self.state = decodedState
    } else {
      self.state = FilterState()
    }
  }
}

struct FilterButton: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      action()
    } label: {
      Text(title)
        .fontWeight(.bold)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color.accentColor : Color.clear)
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                  isSelected ? Color.accentColor : Color.primary,
                  lineWidth: 1
                )
            )
        )
        .foregroundColor(isSelected ? .white : .primary)
    }
  }
}

struct DrilldownFilter: View {
  @Binding var filterState: FilterState
  private var onFilterChange: ((FilterState) -> Void)?
  @StateObject private var stateManager: FilterStateManager
  private var isUsingBinding: Bool

  init(filterState: Binding<FilterState>) {
    self._filterState = filterState
    self._stateManager = StateObject(
      wrappedValue: FilterStateManager(initialState: filterState.wrappedValue)
    )
    self.onFilterChange = nil
    self.isUsingBinding = true
  }

  init(
    initialState: FilterState = FilterState(),
    onChange: @escaping (FilterState) -> Void
  ) {
    self._filterState = .constant(initialState)
    self.onFilterChange = onChange
    self._stateManager = StateObject(
      wrappedValue: FilterStateManager(initialState: initialState)
    )
    self.isUsingBinding = false
  }

  private var currentState: FilterState {
    isUsingBinding ? filterState : stateManager.state
  }

  private func updateFilter(mode: FilterState.FilterMode) {
    withAnimation(.snappy) {
      if isUsingBinding {
        var newState = filterState
        newState.mode = mode
        self.filterState = newState
      } else {
        var newState = stateManager.state
        newState.mode = mode
        stateManager.state = newState
      }
    }
  }

  var body: some View {
    HStack(spacing: 12) {
      FilterButton(
        title: "All",
        isSelected: currentState.mode == .all,
        action: { updateFilter(mode: .all) }
      )

      FilterButton(
        title: "Following",
        isSelected: currentState.mode == .following,
        action: { updateFilter(mode: .following) }
      )
    }
    .padding(.vertical, 8)
    .padding(.horizontal)
    .background(Color(.systemBackground))
    .onAppear {
      if let onFilterChange = onFilterChange {
        stateManager.onStateChange = onFilterChange
      }

      if isUsingBinding {
        stateManager.state = filterState
      }
    }
    .onChange(of: filterState) { oldValue, newValue in
      if isUsingBinding && stateManager.state != newValue {
        stateManager.state = newValue
      }
    }
    .onChange(of: stateManager.state) { oldValue, newValue in
      if isUsingBinding && filterState != newValue {
        filterState = newValue
      }
    }
  }
}

#Preview("Simple Filter Component") {
  DrilldownFilter(
    filterState: .constant(FilterState(mode: .following))
  )
  .preferredColorScheme(.dark)
  .accentColor(.green)
}
