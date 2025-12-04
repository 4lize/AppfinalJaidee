//
//  OCRViewModel.swift
//  Jaidee
//
//  Created by Teerapat Kuanphuek on 4/12/2568 BE.
//

import SwiftUI
import Vision
import UIKit
import Combine

@MainActor
final class OCRViewModel: ObservableObject {
    @Published var recognizedText: String = ""
    @Published var transactionId: String = ""
    @Published var amount: String = ""
    @Published var senderName: String = ""
    @Published var stimestamp: Date = Date()
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?

    // เรียกใช้หลังผู้ใช้เลือก UIImage
    func process(image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        guard let cgImage = image.cgImage else {
            errorMessage = "ไม่สามารถอ่านภาพได้"
            return
        }

        do {
            let text = try await recognizeText(in: cgImage)
            recognizedText = text

            // ทำ normalization ก่อน parse
            let normalized = normalizeDigitsThaiToArabic(text)
            let parsed = parseSlipText(normalized)

            transactionId = parsed["transactionId"] ?? ""
            amount = parsed["amount"] ?? ""
            senderName = parsed["senderName"] ?? ""
            if let ts = parsed["stimestamp"], let date = iso8601Date(from: ts) {
                stimestamp = date
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recognizeText(in cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines: [String] = observations.compactMap { obs in
                    obs.topCandidates(1).first?.string
                }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.02
            // ไทย/อังกฤษ
            request.recognitionLanguages = ["th-TH", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // แปลงเลขไทย -> อารบิก และลบช่องว่างพิเศษ
    private func normalizeDigitsThaiToArabic(_ text: String) -> String {
        let thaiToArabic: [Character: Character] = [
            "๐":"0","๑":"1","๒":"2","๓":"3","๔":"4","๕":"5","๖":"6","๗":"7","๘":"8","๙":"9"
        ]
        let mapped = text.map { thaiToArabic[$0] ?? $0 }
        // ลบ zero-width / คั่นบรรทัดผิดปกติที่อาจมาจาก OCR
        return String(mapped).replacingOccurrences(of: "\u{200B}", with: "")
    }

    // MARK: - Parsing
    func parseSlipText(_ text: String) -> [String: String] {
        var result: [String: String] = [:]

        // 1) เลขที่การทำธุรกรรม อัลฟานิวเมอริก 12–20 ตัว
        // ก่อนอื่น ลองหาแบบมีคีย์กำกับ (label-based)
        if let labeledId = extractTransactionId(afterLabelsIn: text) {
            result["transactionId"] = labeledId
        } else {
            // แบบ compact: ลบทุกอย่างที่ไม่ใช่อัลฟานิวเมอริกหรือขึ้นบรรทัด แล้วจับกลุ่ม 12–20 ตัว
            let compactAlphaNum = text.replacingOccurrences(of: "[^A-Za-z0-9\\n]", with: "", options: .regularExpression)
            if let idA = matchRegex(compactAlphaNum, pattern: #"(?m)(?<![A-Za-z0-9])[A-Za-z0-9]{12,20}(?![A-Za-z0-9])"#) {
                result["transactionId"] = idA
            } else if let idB = matchRegex(text, pattern: #"(?<![A-Za-z0-9])[A-Za-z0-9](?:[\s-]?[A-Za-z0-9]){11,19}(?![A-Za-z0-9])"#) {
                // เผื่อ OCR แยกด้วยช่องว่าง/ขีด ให้ลบตัวคั่นออกให้เหลืออัลฟานิวเมอริกล้วน
                let onlyAlphaNum = idB.replacingOccurrences(of: "[^A-Za-z0-9]", with: "", options: .regularExpression)
                result["transactionId"] = onlyAlphaNum
            }
        }

        // 2) จำนวนเงิน: รองรับ 1,234.56 หรือ 1234.56 หรือ 1.00 ฯลฯ
        if let amt = matchRegex(text, pattern: #"(?:[0-9]{1,3}(?:,[0-9]{3})*|[0-9]+)\.[0-9]{2}"#) {
            result["amount"] = amt.replacingOccurrences(of: ",", with: "")
        } else if let amtInt = matchRegex(text, pattern: #"(?:[0-9]{1,3}(?:,[0-9]{3})*|[0-9]+)(?!\.)"#) {
            // กรณีไม่มีทศนิยม (บางสลิป) เติม .00 ให้
            let cleaned = amtInt.replacingOccurrences(of: ",", with: "")
            result["amount"] = cleaned + ".00"
        }

        // 3) วันเวลาโอน
        if let ts = parseTimestamp(text) {
            // เก็บในรูปแบบ ISO8601 string เพื่อส่งกลับใน dictionary
            result["stimestamp"] = iso8601String(from: ts)
        }

        // 4) ชื่อผู้โอน: มองหาหลังคีย์เวิร์ด
        if let name = extractName(text) {
            result["senderName"] = name
        }

        return result
    }

    private func matchRegex(_ text: String, pattern: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex?.firstMatch(in: text, options: [], range: range),
           let r = Range(match.range, in: text) {
            return String(text[r])
        }
        return nil
    }

    private func extractTransactionId(afterLabelsIn text: String) -> String? {
        // คีย์ที่ผู้ใช้ต้องการรองรับ
        let labels = [
            "รหัสอ้างอิง",
            "เลขที่อ้างอิง",
            "หมายเลขรายการ",
            "เลขที่ธุรกรรม",
            "เลขที่รายการ",
            "รหัสธุรกรรม",
            "Reference No.",
            "Transaction ID"
        ]

        // สร้างแพทเทิร์นหา label แล้วตามด้วยตัวคั่น (: - — space) และค่า
        // ดึงเฉพาะส่วนในบรรทัดเดียวกันหลัง label
        // จากนั้นคัดกรองค่าให้เหลืออัลฟานิวเมอริก (ยอมให้มีช่องว่าง/ขีดคั่นระหว่างกลาง)
        for label in labels {
            // escape label for regex safely
            let escaped = NSRegularExpression.escapedPattern(for: label)
            // ค้นหาในแบบ case-insensitive และเฉพาะบรรทัดเดียว
            // กลุ่ม 1: เนื้อหาหลัง label ถึงจบไลน์
            let pattern = "(?im)^\(escaped)\\s*[:\\-–—]?\\s*(.+)$"
            if let line = matchRegex(text, pattern: pattern) {
                // line ตอนนี้คือทั้งบรรทัดหลัง label
                // หาโทเคนที่เป็นอัลฟานิวเมอริก (อาจมีคั่นด้วยช่องว่าง/ขีด)
                if let token = matchRegex(line, pattern: #"(?i)[A-Za-z0-9](?:[ \-]?[A-Za-z0-9]){11,}"#) {
                    // ลบตัวคั่นที่ไม่ใช่อัลฟานิวเมอริก
                    let normalized = token.replacingOccurrences(of: "[^A-Za-z0-9]", with: "", options: .regularExpression)
                    // ตรวจความยาว 12–20
                    if (12...20).contains(normalized.count) {
                        return normalized
                    }
                }
            }
        }
        return nil
    }

    // MARK: - New flexible timestamp parsing (split date and time patterns)
    private func parseTimestamp(_ text: String) -> Date? {
        // ใช้ hints เดิมเพื่อกรองบรรทัดที่น่าจะมีวันเวลา
        let hints = ["เวลา", "วันที่", "วันเวลา", "Time", "Date", "Date/Time", "Transaction Date", "Transaction Time", "น.", "ชำระเงินสำเร็จ"]
        let allLines = text.split(separator: "\n").map { String($0) }
        var candidateLines: [String] = []
        for line in allLines {
            let l = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if l.isEmpty { continue }
            if hints.contains(where: { l.localizedCaseInsensitiveContains($0) }) {
                candidateLines.append(l)
            }
        }
        if candidateLines.isEmpty {
            candidateLines = allLines
        }

        // ลองทีละบรรทัด: แยกจับ date กับ time แล้วประกอบ
        for line in candidateLines {
            // Normalize เลขไทยให้เป็นอารบิกก่อน
            let normalizedLine = normalizeDigitsThaiToArabic(line)

            // พยายามดึง date components
            guard let dateComp = extractDateComponents(from: normalizedLine) else {
                // ถ้าไม่มีวัน ให้ลองไปบรรทัดถัดไป
                continue
            }

            // พยายามดึง time components จากบรรทัดเดียวกัน (ถ้าไม่เจอจะเป็น nil)
            let timeComp = extractTimeComponents(from: normalizedLine)

            if let date = buildDate(day: dateComp.day, month: dateComp.month, year: dateComp.year, hour: timeComp?.hour, minute: timeComp?.minute) {
                return date
            }
        }

        // ถ้าไม่เจอเลย ลอง fallback: รวมข้อความทั้งก้อนเพื่อหา date และ time (บางสลิปแยกคนละบรรทัด)
        let whole = normalizeDigitsThaiToArabic(text)
        if let dateComp = extractDateComponents(from: whole) {
            let timeComp = extractTimeComponents(from: whole)
            if let date = buildDate(day: dateComp.day, month: dateComp.month, year: dateComp.year, hour: timeComp?.hour, minute: timeComp?.minute) {
                return date
            }
        }

        return nil
    }

    // แผนที่ชื่อเดือนภาษาไทย (ย่อ/เต็ม) -> หมายเลขเดือน
    private var thaiMonthMap: [String: Int] {
        [
            "ม.ค.": 1, "มกราคม": 1,
            "ก.พ.": 2, "กุมภาพันธ์": 2,
            "มี.ค.": 3, "มีนาคม": 3,
            "เม.ย.": 4, "เมษายน": 4,
            "พ.ค.": 5, "พฤษภาคม": 5,
            "มิ.ย.": 6, "มิถุนายน": 6,
            "ก.ค.": 7, "กรกฎาคม": 7,
            "ส.ค.": 8, "สิงหาคม": 8,
            "ก.ย.": 9, "กันยายน": 9,
            "ต.ค.": 10, "ตุลาคม": 10,
            "พ.ย.": 11, "พฤศจิกายน": 11,
            "ธ.ค.": 12, "ธันวาคม": 12
        ]
    }

    // ดึง date components: รองรับตัวเลขล้วนและเดือนไทย (ย่อ/เต็ม), รวมทั้ง yyyy-MM-dd, dd/MM/yyyy, d-M-yy ฯลฯ
    private func extractDateComponents(from text: String) -> (day: Int, month: Int, year: Int)? {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) yyyy-MM-dd หรือ yyyy/MM/dd หรือ yyyy.M.d
        if let m = firstMatch(s, pattern: #"(?<!\d)(\d{4})[\/\-\.\s](\d{1,2})[\/\-\.\s](\d{1,2})(?!\d)"#) {
            if let y = Int(m[1]), let mm = Int(m[2]), let d = Int(m[3]) {
                let year = adjustBEIfNeeded(year: y)
                if (1...12).contains(mm), (1...31).contains(d) {
                    return (d, mm, year)
                }
            }
        }

        // 2) dd-MM-yyyy / d/M/yyyy / dd.MM.yyyy
        if let m = firstMatch(s, pattern: #"(?<!\d)(\d{1,2})[\/\-\.\s](\d{1,2})[\/\-\.\s](\d{2,4})(?!\d)"#) {
            if let d = Int(m[1]), let mm = Int(m[2]), let yRaw = Int(m[3]) {
                let year = adjustBEIfNeeded(year: normalizeYear(yRaw))
                if (1...12).contains(mm), (1...31).contains(d) {
                    return (d, mm, year)
                }
            }
        }

        // 3) เดือนไทย (ย่อ/เต็ม): "12 ก.พ. 2568", "1 มีนาคม 68", อนุโลมช่องว่าง
        // หมายเหตุ: ใช้ alternation จาก key ทั้งหมดของ thaiMonthMap แบบ escape
        let monthAlternatives = thaiMonthMap.keys
            .sorted { $0.count > $1.count } // จับคำยาวก่อน
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        let patternThaiMonth = #"(?<!\d)(\d{1,2})\s+(\#(monthAlternatives))\s+(\d{2,4})(?!\d)"#
        if let m = firstMatch(s, pattern: patternThaiMonth) {
            if let d = Int(m[1]) {
                let monthName = m[2]
                let mm = thaiMonthMap[monthName] ?? 0
                if let yRaw = Int(m[3]) {
                    let year = adjustBEIfNeeded(year: normalizeYear(yRaw))
                    if mm >= 1 && mm <= 12 && (1...31).contains(d) {
                        return (d, mm, year)
                    }
                }
            }
        }

        // 4) รูปแบบ dd MMM yyyy ภาษาอังกฤษ (กันกรณี OCR จับเป็น en)
        // เช่น "12 Mar 2025" หรือ "1 Sep 25"
        if let m = firstMatch(s, pattern: #"(?i)(?<!\d)(\d{1,2})\s+([A-Za-z]{3,})\s+(\d{2,4})(?!\d)"#) {
            if let d = Int(m[1]) {
                let engMonth = m[2].prefix(3).lowercased()
                let engMap = ["jan":1,"feb":2,"mar":3,"apr":4,"may":5,"jun":6,"jul":7,"aug":8,"sep":9,"oct":10,"nov":11,"dec":12]
                if let mm = engMap[engMonth], let yRaw = Int(m[3]) {
                    let year = adjustBEIfNeeded(year: normalizeYear(yRaw))
                    if (1...12).contains(mm), (1...31).contains(d) {
                        return (d, mm, year)
                    }
                }
            }
        }

        return nil
    }

    // ดึง time components: รองรับ HH:mm, HH.mm, HH mm และ optional "น."
    private func extractTimeComponents(from text: String) -> (hour: Int, minute: Int)? {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) HH:mm หรือ H:mm
        if let m = firstMatch(s, pattern: #"(?<!\d)(\d{1,2})\:(\d{2})(?:\s*น\.)?(?!\d)"#) {
            if let h = Int(m[1]), let min = Int(m[2]), (0...23).contains(h), (0...59).contains(min) {
                return (h, min)
            }
        }
        // 2) HH.mm หรือ H.mm
        if let m = firstMatch(s, pattern: #"(?<!\d)(\d{1,2})\.(\d{2})(?:\s*น\.)?(?!\d)"#) {
            if let h = Int(m[1]), let min = Int(m[2]), (0...23).contains(h), (0...59).contains(min) {
                return (h, min)
            }
        }
        // 3) HH mm (เว้นวรรค)
        if let m = firstMatch(s, pattern: #"(?<!\d)(\d{1,2})\s+(\d{2})(?:\s*น\.)?(?!\d)"#) {
            if let h = Int(m[1]), let min = Int(m[2]), (0...23).contains(h), (0...59).contains(min) {
                return (h, min)
            }
        }
        return nil
    }

    // สร้าง Date จาก components (ถ้าไม่พบเวลา ให้ default 00:00)
    private func buildDate(day: Int, month: Int, year: Int, hour: Int?, minute: Int?) -> Date? {
        var comps = DateComponents()
        comps.calendar = Calendar.current
        comps.timeZone = TimeZone.current
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour ?? 0
        comps.minute = minute ?? 0
        return comps.date
    }

    // ปรับปี พ.ศ. -> ค.ศ. ถ้าปีเกิน 2400
    private func adjustBEIfNeeded(year: Int) -> Int {
        return year > 2400 ? (year - 543) : year
    }

    // ปี 2 หลัก -> 4 หลัก (สมมติ 00...79 = 2000-2079, 80...99 = 1980-1999)
    private func normalizeYear(_ y: Int) -> Int {
        if y < 100 {
            return y >= 80 ? (1900 + y) : (2000 + y)
        }
        return y
    }

    // firstMatch ที่คืนทั้งกลุ่มย่อยเป็น array (index 0 = ทั้งแมตช์, 1.. = capture groups)
    private func firstMatch(_ text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        var results: [String] = []
        for i in 0..<match.numberOfRanges {
            if let r = Range(match.range(at: i), in: text) {
                results.append(String(text[r]))
            } else {
                results.append("")
            }
        }
        return results
    }

    private func iso8601String(from date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    private func iso8601Date(from iso: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: iso)
    }

    private func extractName(_ text: String) -> String? {
        // คีย์เวิร์ดที่พบบ่อยในสลิปไทย/อังกฤษ
        let keys = ["ผู้โอน", "ชื่อผู้โอน", "จาก", "From", "Sender", "ผู้สั่งจ่าย","นาย","นาง","นางสาว"]
        for key in keys {
            if let range = text.range(of: key, options: .caseInsensitive) {
                let after = text[range.upperBound...]
                // ตัดบรรทัดแรกหลังคีย์เวิร์ด
                if let firstLine = after.split(separator: "\n").first {
                    let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        // ลบสัญลักษณ์/คั่นที่ไม่จำเป็น
                        let cleaned = trimmed.replacingOccurrences(of: #"^[\:\-\–\—\s]+"#, with: "", options: .regularExpression)
                        return cleaned
                    }
                }
            }
        }
        return nil
    }
}

#Preview {
    Text("OCRViewModel Preview")
}
