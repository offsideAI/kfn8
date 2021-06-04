//
//  ControlView.swift
//  kfn8
//
//  Created by coder on 6/4/21.
//


import SwiftUI


struct ControlView: View {
    @Binding var isControlsVisible: Bool
    @Binding var isBrowseVisible: Bool
    var body: some View {
        VStack {
            ControlVisibilityToggleButton(isControlsVisible: $isControlsVisible)
            
            Spacer()
            
            if isControlsVisible {
                ControlButtonBar(isBrowseShown: $isBrowseVisible)
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
                    self.isControlsVisible.toggle()
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
    @Binding var isBrowseShown: Bool
    var body: some View {
        HStack {
            // MostRecentlyPlacedButton
            ControlButton(systemIconName: "line.horizontal.3") {
                print("MostrecentlyPlaced button pressed")
            }
            
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
            ControlButton(systemIconName: "slider.horizontal.3") {
                print("Settings button pressed")
            }
            
            
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
