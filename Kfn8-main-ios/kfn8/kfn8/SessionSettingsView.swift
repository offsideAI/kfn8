//
//  SessionSettingsView.swift
//  kfn8
//
//  Created by coder on 6/9/21.
//

import SwiftUI

enum Setting {
    case peopleOcclusion
    case objectOcclusion
    case lidarDebug
    case multiUser
    
    var label: String {
        get {
            switch self {
            case .peopleOcclusion, .objectOcclusion:
                return "Occlusion"
            case .lidarDebug:
                return "LiDAR"
            case .multiUser:
                return "Multiuser"
            }
            
        }
    }
    
    var systemIconName: String {
        get {
            switch self {
            case .peopleOcclusion:
                return "person"
            case .objectOcclusion:
                return "cube.box.fill"
            case .lidarDebug:
                return "light.min"
            case .multiUser:
                return "person.2"
            }
            
        }
    }
}

struct SettingsGrid: View {
    @EnvironmentObject var sessionSettings: SessionSettings
    private var gridItemLayout = [GridItem(.adaptive(minimum: 100, maximum: 100), spacing: 25)]
    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridItemLayout, spacing: 25) {
                
                SettingsToggleButton(setting: .peopleOcclusion, isSettingOn: $sessionSettings.isPeopleOcclusionEnabled)
                
                SettingsToggleButton(setting: .objectOcclusion, isSettingOn: $sessionSettings.isObjectOcclusionEnabled)
                
                SettingsToggleButton(setting: .lidarDebug, isSettingOn: $sessionSettings.isLidarDebugEnabled)
                
                SettingsToggleButton(setting: .multiUser, isSettingOn: $sessionSettings.isMultiuserEnabled)
                
            }
        }
        .padding(.top, 35)
    }
}

struct SettingsToggleButton: View {
    let setting: Setting
    @Binding var isSettingOn: Bool
    var body: some View {
        Button(action: {
            self.isSettingOn.toggle()
            print("\(#file) - \(setting): \(self.isSettingOn)")
            
        }) {
            VStack {
                Image(systemName: setting.systemIconName)
                    .font(.system(size: 35))
                    .foregroundColor(self.isSettingOn ? .green : Color(UIColor.secondaryLabel))
                    .buttonStyle(PlainButtonStyle())
                Text(setting.label)
                    .font(.system(size: 17, weight: .medium, design: .default))
                    .foregroundColor(self.isSettingOn ? Color(UIColor.label) : Color(UIColor.secondaryLabel))
                    .padding(.top, 5)
                
            }
        }
        .frame(width: 100, height: 100)
        .background(Color(UIColor.secondarySystemFill))
        .cornerRadius(20.0)
    }
}

struct SessionSettingsView: View {
    @Binding var isSettingsShown: Bool
    var body: some View {
        NavigationView {
                SettingsGrid()
                    .navigationBarTitle(Text("Settings"), displayMode: .inline)
                    .navigationBarItems(trailing:
                                            Button(action: {
                                                
                                            }) {
                                                
                                            }
                    )
            }
            .navigationBarTitle(Text("Settings"), displayMode: .large)
            .navigationBarItems(trailing:
                                    Button(action: {
                                        self.isSettingsShown.toggle()
                                    }) {
                                        Text("Done").bold()
                                    })
    
    }
}
    
