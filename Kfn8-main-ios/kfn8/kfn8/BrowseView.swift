//
//  BrowseView.swift
//  kfn8
//
//  Created by coder on 6/4/21.
//

import SwiftUI

struct BrowseView: View {
    @Binding var isBrowseShown: Bool
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                 // Gridviews for thumbnails
                ModelsByCategoryGrid()
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

struct ModelsByCategoryGrid: View {
    let models = Models()
    
    var body: some View {
        VStack {
            ForEach(ModelCategory.allCases, id:\.self) { category in
                
                // Only display grid if category contains items
                if let modelsByCategory = models.get(category: category) {
                    HorizontalGrid(title: category.label, items: modelsByCategory)
                }
                
            }
        }
    }
}

struct HorizontalGrid: View {
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
                        Color(UIColor.secondarySystemFill)
                            .frame(width: 150, height: 150)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                
            }
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
