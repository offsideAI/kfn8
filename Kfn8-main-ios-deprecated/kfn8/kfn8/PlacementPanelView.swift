//
//  PlacementPanelView.swift
//  kfn8
//
//  Created by coder on 6/10/21.
//

import SwiftUI



struct PlacementPanelView: View {
    @EnvironmentObject var placementSettings: PlacementSettings
    @Binding var isPlacementPanelEnabled: Bool
    @Binding var modelConfirmedForPlacement: Model?
    
    var body: some View {
        HStack {
            
            /*
            Button(action: {
                print("Model placement cancel")
                self.resetControlParameters()
            }) {
                Image(systemName: "xmark")
                    .frame(width: 60, height: 60)
                    .font(.title)
                    .background(Color.white.opacity(0.75))
                    .cornerRadius(30)
                    .padding(20)
            }
            Button(action: {
                 print("Model placement confirm")
                 self.modelConfirmedForPlacement = self.selectedModel
                 self.resetControlParameters()
            }) {
                 Image(systemName: "checkmark")
                     .frame(width: 60, height: 60)
                     .font(.title)
                     .background(Color.white.opacity(0.75))
                     .cornerRadius(30)
                     .padding(20)
            }
            */
            Spacer()
            // Cancel Button
            PlacementButton(systemIconName: "xmark.circle.fill") {
                print("Cancel Placement Button pressed")
                self.placementSettings.currentSelectedModel = nil
            }
            Spacer()
            // Confirm Button
            PlacementButton(systemIconName: "checkmark.circle.fill") {
                print("Confirm placement button pressed")
                self.placementSettings.currentConfirmedModel = self.placementSettings.currentSelectedModel
                self.placementSettings.currentSelectedModel = nil
            }
            Spacer()
        }
        .padding(.top, 20)
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.bottom, 230)
    }
    func resetControlParameters() {
        self.isPlacementPanelEnabled = false
    }
}

struct PlacementButton: View {
    let systemIconName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            self.action()
        }) {
            Image(systemName: systemIconName)
                .font(.system(size: 50, weight: .light, design: .default))
                .foregroundColor(.white)
                .buttonStyle(PlainButtonStyle())
        }
        .frame(width: 75, height: 75)
    }
}
