
extension String {
    func forcedFormatNumber(maxLength: Int = 10) -> String {
        // Giới hạn độ dài tối đa
        let truncated = String(self.prefix(maxLength))
        
        var hasDecimal = false
        var result = ""
        
        for (index, char) in truncated.enumerated() {
            // Cho phép dấu trừ nếu ở vị trí đầu tiên
            if char == "-" && index == 0 {
                result.append(char)
            }
            // Cho phép số
            else if char.isNumber {
                result.append(char)
            }
            // Cho phép một dấu chấm duy nhất
            else if char == "." && !hasDecimal {
                result.append(char)
                hasDecimal = true
            }
        }
        
        return result
    }
}
