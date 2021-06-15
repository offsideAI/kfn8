//
//  ControlView.swift
//  kfn8
//
//  Created by coder on 6/4/21.
//


import SwiftUI


struct ControlView: View {
    @Binding var isControlsVisible: Bool
    @Binding var isBrowseShown: Bool
    @Binding var isMyCollectionShown: Bool
    var body: some View {
        VStack {
            ControlVisibilityToggleButton(isControlsVisible: $isControlsVisible)
            
            Spacer()
            
            if isControlsVisible {
                ControlButtonBar(isBrowseShown: $isBrowseShown, isMyCollectionShown: $isMyCollectionShown)
            }
        }
    }
    
}


struct ControlVisibilityToggleButton: View {
    @Binding var isControlsVisible: Bool
    var body: some View {
        HStack {
            
            Spacer()
            
            ZStack {
                Color.black.opacity(0.25)
                
                Button(action: {
                    print("ControlVisibility Toggle button pressed")
                    // TODO-FIXME-DEBUG
                    // Don't show/hide the ControlView
                    // self.isControlsVisible.toggle()
                    
                }) {
                    Image(systemName: self.isControlsVisible ? "rectangle" : "slider.horizontal.below.rectangle")
                        .font(.system(size: 35))
                        .foregroundColor(.white)
                        .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8.0)
        }
        .padding(.top, 0)
        .padding(.trailing, 20)
    }
}


struct ControlButtonBar: View {
    @EnvironmentObject var placementSettings: PlacementSettings
    @Binding var isBrowseShown: Bool
    @Binding var isMyCollectionShown: Bool
    var body: some View {
        HStack {
            // MostRecentlyPlacedButton
            MostRecentlyPlacedButton().hidden(self.placementSettings.recentlyPlaced.isEmpty)
            Spacer()
            
            // BrowseButton
            ControlButton(systemIconName: "square.stack.3d.forward.dottedline") {
                print("Browse button pressed")
                self.isBrowseShown.toggle()
            }.sheet(isPresented: $isBrowseShown, content: {
                // BrowseView
                BrowseView(isBrowseShown: $isBrowseShown)
            })
            
            Spacer()
            
            
            // SettingButton

            ControlButton(systemIconName: "line.horizontal.3") {
                print("Settings button pressed")
                print("MostrecentlyPlaced button pressed")
                self.isMyCollectionShown.toggle()
            }.sheet(isPresented: $isMyCollectionShown, content: {
                MoreView(isMyCollectionShown: $isMyCollectionShown)
            })
        
            
            /*
            Button(action: {
                print("Browse button pressed")
            }) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 35))
                    .foregroundColor(.white)
                    .buttonStyle(PlainButtonStyle())
            }
            .frame(width: 50, height: 50)
            */

        }
        .frame(maxWidth: 500)
        .padding(30)
        .background(Color.black .opacity(0.25))
    }
}

struct ControlButton: View {
    let systemIconName: String
    let action: () -> Void
    var body: some View {
        Button(action: {
            self.action()
        }) {
            Image(systemName: systemIconName)
                .font(.system(size: 35))
                .foregroundColor(.white)
                .buttonStyle(PlainButtonStyle())
        }
        .frame(width: 50, height: 50)
    }
}

struct MostRecentlyPlacedButton: View {
    @EnvironmentObject var placementSettings: PlacementSettings
    var body: some View {
        Button(action: {
            print("Most Recently Placed button pressed")
            self.placementSettings.currentSelectedModel = self.placementSettings.recentlyPlaced.last
        }) {
            if let mostRecentlyPlacedModel = self.placementSettings.recentlyPlaced.last {
                Image(uiImage: mostRecentlyPlacedModel.image)
                    .resizable()
                    .frame(width: 46)
                    .aspectRatio(1/1, contentMode: .fit)
            } else {
                 Image(systemName: "clock.fill")
                    .font(.system(size: 35))
                    .foregroundColor(.white)
                    .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(width: 50, height: 50)
        .background(Color.white)
        .cornerRadius(8.0)
        
    }
}
