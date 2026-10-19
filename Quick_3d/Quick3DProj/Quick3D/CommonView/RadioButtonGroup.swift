//
//  RadioButtonGroup.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 02/06/2022.
//

import SwiftUI

struct RadioButton: View {
    let id: String
    let callback: (String) -> ()
    let isSelected : Bool
    let size: CGFloat
    let color: Color
    let direction: RadioButtonGroup.Direction
    private let isIPhone = UIDevice.current.isIphone
    @EnvironmentObject var userManager: UserManager

    init(
        _ id: String,
        callback: @escaping (String) -> (),
        isSelected: Bool,
        color: Color = Color.white,
        direction: RadioButtonGroup.Direction
    ) {
        self.id = id
        self.size = isIPhone ? 15 : 25
        self.color = color
        self.isSelected = isSelected
        self.callback = callback
        self.direction = direction
    }

    var body: some View {
        Button(action:{
            self.callback(self.id)
        }) {
            if direction == .horizon {
                HStack(alignment: .center, spacing: isIPhone ? 5 : 10) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "circle")
                        .renderingMode(.original)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .foregroundColor(userManager.setting.textColor)

                    Text(id)
                        .font(isIPhone ? .body : .title3)
                        .foregroundColor(userManager.setting.textColor)

                    Spacer()
                }.foregroundColor(self.color)
            } else {
                VStack(alignment: .center) {
                    Text(id)
                        .font(isIPhone ? .body : .title3)
                        .foregroundColor(userManager.setting.textColor)

                    Image(systemName: isSelected ? "checkmark.rectangle.fill" : "square")
                        .renderingMode(.original)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size)
                        .foregroundColor(userManager.setting.textColor)

                }
                .foregroundColor(self.color)
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 30))
            }
        }
        .foregroundColor(self.color)
    }
}

struct RadioButtonGroup: View {
    enum Direction {
        case vertical
        case horizon
    }

    let items : [String]
    let direction: Direction
    @State var selectedIndex = -1
    let callback: (Int) -> ()

    var body: some View {
        if direction == .horizon {
            VStack {
                ForEach(0..<items.count, id: \.self) { index in
                    RadioButton(self.items[index], callback: self.radioGroupCallback, isSelected: index == selectedIndex, direction: direction)
                }
            }
        } else {
            HStack {
                ForEach(0..<items.count, id: \.self) { index in
                    RadioButton(self.items[index], callback: self.radioGroupCallback, isSelected: index == selectedIndex, direction: direction)
                }
            }
        }
    }

    func radioGroupCallback(id: String) {
        let index = items.firstIndex(of: id)!
        selectedIndex = index
        callback(index)
    }
}

