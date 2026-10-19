//
//  Double++.swift
//  Quick3D
//
//  Created by MOR on 20/1/25.
//

import Foundation

extension Double {
    var fraction: (num: Int, den: Int) {
        // 1. Kiểm tra nếu số là NaN hoặc Vô cực
        guard self.isFinite else {
            return (Int.max, 1) // Hoặc xử lý tùy ý bạn
        }
        
        // 2. Kiểm tra nếu số quá lớn vượt quá khả năng chứa của Int
        if self > Double(Int.max) {
            return (Int.max, 1)
        }
        if self < Double(Int.min) {
            return (Int.min, 1)
        }
        
        let eps: Double = 1.0E-6
        var x = self
        var a = floor(x)
        
        // 3. Cast an toàn sau khi đã kiểm tra bounds
        var (h1, k1, h, k) = (1, 0, Int(a), 1)
        
        // Loop tính toán phân số liên tục
        while x - a > eps * Double(k) * Double(k) {
            x = 1.0 / (x - a)
            a = floor(x)
            
            // 4. Kiểm tra tràn số (Overflow) trước khi nhân cộng
            // Công thức: h_new = h1 + a * h
            // Nếu a hoặc h quá lớn, phép nhân sẽ crash app
            let aInt = Int(a)
            
            // Dùng arithmetic báo lỗi để tránh crash trong vòng lặp
            let (multResult, overflowMult) = h.multipliedReportingOverflow(by: aInt)
            let (newH, overflowAdd) = h1.addingReportingOverflow(multResult)
            
            if overflowMult || overflowAdd {
                break // Dừng lại nếu tử số quá lớn, trả về kết quả tốt nhất hiện có
            }
            
            let (multResultK, overflowMultK) = k.multipliedReportingOverflow(by: aInt)
            let (newK, overflowAddK) = k1.addingReportingOverflow(multResultK)
            
            if overflowMultK || overflowAddK {
                break // Dừng lại nếu mẫu số quá lớn
            }
            
            (h1, k1, h, k) = (h, k, newH, newK)
        }
        
        return (h, k)
    }
    
//    var fraction: (num : Int, den : Int) {
//        let eps : Double = 1.0E-6
//        var x = self
//        var a = floor(x)
//        var (h1, k1, h, k) = (1, 0, Int(a), 1)
//
//        while x - a > eps * Double(k) * Double(k) {
//            x = 1.0/(x - a)
//            a = floor(x)
//            (h1, k1, h, k) = (h, k, h1 + Int(a) * h, k1 + Int(a) * k)
//        }
//        return (h, k)
//    }
    
    var fractionString: String {
        var x = self
        x = self.rounding()
        let f = x.fraction
        return "\(f.num)/\(f.den)"
    }
    
    var radians: Double {
        self * .pi / 180.0
    }
    
    var degrees: Double {
        self * 180.0 / .pi
    }
    
    func rounding(places: Int = 5) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}
