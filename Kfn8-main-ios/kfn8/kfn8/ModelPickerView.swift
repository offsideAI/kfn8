//
//  ModelPickerView.swift
//  kfn8
//
//  Created by coder on 6/16/21.
//

import SwiftUI

struct ModelPickerView: View {
    @EnvironmentObject var placementSettings: PlacementSettings
    @Binding var isPlacementPanelEnabled: Bool
    var items: [Model]
    var body: some View {
        ScrollView(.horizontal, showsIndicators:false) {
            HStack(spacing: 30) {
                ForEach(0 ..< self.items.count) { index in
                    // Text(self.models[index].modelName)
                    let model = items[index]
                    ItemButton(model: model, height: 80) {
                      // call model method to async load modelEntity
                      model.asyncLoadModelEntity()
                      // select model for placement
                      self.placementSettings.currentSelectedModel = model
                      print("\(#file) | HorizontalGrid : selected \(model.modelName). for placement.")
                      print("\(#file) | HorizontalGrid : selected model with name: \(model.modelName)")
                      self.isPlacementPanelEnabled = true
                    }
                    /* TODO-FIXME-DEBUG-DEPRECATE-REMOVE
                    Button(action: {
                        print("Selected model with name: \(self.items[index].modelName)")
                        self.placementSettings.currentSelectedModel = self.items[index]
                        self.isPlacementPanelEnabled = true
                        
                    }) {
                        Image(uiImage: self.items[index].image)
                                .resizable()
                                .frame(height:80)
                                .aspectRatio(1/1, contentMode: .fit)
                                .background(Color.white)
                                .cornerRadius(12)
                        
                        
                    }
                    .buttonStyle(PlainButtonStyle())
                    */
                    
                }
            }
        }
        // .padding(20)
        .padding(.top, 20)
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.bottom, 130)
        .background(Color.black.opacity(0.5))
    }
}
