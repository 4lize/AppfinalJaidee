//
//  UIstyles.swift
//  Jaidee
//
//  Created by Phawatkun Chokanannithi on 7/12/2568 BE.
//

import SwiftUI

// MARK: - สีหลักของแอป Jaidee
extension Color {
    /// สีฟ้าเข้มที่ใช้ใน Header ทั้งหมด
    static let primaryBlue = Color(red: 0/255, green: 71/255, blue: 155/255)
}


// MARK: - Rounded Corner เฉพาะด้าน
/// ใช้สำหรับทำมุมโค้งเฉพาะบางด้าน เช่น header แบบโค้งด้านล่าง
struct RoundedCorner: Shape {
    var radius: CGFloat = 16
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
