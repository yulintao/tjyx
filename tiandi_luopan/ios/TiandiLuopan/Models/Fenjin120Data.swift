import Foundation

// MARK: - 一百二十分金数据库与吉凶分析 (PRD 6.6 & 罗盘核心第三层)

public struct FenjinItem: Identifiable {
    public var id: String { "\(mountainName)-\(index)" }
    public let mountainName: String    // 所属二十四山 (如 "子山")
    public let index: Int              // 1..5
    public let jiaziName: String       // 甲子名称 (如 "甲子", "丙子", "戊子", "庚子", "壬子")
    public let startAngle: Double      // 起始角度
    public let endAngle: Double        // 终止角度
    public let centerAngle: Double     // 中心角度
    public let grade: String           // "旺相大吉", "孤虚差错", "龟甲空亡", "平稳"
    public let isAuspicious: Bool      // 是否为可用吉度
    public let lore: String            // 秘诀断语

    public var localizedMountainName: String {
        if let mountain = Mountain24Data.shared.mountains.first(where: { $0.name == mountainName }) {
            return mountain.localizedName
        }
        return mountainName
    }

    public var localizedJiaziName: String {
        guard jiaziName.count >= 2 else { return jiaziName }
        let stemChar = String(jiaziName.prefix(1))
        let branchChar = String(jiaziName.suffix(1))
        let lang = LocalizationManager.shared.effectiveLanguage

        let stemMap: [String: [AppLanguage: String]] = [
            "甲": [.en: "Jia", .ja: "甲", .ko: "갑", .vi: "Giáp", .th: "เจี่ย", .id: "Jia"],
            "乙": [.en: "Yi", .ja: "乙", .ko: "을", .vi: "Ất", .th: "อี่", .id: "Yi"],
            "丙": [.en: "Bing", .ja: "丙", .ko: "병", .vi: "Bính", .th: "ปิ่ง", .id: "Bing"],
            "丁": [.en: "Ding", .ja: "丁", .ko: "정", .vi: "Đinh", .th: "ติง", .id: "Ding"],
            "戊": [.en: "Wu", .ja: "戊", .ko: "무", .vi: "Mậu", .th: "อู้", .id: "Wu"],
            "己": [.en: "Ji", .ja: "己", .ko: "기", .vi: "Kỷ", .th: "จี่", .id: "Ji"],
            "庚": [.en: "Geng", .ja: "庚", .ko: "경", .vi: "Canh", .th: "เกิง", .id: "Geng"],
            "辛": [.en: "Xin", .ja: "辛", .ko: "신", .vi: "Tân", .th: "ซิน", .id: "Xin"],
            "壬": [.en: "Ren", .ja: "壬", .ko: "임", .vi: "Nhâm", .th: "เหริน", .id: "Ren"],
            "癸": [.en: "Gui", .ja: "癸", .ko: "계", .vi: "Quý", .th: "กุ่ย", .id: "Gui"]
        ]
        let branchMap: [String: [AppLanguage: String]] = [
            "子": [.en: "Zi", .ja: "子", .ko: "자", .vi: "Tý", .th: "จื่อ", .id: "Zi"],
            "丑": [.en: "Chou", .ja: "丑", .ko: "축", .vi: "Sửu", .th: "โฉ่ว", .id: "Chou"],
            "寅": [.en: "Yin", .ja: "寅", .ko: "인", .vi: "Dần", .th: "อิ๋น", .id: "Yin"],
            "卯": [.en: "Mao", .ja: "卯", .ko: "묘", .vi: "Mão", .th: "เหมา", .id: "Mao"],
            "辰": [.en: "Chen", .ja: "辰", .ko: "진", .vi: "Thìn", .th: "เฉิน", .id: "Chen"],
            "巳": [.en: "Si", .ja: "巳", .ko: "사", .vi: "Tỵ", .th: "ซื่อ", .id: "Si"],
            "午": [.en: "Wu", .ja: "午", .ko: "오", .vi: "Ngọ", .th: "อู่", .id: "Wu"],
            "未": [.en: "Wei", .ja: "未", .ko: "미", .vi: "Mùi", .th: "เว่ย", .id: "Wei"],
            "申": [.en: "Shen", .ja: "申", .ko: "신", .vi: "Thân", .th: "เซิน", .id: "Shen"],
            "酉": [.en: "You", .ja: "酉", .ko: "유", .vi: "Dậu", .th: "โหย่ว", .id: "You"],
            "戌": [.en: "Xu", .ja: "戌", .ko: "술", .vi: "Tuất", .th: "ซีว์", .id: "Xu"],
            "亥": [.en: "Hai", .ja: "亥", .ko: "해", .vi: "Hợi", .th: "ไฮ่", .id: "Hai"]
        ]

        if lang == .zhHans || lang == .zhHant {
            return jiaziName
        }
        let s = stemMap[stemChar]?[lang] ?? stemChar
        let b = branchMap[branchChar]?[lang] ?? branchChar
        switch lang {
        case .en, .id: return "\(s)-\(b)"
        case .vi: return "\(s) \(b)"
        case .ko: return "\(s)\(b) (\(jiaziName))"
        case .ja: return "\(jiaziName) (\(s)\(b))"
        case .th: return "\(s)-\(b)"
        default: return jiaziName
        }
    }

    public var localizedGrade: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .auto, .zhHans:
            return grade
        case .zhHant:
            switch grade {
            case "正中分度": return "正中分度"
            case "边缘分度": return "邊緣分度"
            case "过渡分度": return "過渡分度"
            case "中界分度": return "中界分度"
            default: return "標準分度"
            }
        case .en:
            switch grade {
            case "正中分度": return "Center-Aligned Slot"
            case "边缘分度": return "Sector-Edge Slot"
            case "过渡分度": return "Transitional Slot"
            case "中界分度": return "Mid-Boundary Slot"
            default: return "Standard Slot"
            }
        case .ja:
            switch grade {
            case "正中分度": return "中心基準区分"
            case "边缘分度": return "境界近接区分"
            case "过渡分度": return "移行区分"
            case "中界分度": return "中央境界区分"
            default: return "標準区分"
            }
        case .ko:
            switch grade {
            case "正中分度": return "중심 기준 구간"
            case "边缘分度": return "경계 인접 구간"
            case "过渡分度": return "전환 구간"
            case "中界分度": return "중앙 경계 구간"
            default: return "표준 구간"
            }
        case .vi:
            switch grade {
            case "正中分度": return "Phân độ chính tâm"
            case "边缘分度": return "Phân độ cận biên"
            case "过渡分度": return "Phân độ chuyển tiếp"
            case "中界分度": return "Phân độ trung giới"
            default: return "Phân độ tiêu chuẩn"
            }
        case .th:
            switch grade {
            case "正中分度": return "ช่วงองศาศูนย์กลาง"
            case "边缘分度": return "ช่วงองศาใกล้ขอบ"
            case "过渡分度": return "ช่วงองศาเปลี่ยนผ่าน"
            case "中界分度": return "ช่วงองศาแนวแบ่งกลาง"
            default: return "ช่วงองศามาตรฐาน"
            }
        case .id:
            switch grade {
            case "正中分度": return "Slot Pusat Presisi"
            case "边缘分度": return "Slot Dekat Batas"
            case "过渡分度": return "Slot Transisi"
            case "中界分度": return "Slot Batas Tengah"
            default: return "Slot Standar"
            }
        }
    }

    /// 120 分度标尺（每格 3.0°）客观工程与传统方位术语说明（移除一切吉凶、健康、财帛与灾祸预测表述）。
    public var localizedLore: String {
        baseLocalizedLore + "\n\n" + classicalSourceNote
    }

    private var baseLocalizedLore: String {
        let firstStem = String(jiaziName.prefix(1))
        let lang = LocalizationManager.shared.effectiveLanguage
        let isCenterSlot = (firstStem == "丙" || firstStem == "丁" || firstStem == "庚" || firstStem == "辛")
        let isMidBoundary = (firstStem == "戊" || firstStem == "己")
        let isEdgeSlot = (firstStem == "甲" || firstStem == "壬")

        switch lang {
        case .en:
            if isCenterSlot {
                return "3.0° primary axial subdivision (\(localizedJiaziName)) located away from 15° sector seams. High classification stability against handheld magnetometer noise."
            } else if isMidBoundary {
                return "3.0° center-seam subdivision (\(localizedJiaziName)). Use 2.5s steady-state circular-mean sampling and True North (WMM) calibration to confirm exact architectural axis."
            } else if isEdgeSlot {
                return "3.0° sector-edge subdivision (\(localizedJiaziName)) near the 15° boundary. Minor sensor drift may cross into the adjacent sector; re-verify while level."
            } else {
                return "3.0° transitional subdivision (\(localizedJiaziName)). Verify bearing stability and magnetic environment (μT) before locking reference orientation."
            }
        case .zhHant:
            if isCenterSlot {
                return "位於 15° 方位扇區內的 3.0° 基準分度（\(localizedJiaziName)），遠離相鄰山向交界縫，手持測角時分區穩定度高，適合建築朝向記錄。"
            } else if isMidBoundary {
                return "位於 15° 扇區中線處的 3.0° 分度（\(localizedJiaziName)），建議開啟真北磁偏角校正並執行 2.5 秒穩態均值採樣復核軸線角度。"
            } else if isEdgeSlot {
                return "鄰近 15° 方位邊界線的 3.0° 分度（\(localizedJiaziName)），手持微小晃動即可能跨入相鄰分區，建議端平設備後二次復測。"
            } else {
                return "屬於 3.0° 過渡區間分度（\(localizedJiaziName)），記錄建築朝向時請同步核對環境磁場強度（μT）與水平狀態。"
            }
        case .ja:
            if isCenterSlot {
                return "15°方位区画の境界から離れた 3.0° 基準区分（\(localizedJiaziName)）です。センサー揺らぎの影響を受けにくく、建築方位の記録に適しています。"
            } else if isMidBoundary {
                return "15°区画の中央線に位置する 3.0° 区分（\(localizedJiaziName)）です。真北補正と定常平均サンプリングで軸線を再確認してください。"
            } else if isEdgeSlot {
                return "15°境界線に近接する 3.0° 区分（\(localizedJiaziName)）です。わずかな傾きで隣接区画へ跨ぐため、水平を保って再計測してください。"
            } else {
                return "3.0° の移行区分（\(localizedJiaziName)）です。磁場強度（μT）と水平状態を確認のうえ方位をロックしてください。"
            }
        case .ko:
            if isCenterSlot {
                return "15° 방위 구획 경계에서 떨어진 3.0° 중심 기준 구간(\(localizedJiaziName))입니다. 센서 흔들림에 안정적이어서 건축 방위 기록에 적합합니다."
            } else if isMidBoundary {
                return "15° 구획 중앙에 위치한 3.0° 구간(\(localizedJiaziName))입니다. 진북(WMM) 보정과 정상 상태 평균 샘플링으로 축선을 재확인하세요."
            } else if isEdgeSlot {
                return "15° 경계선에 인접한 3.0° 구간(\(localizedJiaziName))입니다. 미세한 흔들림에도 인접 구역으로 바뀔 수 있으므로 수평 유지 후 재측정하세요."
            } else {
                return "3.0° 전환 구간(\(localizedJiaziName))입니다. 방위를 잠그기 전에 자기장 세기(μT)와 수평 상태를 함께 확인하세요."
            }
        case .vi:
            if isCenterSlot {
                return "Phân độ chuẩn 3,0° (\(localizedJiaziName)) nằm xa đường biên 15°, độ ổn định cao khi đo cầm tay, phù hợp ghi nhận trục hướng công trình."
            } else if isMidBoundary {
                return "Phân độ trung tâm 3,0° (\(localizedJiaziName)). Nên bật hiệu chỉnh Bắc thực (WMM) và lấy mẫu trung bình ổn định 2,5 giây để đối chiếu."
            } else if isEdgeSlot {
                return "Phân độ cận biên 3,0° (\(localizedJiaziName)) sát ranh giới 15°; rung lắc nhẹ có thể nhảy sang cung kế bên, cần giữ thăng bằng và đo lại."
            } else {
                return "Phân độ chuyển tiếp 3,0° (\(localizedJiaziName)); hãy kiểm tra cường độ từ trường (μT) và bọt thủy trước khi khóa góc."
            }
        case .th:
            if isCenterSlot {
                return "ช่วงแบ่งละเอียด 3.0° (\(localizedJiaziName)) อยู่ห่างจากเส้นขอบ 15° มีความเสถียรสูงต่อสัญญาณรบกวน เหมาะสำหรับบันทึกแนวแกนอาคาร"
            } else if isMidBoundary {
                return "ช่วงแบ่งแนวกลาง 3.0° (\(localizedJiaziName)) แนะนำให้เปิดการปรับแก้ทิศเหนือจริง (WMM) และใช้การสุ่มค่าเฉลี่ยคงที่เพื่อทวนสอบ"
            } else if isEdgeSlot {
                return "ช่วงแบ่งใกล้ขอบ 3.0° (\(localizedJiaziName)) ใกล้เส้นแบ่ง 15° การเอียงเล็กน้อยอาจข้ามช่วงข้างเคียง ควรรักษาระดับน้ำแล้ววัดซ้ำ"
            } else {
                return "ช่วงเปลี่ยนผ่าน 3.0° (\(localizedJiaziName)) โปรดตรวจสอบความเข้มสนามแม่เหล็ก (μT) และระดับน้ำก่อนล็อกมุม"
            }
        case .id:
            if isCenterSlot {
                return "Subdivisi presisi 3,0° (\(localizedJiaziName)) jauh dari batas sektor 15°, stabil terhadap noise sensor untuk pencatatan sumbu bangunan."
            } else if isMidBoundary {
                return "Subdivisi garis tengah 3,0° (\(localizedJiaziName)). Gunakan kalibrasi Utara Sejati (WMM) dan sampling rata-rata stabil 2,5 detik untuk verifikasi."
            } else if isEdgeSlot {
                return "Subdivisi tepi 3,0° (\(localizedJiaziName)) dekat batas 15°; getaran kecil dapat berpindah sektor, pastikan rata dan ukur ulang."
            } else {
                return "Subdivisi transisi 3,0° (\(localizedJiaziName)); periksa kekuatan medan magnet (μT) dan kerataan perangkat sebelum mengunci sudut."
            }
        case .auto, .zhHans:
            if isCenterSlot {
                return "位于 15° 方位扇区内的 3.0° 基准分度（\(localizedJiaziName)），远离相邻山向交界缝，手持测角时分区稳定度高，适合建筑朝向记录。"
            } else if isMidBoundary {
                return "位于 15° 扇区中线处的 3.0° 分度（\(localizedJiaziName)），建议开启真北磁偏角校正并执行 2.5 秒稳态均值采样复核轴线角度。"
            } else if isEdgeSlot {
                return "邻近 15° 方位边界线的 3.0° 分度（\(localizedJiaziName)），手持微小晃动即可能跨入相邻分区，建议端平设备后二次复测。"
            } else {
                return "属于 3.0° 过渡区间分度（\(localizedJiaziName)），记录建筑朝向时请同步核对环境磁场强度（μT）与水平状态。"
            }
        }
    }

    private var classicalSourceNote: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            return "Reference: 360° ÷ 120 = 3.0° fine azimuth subdivision paired with traditional 60-stem-branch indexing for cultural and architectural orientation documentation."
        case .zhHant:
            return "說明：360° ÷ 120 = 3.0° 精細方位分度標尺，結合傳統干支編號用於建築測繪記錄與文化參考，不涉及任何吉凶或運勢預測。"
        case .ja:
            return "補足：360° ÷ 120 = 3.0° の精密方位区分に伝統干支ラベルを併記した測量・文化参照用の目盛です。"
        case .ko:
            return "참고: 360° ÷ 120 = 3.0° 정밀 방위 분할에 전통 간지 표기를 병기한 측량·문화 참조 눈금입니다."
        case .vi:
            return "Ghi chú: Thang chia góc tinh 360° ÷ 120 = 3,0° kết hợp ký hiệu Can Chi truyền thống cho ghi chép đo đạc và tham khảo văn hóa."
        case .th:
            return "หมายเหตุ: มาตราส่วนมุมละเอียด 360° ÷ 120 = 3.0° พร้อมรหัสอ้างอิงทางวัฒนธรรมเพื่อการบันทึกงานสำรวจอาคาร"
        case .id:
            return "Catatan: Skala subdivisi sudut presisi 360° ÷ 120 = 3,0° dengan indeks budaya tradisional untuk dokumentasi survei arsitektur."
        case .auto, .zhHans:
            return "说明：360° ÷ 120 = 3.0° 精细方位分度标尺，结合传统干支编号用于建筑测绘记录与文化参考，不涉及任何吉凶或运势预测。"
        }
    }
}

public class Fenjin120Data {
    public static let shared = Fenjin120Data()
    
    public let allFenjin: [FenjinItem]
    
    // 二十四山正针名称与起止角度 (每山 15 度，坎宫子山从 352.5° 至 7.5°)
    // 120 分度每格 3.0 度
    private let stemTypes: [String: (grade: String, ji: Bool, lore: String)] = [
        "甲": ("边缘分度", false, "位于 15° 扇区外缘，建议端平设备并复测确认跨界误差。"),
        "乙": ("过渡分度", false, "位于 3.0° 过渡区间，建议结合磁偏角与稳态均值采样复核。"),
        "丙": ("正中分度", true, "位于扇区稳定基准区内，远离 15° 边界缝，适合作为建筑朝向主参考角。"),
        "丁": ("正中分度", true, "位于扇区稳定基准区内，方位归属清晰，适合作为建筑朝向主参考角。"),
        "戊": ("中界分度", false, "位于扇区中线分隔处，建议开启真北校正并多次采样确认轴线。"),
        "己": ("中界分度", false, "位于扇区中线分隔处，建议开启真北校正并多次采样确认轴线。"),
        "庚": ("正中分度", true, "位于扇区稳定基准区内，方位归属清晰，适合作为建筑朝向主参考角。"),
        "辛": ("正中分度", true, "位于扇区稳定基准区内，远离 15° 边界缝，适合作为建筑朝向主参考角。"),
        "壬": ("边缘分度", false, "位于 15° 扇区外缘，微小倾角变化可能跨区，建议复测确认。"),
        "癸": ("过渡分度", false, "位于 3.0° 过渡区间，建议结合环境磁场强度（μT）确认读数稳定。")
    ]
    
    private init() {
        var items: [FenjinItem] = []
        let mountains = Mountain24Data.shared.mountains
        
        // Each mountain contains five same-branch 120-fen-jin degrees.
        // The previous sequential 60-cycle assigned 子山 as 甲子/乙丑/…,
        // which mixed branches inside one mountain.  Generate the valid five
        // Jiazi combinations from the mountain's three-mountain branch group.
        let branchGroups = [0, 1, 3, 4, 6, 7, 9, 10]
        let branchNames = ["子", "丑", "卯", "辰", "午", "未", "酉", "戌"]
        let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
        
        for m in mountains {
            let group = min(max(m.id / 3, 0), branchGroups.count - 1)
            let branchIndex = branchGroups[group]
            let branch = branchNames[group]
            let firstStemIndex = branchIndex % 2
            for i in 0..<5 {
                let jiazi = "\(stems[firstStemIndex + i * 2])\(branch)"
                let startA = (m.startAngle + Double(i) * 3.0).truncatingRemainder(dividingBy: 360)
                let endA = (m.startAngle + Double(i + 1) * 3.0).truncatingRemainder(dividingBy: 360)
                let centerA = (m.startAngle + Double(i) * 3.0 + 1.5).truncatingRemainder(dividingBy: 360)
                
                let firstChar = String(jiazi.prefix(1))
                let meta = stemTypes[firstChar] ?? ("平稳", false, "气场平平")
                
                items.append(FenjinItem(
                    mountainName: m.name,
                    index: i + 1,
                    jiaziName: jiazi,
                    startAngle: startA,
                    endAngle: endA,
                    centerAngle: centerA,
                    grade: meta.grade,
                    isAuspicious: meta.ji,
                    lore: meta.lore
                ))
            }
        }
        self.allFenjin = items
    }
    
    // 根据方位角实时检索匹配当前精确分金
    public func resolveFenjin(for angle: Double) -> FenjinItem {
        let normAngle = (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        for item in allFenjin {
            if item.startAngle < item.endAngle {
                if normAngle >= item.startAngle && normAngle < item.endAngle {
                    return item
                }
            } else {
                // 跨越 0°/360° 正北子山分金
                if normAngle >= item.startAngle || normAngle < item.endAngle {
                    return item
                }
            }
        }
        // The table is generated from the fixed 24-mountain data and should
        // never be empty, but keep the lookup total so a future data change
        // cannot crash the compass at runtime.
        return allFenjin.first ?? FenjinItem(
            mountainName: "子",
            index: 1,
            jiaziName: "甲子",
            startAngle: 0,
            endAngle: 3,
            centerAngle: 1.5,
            grade: "平稳",
            isAuspicious: false,
            lore: "气场平平"
        )
    }
}
