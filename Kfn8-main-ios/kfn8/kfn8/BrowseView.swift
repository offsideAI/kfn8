//
//  BrowseView.swift
//  kfn8
//
//  Created by coder on 6/4/21.
//

import SwiftUI

struct BrowseView: View {
  @EnvironmentObject var placementSettings: PlacementSettings
  @Binding var isBrowseShown: Bool
  var body: some View {
    NavigationView {
      ScrollView(showsIndicators: false) {
        // Gridviews for thumbnails
        // TODO-FIXME-DEBUG-DEPRECATE-TEMP RecentsGrid(isBrowseShown: $isBrowseShown)
        ModelsByCategoryGrid(isBrowseShown: $isBrowseShown)
      }
      .navigationBarTitle(Text("Browse"), displayMode: .large)
      .navigationBarItems(trailing:
                            Button(action: {
                              self.isBrowseShown.toggle()
                            }) {
                              Text("Done").bold()
                            })
    }
  }
  
}

struct RecentsGrid: View {
  @EnvironmentObject var placementSettings: PlacementSettings
  @Binding var isBrowseShown: Bool
  var body: some View {
    if !self.placementSettings.recentlyPlaced.isEmpty {
      HorizontalGrid(isBrowseShown: $isBrowseShown, title: "Recents", items: getRecentsUniqueOrdered())
    }
  }
  
  func getRecentsUniqueOrdered() -> [Model] {
    var recentsUniqueOrderedArray: [Model] = []
    var modelNameSet: Set<String> = []
    
    for model in self.placementSettings.recentlyPlaced.reversed() {
      if !modelNameSet.contains(model.modelName) {
        recentsUniqueOrderedArray.append(model)
        modelNameSet.insert(model.modelName)
      }
    }
    return recentsUniqueOrderedArray
  }
}

struct ModelsByCategoryGrid: View {
  @Binding var isBrowseShown: Bool
  let models = Models()
  
  var body: some View {
    VStack {
      ForEach(ModelCategory.allCases, id:\.self) { category in
        
        // Only display grid if category contains items
        if let modelsByCategory = models.get(category: category) {
          HorizontalGrid(isBrowseShown: $isBrowseShown, title: category.label, items: modelsByCategory)
        }
        
      }
    }
  }
}

struct HorizontalGrid: View {
  @Binding var isBrowseShown: Bool
  @EnvironmentObject var placementSettings: PlacementSettings
  
  var title: String
  var items: [Model]
  private let gridItemLayout = [GridItem(.fixed(150))]
  var body: some View {
    VStack(alignment: .leading) {
      Separator()
      Text(title)
        .font(.title2).bold()
        .padding(.leading, 22)
        .padding(.top, 10)
      
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHGrid(rows: gridItemLayout, spacing: 30) {
          ForEach(0..<items.count) { index in
            
            let model = items[index]
            
            ItemButton(model: model) {
              // call model method to async load modelEntity
              model.asyncLoadModelEntity()
              // select model for placement
              self.placementSettings.currentSelectedModel = model
              print("BrowseView | HorizontalGrid : selected \(model.modelName). for placement.")
              print("BrowseView | HorizontalGrid : selected model with name: \(model.modelName)")
              self.isBrowseShown = false
            }
            /*
             Color(UIColor.secondarySystemFill)
             .frame(width: 150, height: 150)
             .cornerRadius(8)
             */
          }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        
      }
    }
  }
}

struct ItemButton: View {
  let model: Model
  let action: () -> Void
  var body: some View {
    Button(action: {
      self.action()
    }) {
      Image(uiImage: self.model.image)
        .resizable()
        .frame(height: 150)
        .aspectRatio(1/1, contentMode: .fit)
        .background(Color(UIColor.secondarySystemFill))
        .cornerRadius(8.0)
    }
  }
}

struct Separator: View {
  var body: some View {
    Divider()
      .padding(.horizontal, 20)
      .padding(.vertical, 10)
  }
}
