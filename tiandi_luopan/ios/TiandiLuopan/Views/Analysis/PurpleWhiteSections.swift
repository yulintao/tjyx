import SwiftUI

/// 太岁 / 岁破 / 三煞 小标签。
struct PurpleWhiteTagPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .adaptiveFont(size: 10, weight: .bold)
                .foregroundColor(.black)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(color)
                .cornerRadius(4)
            Text(value)
                .adaptiveFont(size: 10, weight: .medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.08))
        .cornerRadius(6)
    }
}

/// 九宫单格：宫位名 + 冲犯标签 + 年飞星大字 + 月飞星与星名。
struct PurpleWhitePalaceCellView: View {
    let item: PurpleWhitePalaceItem
    let isFacing: Bool
    var isSelected: Bool = false
    var isRoomy: Bool = false
    @ObservedObject private var lang = LocalizationManager.shared

    var body: some View {
        // Both annual and monthly Five Yellow can affect the current palace;
        // the chart's advice uses the same rule so the visual warning cannot
        // disagree with the detail text.
        let isDanger = item.isDanger25 || item.yearGuestStar == 5 || item.monthGuestStar == 5
        let isJi = [1, 4, 6, 8, 9].contains(item.yearGuestStar)
        let strokeColor = isSelected
            ? Color(red: 0.95, green: 0.85, blue: 0.45)
            : (isFacing ? Color.yanCyan : (isDanger ? Color.red : (isJi ? Color.green.opacity(0.5) : Color.white.opacity(0.12))))
        let bgColor = isDanger
            ? Color.red.opacity(0.12)
            : (isJi ? Color.green.opacity(0.06) : Color(red: 0.12, green: 0.13, blue: 0.18))

        VStack {
            HStack {
                Text(item.direction)
                    .adaptiveFont(size: 10, weight: .bold)
                    .foregroundColor(.white)
                Spacer()
                if item.isTaiSui {
                    Text(lang.t("tag_taisui"))
                        .adaptiveFont(size: 8, weight: .bold)
                        .foregroundColor(.red)
                } else if item.isSanSha {
                    Text(lang.t("tag_sansha"))
                        .adaptiveFont(size: 8, weight: .bold)
                        .foregroundColor(.purple)
                }
                if isFacing {
                    Image(systemName: "location.north.fill")
                        .adaptiveFont(size: 8, weight: .bold)
                        .foregroundColor(.yanCyan)
                }
            }

            Spacer(minLength: 2)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(item.yearGuestStar)")
                    .adaptiveFont(size: 20, weight: .bold, design: .serif)
                    .foregroundColor(isDanger ? Color.red : (isJi ? Color(red: 0.95, green: 0.85, blue: 0.45) : Color.white.opacity(0.7)))

                Text("\(lang.t("tag_month_prefix"))\(item.monthGuestStar)")
                    .adaptiveFont(size: 9)
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer(minLength: 2)

            Text(item.starName)
                .adaptiveFont(size: 8)
                .foregroundColor(isDanger ? Color.red : Color.white.opacity(0.65))
                .lineLimit(1)
        }
        .padding(isRoomy ? 10 : 6)
        .aspectRatio(1.0, contentMode: .fit)
        .background(bgColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(strokeColor, lineWidth: isDanger ? 1.5 : 1)
        )
    }
}

/// 选中宫位的流年/流月客星详解、白话速断与调理打卡。
struct PurpleWhitePalaceDetailCard: View {
    let item: PurpleWhitePalaceItem
    let isFacing: Bool
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var retention = RetentionServiceManager.shared
    @ObservedObject private var lang = LocalizationManager.shared

    var body: some View {
        let isDanger = item.isDanger25 || item.yearGuestStar == 5 || item.monthGuestStar == 5
        let isJi = [1, 4, 6, 8, 9].contains(item.yearGuestStar) && !isDanger
        let plainSummary = PurpleWhiteCopy.plainSummary(
            item: item,
            isDanger: isDanger,
            isJi: isJi,
            language: lang.effectiveLanguage
        )
        let remedyId = "pw_\(item.palaceId)"
        let inRemedy = retention.remedyTasks.contains(where: { $0.id == remedyId })

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: isDanger ? "exclamationmark.triangle.fill" : "sparkles")
                    .foregroundColor(isDanger ? .red : Color(red: 0.95, green: 0.85, blue: 0.45))
                Text(item.palaceName)
                    .adaptiveFont(size: 13, weight: .bold)
                    .foregroundColor(.white)
                Text("· \(item.starName)")
                    .adaptiveFont(size: 12, weight: .semibold)
                    .foregroundColor(isDanger ? .red : Color.yanCyan)
                Spacer()
                Button(action: {
                    retention.toggleRemedyTask(
                        id: remedyId,
                        palaceDirection: item.palaceName,
                        title: item.starName,
                        remedyAction: plainSummary
                    )
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: inRemedy ? "checkmark.circle.fill" : "plus.circle")
                            .adaptiveFont(size: 9)
                        Text(PurpleWhiteCopy.remedyLabel(inRemedy: inRemedy, language: lang.effectiveLanguage))
                            .adaptiveFont(size: 9, weight: .bold)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(inRemedy ? Color.green.opacity(0.22) : Color.yanCyan.opacity(0.18))
                    .foregroundColor(inRemedy ? .green : Color.yanCyan)
                    .cornerRadius(5)
                }
                .buttonStyle(PlainButtonStyle())
                Text("\(item.yearGuestStar) / \(lang.t("tag_month_prefix"))\(item.monthGuestStar)")
                    .adaptiveFont(size: 11, weight: .bold, design: .monospaced)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            }

            Text(plainSummary)
                .adaptiveFont(size: 11, weight: .semibold)
                .foregroundColor(isDanger ? Color.orange : (isJi ? Color.green : Color(red: 0.95, green: 0.85, blue: 0.45)))
                .fixedSize(horizontal: false, vertical: true)

            if iap.hasUnlockedVIP {
                DisclosureGroup(lang.t("xkd_evidence")) {
                    Text(item.advice)
                        .adaptiveFont(size: 12)
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(3)
                }
                .adaptiveFont(size: 12)
                .foregroundColor(Color.yanCyan)
            }
        }
        .padding(12)
        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isDanger ? Color.red.opacity(0.5) : (isFacing ? Color.yanCyan.opacity(0.5) : Color.white.opacity(0.1)), lineWidth: 1)
        )
    }
}

/// 未解锁时的能力预览卡。
struct PurpleWhiteVIPPreviewCard: View {
    let onUnlock: () -> Void
    @ObservedObject private var lang = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .adaptiveFont(size: 16)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text(lang.t("privilege_purplewhite_title"))
                    .adaptiveFont(size: 14, weight: .bold)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Spacer()
                Text(lang.t("vip_badge_title"))
                    .adaptiveFont(size: 10, weight: .bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.2))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    .cornerRadius(4)
            }

            Text(lang.t("privilege_purplewhite_desc"))
                .adaptiveFont(size: 11)
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(3)

            Divider().background(Color.white.opacity(0.1))

            Text("🌟 \(lang.t("privilege_pw_feature_title"))")
                .adaptiveFont(size: 12, weight: .semibold)
                .foregroundColor(Color.yanCyan)

            VStack(alignment: .leading, spacing: 6) {
                Text("• \(lang.t("privilege_pw_bullet_1"))")
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.75))
                Text("• \(lang.t("privilege_pw_bullet_2"))")
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.75))
                Text("• \(lang.t("privilege_pw_bullet_3"))")
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.75))
            }

            Spacer(minLength: 8)

            Button(action: onUnlock) {
                HStack {
                    Spacer()
                    Image(systemName: "crown.fill")
                    Text(lang.t("unlock_vip_now"))
                    Spacer()
                }
                .adaptiveFont(size: 12, weight: .bold)
                .padding(.vertical, 8)
                .background(Color(red: 0.83, green: 0.68, blue: 0.21))
                .foregroundColor(.black)
                .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
    }
}

/// 该页所有需要按语言拼写的短文，集中在一处，避免散落在多个视图里。
enum PurpleWhiteCopy {

    static func remedyLabel(inRemedy: Bool, language: AppLanguage) -> String {
        switch language {
        case .en: return inRemedy ? "Tracked" : "+ Track"
        case .zhHant: return inRemedy ? "已入清單" : "+ 調理打卡"
        case .ja: return inRemedy ? "登録済" : "+ 化殺記録"
        case .ko: return inRemedy ? "등록됨" : "+ 비보체크"
        case .vi: return inRemedy ? "Đã lưu" : "+ Theo dõi"
        case .th: return inRemedy ? "บันทึกแล้ว" : "+ ติดตาม"
        case .id: return inRemedy ? "Tersimpan" : "+ Lacak"
        case .auto, .zhHans: return inRemedy ? "已入清单" : "+ 调理打卡"
        }
    }

    static func plainSummary(
        item: PurpleWhitePalaceItem,
        isDanger: Bool,
        isJi: Bool,
        language: AppLanguage
    ) -> String {
        switch language {
        case .en:
            if isDanger { return "⚠️ Plain Summary: 5-Yellow/2-Black Sha lands in \(item.palaceName). Keep quiet, avoid renovation/drilling, and place metal/brass cures." }
            if isJi { return "✅ Plain Summary: Auspicious Star (\(item.starName)) visits \(item.palaceName). Activate with daily activity, lighting, or water/plants." }
            return "💡 Plain Summary: Watch for petty disputes or drain in \(item.palaceName). Keep tidy and well-lit."
        case .zhHant:
            if isDanger { return "⚠️ 【白話速斷】流年/流月五黃二黑煞星飛臨【\(item.palaceName)】，切忌動土鑽牆或放紅色地墊，宜掛銅錢/銅葫蘆化洩。" }
            if isJi { return "✅ 【白話速斷】流年吉星【\(item.starName)】飛臨【\(item.palaceName)】，主旺財喜文昌，宜常坐臥、開窗納氣或擺放催旺器物。" }
            return "💡 【白話速斷】本宮流年見【\(item.starName)】，注意防口舌是非或小破耗，保持整潔明亮即可。"
        case .ja:
            if isDanger { return "⚠️ 【平易解説】五黄・二黒の凶星が【\(item.palaceName)】に飛来。動土や赤い装飾を避け、銅銭や銅製ひょうたんで化殺してください。" }
            if isJi { return "✅ 【平易解説】吉星【\(item.starName)】が【\(item.palaceName)】に飛来。財運・文昌に吉。換気と採光を良くして活用しましょう。" }
            return "💡 【平易解説】本宮は【\(item.starName)】が巡ります。口論や小出費に注意し、整理整頓を心がけてください。"
        case .ko:
            if isDanger { return "⚠️ [쉬운 해설] 오황·이흑 살성이 【\(item.palaceName)】에 비임했습니다. 공사나 붉은 매트를 피하고 동전/동호리병으로 화살하세요." }
            if isJi { return "✅ [쉬운 해설] 유년 길성 【\(item.starName)】이 【\(item.palaceName)】에 비임해 재물과 문창이 왕성합니다. 자주 머물고 환기하세요." }
            return "💡 [쉬운 해설] 본 궁에 【\(item.starName)】이 비임하여 구설수나 작은 지출을 주의하고 밝고 깨끗이 유지하세요."
        case .vi:
            if isDanger { return "⚠️ [Tóm tắt] Sao Ngũ Hoàng/Nhị Hắc bay vào 【\(item.palaceName)】, kỵ khoan đục hoặc trải thảm đỏ; nên treo tiền đồng/hồ lô đồng hóa giải." }
            if isJi { return "✅ [Tóm tắt] Cát tinh 【\(item.starName)】 đáo 【\(item.palaceName)】, vượng tài và văn xương; nên mở cửa đón khí hoặc sinh hoạt thường xuyên." }
            return "💡 [Tóm tắt] Cung 【\(item.palaceName)】 gặp 【\(item.starName)】, lưu ý tránh thị phi nhỏ, giữ gọn gàng sáng sủa."
        case .th:
            if isDanger { return "⚠️ [สรุปเข้าใจง่าย] ดาวร้าย 5 เหลือง/2 ดำจรเข้า【\(item.palaceName)】 ห้ามเจาะทุบหรือวางพรมแดง แนะนำแขวนเหรียญทองเหลืองแก้เคล็ด" }
            if isJi { return "✅ [สรุปเข้าใจง่าย] ดาวมงคล【\(item.starName)】จรเข้า【\(item.palaceName)】 เสริมโชคลาภและการงาน แนะนำเปิดรับแสงลมและใช้งานบ่อยๆ" }
            return "💡 [สรุปเข้าใจง่าย] วังนี้พบดาว【\(item.starName)】 ระวังปากเสียงเล็กน้อย รักษาความสะอาดและแสงสว่าง"
        case .id:
            if isDanger { return "⚠️ [Ringkasan] Bintang 5-Kuning/2-Hitam di 【\(item.palaceName)】. Hindari renovasi & karpet merah; pasang koin/labu kuningan." }
            if isJi { return "✅ [Ringkasan] Bintang Keberuntungan 【\(item.starName)】 di 【\(item.palaceName)】. Aktifkan dengan pencahayaan & sirkulasi udara." }
            return "💡 [Ringkasan] Sektor 【\(item.palaceName)】 bertemu 【\(item.starName)】. Jaga tetap rapi dan terang untuk menghindari perselisihan kecil."
        case .auto, .zhHans:
            if isDanger { return "⚠️ 【白话速断】流年/流月五黄二黑煞星飞临【\(item.palaceName)】，切忌动土钻墙或放红色地垫，宜挂铜钱/铜葫芦化泄。" }
            if isJi { return "✅ 【白话速断】流年吉星【\(item.starName)】飞临【\(item.palaceName)】，主旺财喜文昌，宜常坐卧、开窗纳气或摆放催旺器物。" }
            return "💡 【白话速断】本宫流年见【\(item.starName)】，注意防口舌是非或小破耗，保持整洁明亮即可。"
        }
    }
}
