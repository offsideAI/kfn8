//
//  LoginView.swift
//  kfn8
//
//  Created by coder on 5/10/21.
//

import SwiftUI

struct LoginView: View {
    var choice: String
    var body: some View {
        NavigationView {
            VStack {
                ZStack {
                    BackCardView()
                        .offset(x: 0, y: -40)
                        .scaleEffect(0.9)
                        .rotationEffect(.degrees(10))
                    
                    BackCardView()
                        .offset(x: 0, y: -20)
                        .scaleEffect(0.95)
                        .rotationEffect(Angle(degrees: 5))
                    
                    CardView()
                }
                
                Text("Kfn8 The Metaverse")
                    .font(.title)
                    .foregroundColor(.secondary)
                    .padding()
                
                NavigationLink(
                    destination: ContentView(),
                    label: {
                        Text("Metaverse Explorer")
                            .bold()
                            .frame(width: 280, height: 50, alignment: .center)
                            .background(Color.blue)
                            .foregroundColor(Color.white)
                            .cornerRadius(10)
                    })
                /* TODO-FIXME-DEBUG-TEMP
                NavigationLink(
                    destination: TabViewContentView(),
                    label: {
                        Text("Metaverse Finder")
                            .bold()
                            .frame(width: 280, height: 50, alignment: .center)
                            .background(Color.blue)
                            .foregroundColor(Color.white)
                            .cornerRadius(10)
                            .padding(10)
                    })
                */
            }
        }
        .accentColor(Color(.label))
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoginView(choice: "ContentView")
        }
    }
}

struct CardView: View {
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text("Kfn8")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Kfn8 Reality")
                        .foregroundColor(Color("PawsomeOrange"))
                }
                Spacer()
                Image("ShoppingCart")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            Spacer()
            Image("LogoIcon")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 300, height: 110, alignment: .top)
        }
        .frame(width: 340.0, height: 220)
        .background(Color("Kfn8"))
        .cornerRadius(20)
        .shadow(radius: 20)
    }
}

struct BackCardView: View {
    var body: some View {
        VStack {
            Spacer()
        }
        .frame(width: 340, height: 220)
        .background(Color("PawsomeMaximumYellowRed"))
        .cornerRadius(20)
        .shadow(radius: 20)
    }
}
