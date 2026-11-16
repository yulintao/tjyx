import SwiftUI
import Foundation
import UIKit

// MARK: - 辅助本地化文案生成器 (Settings Localization Helpers)

enum SettingsLocalizationHelpers {
    static func ownerProfileEnableTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "启用宅主本命卦人宅配卦"
        case .zhHant: return "啟用宅主本命卦人宅配卦"
        case .en: return "Enable Owner Life Gua Matching"
        case .ja: return "家主本命卦マッチングを有効化"
        case .ko: return "본명괘 매칭 활성화"
        case .vi: return "Bật Phối Quẻ Trạch Chủ"
        case .th: return "เปิดใช้การจับคู่รหัสชีวิต"
        case .id: return "Aktifkan Pencocokan Gua Pemilik"
        default: return "启用宅主本命卦人宅配卦"
        }
    }

    static func ownerBirthYearTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "出生年份与本命卦"
        case .zhHant: return "出生年份與本命卦"
        case .en: return "Birth Year & Life Gua"
        case .ja: return "生年と本命卦"
        case .ko: return "출생연도 및 본명괘"
        case .vi: return "Năm Sinh & Bản Mệnh Quái"
        case .th: return "ปีเกิดและรหัสชีวิต"
        case .id: return "Tahun Lahir & Gua"
        default: return "出生年份与本命卦"
        }
    }

    static func ownerGenderTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "性别"
        case .zhHant, .ja: return "性別"
        case .en: return "Gender"
        case .ko: return "성별"
        case .vi: return "Giới tính"
        case .th: return "เพศ"
        case .id: return "Jenis Kelamin"
        default: return "性别"
        }
    }

    static func maleLabel(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .zhHans, .zhHant, .ja: return "乾造 (男)"
        case .en: return "Male"
        case .ko: return "남성"
        case .vi: return "Nam"
        case .th: return "ชาย"
        case .id: return "Pria"
        default: return "乾造 (男)"
        }
    }

    static func femaleLabel(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .zhHans, .zhHant, .ja: return "坤造 (女)"
        case .en: return "Female"
        case .ko: return "여성"
        case .vi: return "Nữ"
        case .th: return "หญิง"
        case .id: return "Wanita"
        default: return "坤造 (女)"
        }
    }

    static func solarTermNotifyTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "二十四节气交节与九星换月提醒"
        case .zhHant: return "二十四節氣交節與九星換月提醒"
        case .en: return "Solar Term & Monthly Star Alerts"
        case .ja: return "二十四節気・月盤切替通知"
        case .ko: return "24절기 및 월반 교체 알림"
        case .vi: return "Nhắc Giao Tiết & Đổi Sao Tháng"
        case .th: return "แจ้งเตือนวันเปลี่ยนสารทและดาวประจำเดือน"
        case .id: return "Pengingat Pergantian Musim & Bintang"
        default: return "二十四节气交节与九星换月提醒"
        }
    }

    static func familySectionTitle(_ lang: LocalizationManager, count: Int) -> String {
        switch lang.effectiveLanguage {
        case .en: return "Family Members Life Gua (\(count))"
        case .zhHant: return "全家成員命卦檔案（\(count)人）"
        case .ja: return "家族全員の本命卦（\(count)名）"
        case .ko: return "가족 구성원 본명괘 (\(count)명)"
        case .vi: return "Bản Mệnh Gia Đình (\(count))"
        case .th: return "รหัสชีวิตสมาชิกครอบครัว (\(count))"
        case .id: return "Gua Anggota Keluarga (\(count))"
        default: return "全家成员命卦档案（\(count)人）"
        }
    }

    static func addFamilyMemberButton(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .en: return "+ Add Member"
        case .zhHant: return "+ 添加家庭成員"
        case .ja: return "+ 家族追加"
        case .ko: return "+ 가족 추가"
        case .vi: return "+ Thêm người"
        case .th: return "+ เพิ่มสมาชิก"
        case .id: return "+ Tambah"
        default: return "+ 添加家人"
        }
    }

    static func emptyFamilyTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .en: return "No family members added yet"
        case .zhHant: return "暫未添加家庭成員"
        case .ja: return "家族メンバーが未登録です"
        case .ko: return "등록된 가족 구성원이 없습니다"
        case .vi: return "Chưa có thành viên gia đình"
        case .th: return "ยังไม่มีสมาชิกครอบครัว"
        case .id: return "Belum ada anggota keluarga"
        default: return "暂未添加家庭成员"
        }
    }

    static func emptyFamilySubtitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .en: return "Tap to add spouse, parents, or children for life gua and smart room fit"
        case .zhHant: return "點擊添加配偶、父母或子女，智能推演全家本命卦與分房吉位"
        case .ja: return "タップして配偶者・両親・子供を追加し、部屋割を自動診断"
        case .ko: return "터치하여 배우자, 부모, 자녀를 추가하고 최적의 방 배정을 확인하세요"
        case .vi: return "Nhấn để thêm vợ/chồng, cha mẹ, con cái và tự động gợi ý phòng"
        case .th: return "แตะเพื่อเพิ่มคู่สมรส พ่อแม่ หรือบุตร เพื่อจัดห้องมงคล"
        case .id: return "Ketuk untuk menambah pasangan, orang tua, atau anak"
        default: return "点击添加配偶、父母或子女，智能推演全家本命卦与分房吉位"
        }
    }

    static func solarTermNotifyDesc(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "系统将于二十四节气交节当日及九星换月当日早 08:30 自动向您推送节气气候与当月飞星吉凶提示。"
        case .zhHant: return "系統將於二十四節氣交節當日及九星換月當日早 08:30 自動向您推送節氣氣候與當月飛星吉凶提示。"
        case .en: return "Alerts for solar term changes and monthly Flying Star shifts will be delivered at 08:30 AM on transition days."
        case .ja: return "二十四節気の交節日および九星換月の当日の朝 08:30 に、気候と飛星の吉凶通知をお届けします。"
        case .ko: return "24절기 입절일 및 월반 교체 당일 오전 08:30에 절기 기후와 당월 비성 길흉 알림을 보내드립니다."
        case .vi: return "Hệ thống sẽ gửi thông báo khí hậu tiết khí và phi tinh cát hung vào lúc 08:30 sáng ngày giao tiết."
        case .th: return "ระบบจะแจ้งเตือนการเปลี่ยนสารทและดาวบินประจำเดือนในเวลา 08:30 น. ของวันเปลี่ยนสารท"
        case .id: return "Pemberitahuan perubahan musim dan Bintang Terbang akan dikirimkan pukul 08:30 pada hari transisi."
        default: return "系统将于二十四节气交节当日及九星换月当日早 08:30 自动向您推送节气气候与当月飞星吉凶提示。"
        }
    }

    static func rateAppTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "为「天机演象」评分鼓励"
        case .zhHant: return "為「天機演象」評分鼓勵"
        case .en: return "Rate Tiandi Luopan"
        case .ja: return "アプリを評価して応援する"
        case .ko: return "앱 평가하기"
        case .vi: return "Đánh Giá Ứng Dụng"
        case .th: return "ให้คะแนนแอป"
        case .id: return "Beri Nilai Aplikasi"
        default: return "为「天机演象」评分鼓励"
        }
    }

    static func testFlightRateAlertTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .en: return "TestFlight Beta Notice"
        case .zhHant: return "TestFlight 測試版提示"
        case .ja: return "TestFlight ベータ版のご案内"
        case .ko: return "TestFlight 베타 안내"
        case .vi: return "Thông Báo TestFlight Beta"
        case .th: return "ข้อความแจ้งเตือน TestFlight"
        case .id: return "Pemberitahuan Beta TestFlight"
        case .auto, .zhHans: return "TestFlight 测试版提示"
        }
    }

    static func testFlightRateAlertMessage(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .en:
            return "You are currently running a TestFlight beta build. Under Apple's rules, the 'Submit' button in rating dialogs is disabled in TestFlight and sandbox environments. Reviews will be fully active once released on the App Store! To submit feedback now, please use the 'Send Beta Feedback' option in the TestFlight app."
        case .zhHant:
            return "當前處於 TestFlight 測試環境。依蘋果官方規則，測試版應用評分彈窗中的「提交」按鈕會被系統強制置灰，無法向 App Store 提交公開評分。正式上架後將全面開放評價！您可在 TestFlight 中點擊「發送反饋」向我們提出建議。"
        case .ja:
            return "現在 TestFlight ベータテスト環境をご利用中です。Apple の仕様により、テスト版では評価ダイアログの「送信」ボタンが無効化されており、App Store に公開評価を投稿することはできません。正式リリース後に評価が可能となります。ご意見は TestFlight の「フィードバックを送信」よりお寄せください。"
        case .ko:
            return "현재 TestFlight 베타 환경입니다. Apple의 정책에 따라 테스트 버전에서는 평가 팝업의 '제출' 버튼이 비활성화되어 App Store에 공개 평가를 등록할 수 없습니다. 정식 출시 후 평가가 가능하며, 의견은 TestFlight 앱의 '피드백 보내기'를 이용해 주시기 바랍니다."
        case .vi:
            return "Bạn đang sử dụng phiên bản thử nghiệm TestFlight. Theo quy định của Apple, nút 'Gửi' trong hộp thoại đánh giá sẽ bị vô hiệu hóa trong môi trường thử nghiệm. Đánh giá sẽ hoạt động bình thường sau khi phát hành chính thức! Bạn có thể gửi ý kiến qua mục 'Gửi phản hồi Beta' trong ứng dụng TestFlight."
        case .th:
            return "ขณะนี้คุณกำลังใช้งานเวอร์ชันทดสอบ TestFlight ตามนโยบายของ Apple ปุ่ม 'ส่ง' ในหน้าต่างให้คะแนนจะถูกปิดใช้งานในเวอร์ชันทดสอบ เมื่อเปิดตัวอย่างเป็นทางการจะสามารถส่งคะแนนได้ตามปกติ หากมีข้อเสนอแนะโปรดใช้ตัวเลือก 'ส่งความคิดเห็น' ในแอป TestFlight"
        case .id:
            return "Anda saat ini menggunakan versi beta TestFlight. Berdasarkan kebijakan Apple, tombol 'Kirim' dinonaktifkan pada versi beta. Ulasan akan dibuka penuh setelah rilis resmi di App Store. Untuk memberikan saran, silakan gunakan 'Kirim Masukan' di aplikasi TestFlight."
        case .auto, .zhHans:
            return "当前处于 TestFlight 测试环境。按苹果官方规则，测试版应用弹出的评分弹窗中「提交」按钮会被系统强制置灰，无法向 App Store 提交公开评分。正式上架后将全面开放评价！您可在 TestFlight 中点击「发送反馈」向我们提出宝贵建议。"
        }
    }

    static func notificationPermissionDeniedTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .en: return "Notification Permission Disabled"
        case .zhHant: return "通知權限未開啟"
        case .ja: return "通知が許可されていません"
        case .ko: return "알림 권한이 비활성화됨"
        case .vi: return "Chưa Bật Quyền Thông Báo"
        case .th: return "ยังไม่ได้เปิดการอนุญาตแจ้งเตือน"
        case .id: return "Izin Notifikasi Belum Diaktifkan"
        case .auto, .zhHans: return "通知权限未开启"
        }
    }

    static func notificationPermissionDeniedMessage(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .en:
            return "You previously chose 'Don't Allow' for notifications. iOS requires you to enable notifications in the Settings app. Please go to Settings to enable alerts for 24 solar terms and monthly Flying Stars."
        case .zhHant:
            return "檢測到您之前點擊了「不允許」通知，iOS 系統限制應用無法再次直接彈窗請求授權。請前往系統「設定」中為「天機演象」開啟通知權限，以便及時接收二十四節氣交節與九星換月提醒。"
        case .ja:
            return "以前「許可しない」を選択されたため、iOSの制約によりアプリ内から再要求できません。「設定」アプリを開き、天地羅盤の通知をオンにして節気交節や九星換月の通知を受け取れるようにしてください。"
        case .ko:
            return "이전에 알림을 '허용 안 함'으로 설정하여 iOS 정책상 앱에서 바로 권한을 재요청할 수 없습니다. 시스템 '설정'에서 알림을 허용하시면 24절기 교절 및 자백구성 환월 알림을 받으실 수 있습니다."
        case .vi:
            return "Bạn đã chọn 'Không cho phép' thông báo trước đó. Vui lòng vào 'Cài đặt' của thiết bị để bật thông báo cho Thiên Địa La Bàn nhằm nhận nhắc nhở giao tiết khí và Cửu Tinh đổi cục."
        case .th:
            return "คุณเคยเลือก 'ไม่อนุญาต' การแจ้งเตือนไว้ ระบบ iOS กำหนดให้ต้องเปิดในแอปการตั้งค่าของเครื่อง โปรดไปที่ 'การตั้งค่า' เพื่อเปิดการแจ้งเตือนสำหรับสารท 24 절기 และดาวบินรายเดือน"
        case .id:
            return "Anda sebelumnya memilih 'Jangan Izinkan' notifikasi. Silakan buka 'Pengaturan' perangkat dan aktifkan notifikasi untuk menerima pengingat pergantian musim dan Bintang Terbang."
        case .auto, .zhHans:
            return "检测到您之前点击了「不允许」通知，iOS 系统限制应用无法再次直接弹窗请求授权。请前往系统「设置」中为「天机演象」开启通知权限，以便及时接收二十四节气交节与九星换月提醒。"
        }
    }

    static func goToSettingsTitle(_ lang: LocalizationManager) -> String {
        switch lang.effectiveLanguage {
        case .en: return "Go to Settings"
        case .zhHant: return "前往設定"
        case .ja: return "設定へ移動"
        case .ko: return "설정으로 이동"
        case .vi: return "Đi đến Cài Đặt"
        case .th: return "ไปที่การตั้งค่า"
        case .id: return "Buka Pengaturan"
        case .auto, .zhHans: return "前往设置"
        }
    }
}
