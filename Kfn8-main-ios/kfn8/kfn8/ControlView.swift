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
            
        }
    }
}


struct ControlButtonBar: View {
    var body: some View {
        HStack {
            Button(action: {
                print("MostrecentlyPlaced button pressed")
            }) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 35))
                    .foregroundColor(.white)
                    .buttonStyle(PlainButtonStyle())
            }
            .frame(width: 50, height: 50)
            
            Button(action: {
                print("Browse button pressed")
            }) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 35))
                    .foregroundColor(.white)
                    .buttonStyle(PlainButtonStyle())
            }
            .frame(width: 50, height: 50)
            
            Button(action: {
                print("Settings button pressed")
            }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 35))
                    .foregroundColor(.white)
                    .buttonStyle(PlainButtonStyle())
            }
            .frame(width: 50, height: 50)
        }
        .frame(maxWidth: 500)
        .padding(30)
        .background(Color.black .opacity(0.25))
    }
}
