//
//  CustomDatePicker.swift
//  Quick3D
//
//  Created by Pham Thanh Xuan on 21/12/2022.
//

import SwiftUI

struct CustomDatePicker: View {
    
    @Binding var currentDate: Date
    var otherDate: Date?
    var isToDate: Bool
    @State var  currentMonth: Int = 0
    @State var _date = Date()
    private var isIPhone: Bool {
        UIDevice.current.isIphone
    }
    @EnvironmentObject var userManager: UserManager
    
    var body: some View {
        
        VStack(spacing: 10) {
            
            // Days
            let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            
            HStack(spacing: isIPhone ? 10 : 20) {
                
                HStack(alignment: .bottom, spacing: 10) {
                    Text(extraDate()[1])
                        .foregroundColor(userManager.setting.textColor)
                    
                    Text(extraDate()[0])
                        .foregroundColor(userManager.setting.textColor)
                }
                .font(isIPhone ? .title3.bold() : .title2.bold())
                .foregroundColor(userManager.setting.textColor)
                
                Spacer()
                
                Button {
                    withAnimation(.none){ currentMonth -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2 )
                        .foregroundColor(userManager.setting.textColor)
                }
                
                Button {
                    withAnimation(.none){ currentMonth += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(userManager.setting.textColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, isIPhone ? 15 : 30)
            .padding(.bottom, isIPhone ? 5 : 10)
            
            // Day View...
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            
            //Date
            // Lazy Grid..
            let columns = Array(repeating: GridItem(.flexible()), count: 7)
            
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(extractDate()) { value in
                    CardView(value: value)
                        .background(
                            Capsule()
                                .fill(Color.pink)
                                .padding(.horizontal, 8)
                                .opacity(isSameDay(date1: value.date, date2: currentDate) ? 1 : 0)
                        )
                        .onTapGesture {
                            guard value.date <= Date() else { return }
                            if isInvalidDate(value: value){
                                return
                            }
                            currentDate = value.date
                        }
                }
            }
            .padding(.bottom, isIPhone ? 15 : 30)
        }
        .onChange(of: currentMonth) { newValue in
            // update month
            _date = getCurrentMonth()
        }
        .padding(.horizontal)
        .background(userManager.setting.themeColor)
        .cornerRadius(isIPhone ? 20 : 30)
        .onTapGesture {}
    }
    
    @ViewBuilder
    func CardView(value: DateValue) -> some View {
        
        ZStack {
            if value.day != -1 {
                Color.blue
                    .opacity((isSameDay(date1: value.date , date2: currentDate) ? 1 : 0))
                
                Text("\(value.day)")
                    .font(.system(size: isIPhone ? 17 : 22).bold())
                    .foregroundColor(
                        value.date.isGreaterThanToday ?
                        (userManager.setting.colorTheme == .light ? .gray.opacity(0.7) : .gray.opacity(0.7))
                        :
                            isInvalidDate(value: value) ? (userManager.setting.colorTheme == .light ? .gray.opacity(0.7) : .gray.opacity(0.7)) :
                            (userManager.setting.colorTheme == .light ? .black : .white)
                    )
                    .frame(maxWidth: .infinity)
                
            }
        }
        .frame(height: isIPhone ? 30 : 40, alignment: .top)
        .cornerRadius(isIPhone ? 15 : 20)
        
    }
    
    func isInvalidDate(value: DateValue ) -> Bool{
        if isToDate && otherDate != nil {
            if value.date < otherDate! {
                return true
            }
        }
        if !isToDate && otherDate != nil {
            if value.date > otherDate! {
                return true
            }
        }
        return false
    }
    
    // Checking dates
    func isSameDay(date1: Date, date2: Date) -> Bool {
        
        return Calendar.current.isDate(date1, inSameDayAs: date2)
        
    }
    
    
    // Extraing year and month for display
    func extraDate() -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY MMMM"
        
        let date = formatter.string(from: _date)
        
        return date.components(separatedBy: " ")
    }
    
    func getCurrentMonth() -> Date {
        let calendar = Calendar.current
        
        // Getting Current month date
        guard let currentMonth = calendar.date(byAdding: .month, value: self.currentMonth, to: Date()) else {
            return Date()
        }
        
        return currentMonth
    }
    
    
    func extractDate() -> [DateValue] {
        
        let calendar = Calendar.current
        
        // Getting Current month date
        let currentMonth = getCurrentMonth()
        
        var days = currentMonth.getAllDates().compactMap { date -> DateValue in
            let day = calendar.component(.day, from: date)
            let dateValue =  DateValue(day: day, date: date)
            return dateValue
        }
        
        // adding offset days to get exact week day...
        let firstWeekday = calendar.component(.weekday, from: days.first?.date ?? Date())
        
        for _ in 0..<firstWeekday - 1 {
            days.insert(DateValue(day: -1, date: Date()), at: 0)
        }
        
        return days
    }
    
}

struct DateValue: Identifiable {
    var id = UUID().uuidString
    var day: Int
    var date: Date
}
