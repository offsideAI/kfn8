//
//  ControlView.swift
//  kfn8
//
//  Created by coder on 6/4/21.
//


import SwiftUI


struct ControlView: View {
    var body: some View {
        VStack {
            ControlVisibilityToggleButton()
            
            Spacer()
            
            ControlButtonBar()
        }
    }
    
}

#if DEBUG

struct ControlView_Previews: PreviewProvider {
    static var previews: some View {
        ControlView()
    }
}

#endif


struct ControlVisibilityToggleButton: View {
    var body: some View {
        HStack {
            
            Spacer()
            
            ZStack {
                Color.black.opacity(0.25)
                
                Button(action: {
                    print("ControlVisibility Toggle button pressed")
                }) {
                    Image(systemName: "rectangle")
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
    var body: some View {
        HStack {
            
            ControlButton(systemIconName: "clock.fill") {
                print("MostrecentlyPlaced button pressed")
            }
            
            Spacer()
            
            ControlButton(systemIconName: "square.grid.2x2") {
                print("Browse button pressed")
            }
            
            Spacer()
            
            
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
