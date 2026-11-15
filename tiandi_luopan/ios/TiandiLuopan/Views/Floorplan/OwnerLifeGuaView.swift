import SwiftUI

// 家人与宅主命卦相关界面。这些类型原先写在 BaZhaiView.swift 里，
// 八宅页删除后仍被家人分房与宅主命卦提醒使用，因此原样搬到本文件。

struct OwnerGuaVIPGate<Content: View>: View {
    @ObservedObject private var iap = StoreKitIAPManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @State private var showPaywall = false
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        Group {
            if iap.hasUnlockedVIP { content() }
            else {
                VIPLockCardView(title: lang.t("bz_tool_owner"), featureDesc: lang.t("bz_owner_vip_desc"),
                                badge: lang.t("vip_badge_title"), targetProductId: .vipYearly,
                                onUnlockTap: { showPaywall = true })
                    .padding(16)
            }
        }
        .sheet(isPresented: $showPaywall) { VIPPaywallSheet(defaultProductId: .proLifetime) }
    }
}

public struct OwnerLifeGuaView: View {
    private let context: CompassHeadingState
    @ObservedObject private var lang = LocalizationManager.shared
    @ObservedObject private var kua = UserKuaProfileManager.shared
    @Environment(\.presentationMode) private var presentationMode
    @State private var showFamilySection = true
    @State private var showProfileData = false
    @State private var activeSheet: Sheet?
    private enum Sheet: String, Identifiable {
        case editOwnerKua, addFamilyMember
        var id: String { rawValue }
    }

    public init(context: CompassHeadingState) { self.context = context }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    Button(lang.t("profile_data_title")) { showProfileData = true }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.top, 12)
                    OwnerGuaVIPGate {
                        VStack(alignment: .leading, spacing: 14) {
                            DisclosureGroup(lang.t("analysis_usage")) {
                                Text(lang.t("bz_owner_intro"))
                            }
                                .adaptiveFont(size: 12)
                                .foregroundColor(.white.opacity(0.75))
                                .padding(.horizontal, 16)
                            Toggle(lang.t("bz_owner_enable"), isOn: $kua.isProfileEnabled)
                                .adaptiveFont(size: 13)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                            if kua.isProfileEnabled {
                                Text(lang.t("bz_tool_context") + " · " + context.sittingMountain.localizedName + lang.t("mountain_suffix"))
                                    .adaptiveFont(size: 11)
                                    .foregroundColor(Color.yanCyan)
                                    .padding(.horizontal, 16)
                                ownerKuaCard(sittingPalace: context.sittingMountain.palace)
                                Button {
                                    presentationMode.wrappedValue.dismiss()
                                    AppNavigationRouter.shared.requestRoute(tab: .floorplan)
                                } label: {
                                    Label(lang.t("fra_open_plan") + " · " + lang.t("fra_membership"), systemImage: "person.2.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(12)
                                        .background(Color.yanCyan.opacity(0.12))
                                        .cornerRadius(10)
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
            .navigationTitle(lang.t("bz_tool_owner"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) {
                Button(lang.t("done")) { presentationMode.wrappedValue.dismiss() }
            } }
            .sheet(item: $activeSheet) { sheet in
                OwnerGuaVIPGate {
                switch sheet {
                case .editOwnerKua:
                    EditOwnerKuaDialog(isPresented: Binding(get: { activeSheet == .editOwnerKua },
                                                           set: { if !$0 { activeSheet = nil } }),
                                       sittingPalace: context.sittingMountain.palace,
                                       onSaved: { activeSheet = nil })
                case .addFamilyMember:
                    AddFamilyMemberDialog(isPresented: Binding(get: { activeSheet == .addFamilyMember },
                                                               set: { if !$0 { activeSheet = nil } }),
                                          ownerBirthYear: kua.birthYear, ownerIsMale: kua.isMale,
                                          onConfirm: { role, name, birthDate, year, male in
                        kua.addFamilyMember(role: role, customName: name, birthDate: birthDate, birthYear: year, isMale: male)
                        showFamilySection = true
                        activeSheet = nil
                    })
                }
                }
            }
            .sheet(isPresented: $showProfileData) {
                NavigationView {
                    PersonalProfileDataView()
                        .toolbar { ToolbarItem(placement: .navigationBarTrailing) {
                            Button(lang.t("done")) { showProfileData = false }
                        } }
                }.navigationViewStyle(StackNavigationViewStyle())
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }

    // MARK: - P1.1 宅主命卦画像与「人宅合一」配对卡
    private func ownerKuaCard(sittingPalace: String) -> some View {
        let compat = kua.evaluateCompatibility(sittingPalace: sittingPalace)
        let titleLabel: String
        let yearPrefix: String
        let maleLabel: String
        let femaleLabel: String
        let wealthLabel: String
        let studyLabel: String
        switch lang.effectiveLanguage {
        case .en:
            titleLabel = "Owner Life Gua & House Match"
            yearPrefix = "Born"
            maleLabel = "M"
            femaleLabel = "F"
            wealthLabel = "Wealth"
            studyLabel = "Study"
        case .zhHant:
            titleLabel = "宅主本命卦 · 人宅合一配對"
            yearPrefix = "生辰"
            maleLabel = "男"
            femaleLabel = "女"
            wealthLabel = "本命財位"
            studyLabel = "本命文昌"
        case .ja:
            titleLabel = "家主本命卦・宅命相配診断"
            yearPrefix = "生年"
            maleLabel = "男"
            femaleLabel = "女"
            wealthLabel = "本命財位"
            studyLabel = "本命文昌"
        case .ko:
            titleLabel = "건축주 본명괘 · 택명상배"
            yearPrefix = "생년"
            maleLabel = "남"
            femaleLabel = "여"
            wealthLabel = "본명재위"
            studyLabel = "본명문창"
        case .vi:
            titleLabel = "Bản Mệnh Trạch Chủ & Phối Quẻ"
            yearPrefix = "Sinh"
            maleLabel = "Nam"
            femaleLabel = "Nữ"
            wealthLabel = "Tài Vị"
            studyLabel = "Văn Xương"
        case .th:
            titleLabel = "รหัสชีวิตเจ้าของบ้าน & สมดุลบ้าน"
            yearPrefix = "ปีเกิด"
            maleLabel = "ชาย"
            femaleLabel = "หญิง"
            wealthLabel = "ทิศโชคลาภ"
            studyLabel = "ทิศการศึกษา"
        case .id:
            titleLabel = "Gua Pemilik & Keselarasan Rumah"
            yearPrefix = "Lahir"
            maleLabel = "P"
            femaleLabel = "W"
            wealthLabel = "Arah Rezeki"
            studyLabel = "Arah Studi"
        case .auto, .zhHans:
            titleLabel = "宅主本命卦 · 人宅合一配对"
            yearPrefix = "生辰"
            maleLabel = "男"
            femaleLabel = "女"
            wealthLabel = "本命财位"
            studyLabel = "本命文昌"
        }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "person.text.rectangle.fill")
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text(titleLabel)
                    .adaptiveFont(size: 13, weight: .bold)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Spacer()

                // 点击修改生辰日期与命卦按钮
                Button(action: {
                    activeSheet = .editOwnerKua
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Text("\(yearPrefix) \(String(kua.birthYear))")
                        Image(systemName: "pencil")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .adaptiveFont(size: 11, weight: .bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                // 性别切换
                Button(action: {
                    kua.isMale.toggle()
                }) {
                    Text(kua.isMale ? maleLabel : femaleLabel)
                        .adaptiveFont(size: 11, weight: .bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yanCyan.opacity(0.2))
                        .foregroundColor(Color.yanCyan)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // 命卦画像展示与配对卡（点击也可直接唤起修改弹窗）
            Button(action: {
                activeSheet = .editOwnerKua
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                HStack(spacing: 8) {
                    Text("【\(compat.localizedOwnerGuaName) · \(compat.localizedLifeGroup) · \(compat.localizedZodiacName)】")
                        .adaptiveFont(size: 12, weight: .bold)
                        .foregroundColor(Color.yanCyan)
                    Spacer()
                    Text(compat.matchBadgeTitle)
                        .adaptiveFont(size: 10, weight: .bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((compat.isMatchedWithHouse ? Color.green : Color.orange).opacity(0.2))
                        .foregroundColor(compat.isMatchedWithHouse ? Color.green : Color.orange)
                        .cornerRadius(4)
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.85))
                }
            }
            .buttonStyle(PlainButtonStyle())

            Text(compat.matchAdvice)
                .adaptiveFont(size: 11)
                .foregroundColor(.white.opacity(0.88))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text("💰 \(wealthLabel): \(compat.wealthDirection)")
                    .adaptiveFont(size: 11, weight: .semibold)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Spacer()
                Text("📚 \(studyLabel): \(compat.studyDirection)")
                    .adaptiveFont(size: 11, weight: .semibold)
                    .foregroundColor(.white.opacity(0.85))
            }

            Divider().background(Color.white.opacity(0.1))

            // 全家成员命卦与智能分房档案
            familyMembersSection(maleLabel: maleLabel, femaleLabel: femaleLabel)
        }
        .padding(12)
        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private func familyMembersSection(maleLabel: String, femaleLabel: String) -> some View {
        let headerTitle: String
        let addHint: String
        let emptyTitle: String
        let emptySubtitle: String
        switch lang.effectiveLanguage {
        case .en:
            headerTitle = "Family Members Life Gua & Smart Room Fit (\(kua.familyMembers.count))"
            addHint = "+ Add Member"
            emptyTitle = "No Family Members Added Yet"
            emptySubtitle = "Tap to add spouse, parents, or children for life gua and room recommendations"
        case .zhHant:
            headerTitle = "全家成員命卦與智能分房檔案（\(kua.familyMembers.count)人）"
            addHint = "+ 添加家人"
            emptyTitle = "暫未添加家庭成員"
            emptySubtitle = "點擊添加配偶、父母或子女，智能推演全家本命卦與分房吉位"
        case .ja:
            headerTitle = "家族全員の本命卦・部屋割診断（\(kua.familyMembers.count)名）"
            addHint = "+ 家族追加"
            emptyTitle = "家族メンバーが未登録です"
            emptySubtitle = "タップして配偶者・両親・子供を追加し、部屋割を自動診断"
        case .ko:
            headerTitle = "가족 구성원 본명괘 및 방 배정 (\(kua.familyMembers.count)명)"
            addHint = "+ 가족 추가"
            emptyTitle = "등록된 가족 구성원이 없습니다"
            emptySubtitle = "터치하여 배우자, 부모, 자녀를 추가하고 최적의 방 배정을 확인하세요"
        case .vi:
            headerTitle = "Bản Mệnh Gia Đình & Phân Phòng (\(kua.familyMembers.count))"
            addHint = "+ Thêm người"
            emptyTitle = "Chưa có thành viên gia đình"
            emptySubtitle = "Nhấn để thêm vợ/chồng, cha mẹ, con cái và tự động gợi ý phòng"
        case .th:
            headerTitle = "รหัสชีวิตสมาชิกครอบครัว & จัดห้อง (\(kua.familyMembers.count))"
            addHint = "+ เพิ่มสมาชิก"
            emptyTitle = "ยังไม่มีสมาชิกครอบครัว"
            emptySubtitle = "แตะเพื่อเพิ่มคู่สมรส พ่อแม่ หรือบุตร เพื่อจัดห้องมงคล"
        case .id:
            headerTitle = "Gua Anggota Keluarga & Kamar (\(kua.familyMembers.count))"
            addHint = "+ Tambah"
            emptyTitle = "Belum Ada Anggota Keluarga"
            emptySubtitle = "Ketuk untuk menambah pasangan, orang tua, atau anak"
        case .auto, .zhHans:
            headerTitle = "全家成员命卦与智能分房档案（\(kua.familyMembers.count)人）"
            addHint = "+ 添加家人"
            emptyTitle = "暂未添加家庭成员"
            emptySubtitle = "点击添加配偶、父母或子女，智能推演全家本命卦与分房吉位"
        }

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) { showFamilySection.toggle() }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yanCyan)
                        Text(headerTitle)
                            .adaptiveFont(size: 11, weight: .bold)
                            .foregroundColor(.yanCyan)
                        Image(systemName: showFamilySection ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Button(action: {
                    activeSheet = .addFamilyMember
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 10))
                        Text(addHint)
                            .adaptiveFont(size: 10, weight: .bold)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.yanCyan.opacity(0.22))
                    .foregroundColor(.yanCyan)
                    .cornerRadius(5)
                }
                .buttonStyle(PlainButtonStyle())
            }

            if kua.familyMembers.isEmpty {
                Button(action: {
                    activeSheet = .addFamilyMember
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 18))
                            .foregroundColor(.yanCyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(emptyTitle)
                                .adaptiveFont(size: 11, weight: .bold)
                                .foregroundColor(.white)
                            Text(emptySubtitle)
                                .adaptiveFont(size: 9.5)
                                .foregroundColor(.white.opacity(0.65))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundColor(Color.yanCyan.opacity(0.35))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 2)
            } else if showFamilySection {
                VStack(spacing: 6) {
                    ForEach(kua.familyMembers) { member in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(member.displayName)
                                    .adaptiveFont(size: 11, weight: .bold)
                                    .foregroundColor(.white)
                                Text("【\(member.localizedGuaBadge)】")
                                    .adaptiveFont(size: 10, weight: .bold)
                                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                Spacer()
                                Menu {
                                    ForEach((1900...UserKuaProfileManager.gregorianCalendar().component(.year, from: Date())).reversed(), id: \.self) { yr in
                                        Button(action: {
                                            kua.updateFamilyMember(id: member.id, birthYear: yr)
                                        }) {
                                            Text("\(String(yr))")
                                        }
                                    }
                                } label: {
                                    Text("\(member.formattedBirth)▾")
                                        .adaptiveFont(size: 10, weight: .semibold)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.08))
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                                .buttonStyle(PlainButtonStyle())
                                Button(action: {
                                    kua.updateFamilyMember(id: member.id, isMale: !member.isMale)
                                }) {
                                    Text(member.isMale ? maleLabel : femaleLabel)
                                        .adaptiveFont(size: 10, weight: .bold)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.yanCyan.opacity(0.18))
                                        .foregroundColor(.yanCyan)
                                        .cornerRadius(4)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button(action: {
                                    withAnimation {
                                        kua.removeFamilyMember(id: member.id)
                                    }
                                }) {
                                    Image(systemName: "trash.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.45))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            Text(member.personalWealthAndStudySummary)
                                .adaptiveFont(size: 10)
                                .foregroundColor(.white.opacity(0.78))
                        }
                        .padding(7)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)
                    }

                    Button(action: {
                        activeSheet = .addFamilyMember
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .bold))
                            Text(addHint)
                                .adaptiveFont(size: 10, weight: .semibold)
                        }
                        .foregroundColor(.yanCyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.yanCyan.opacity(0.08))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 2)
                }
            }
        }
    }

}

public struct AddFamilyMemberDialog: View {
    @Binding var isPresented: Bool
    let ownerBirthYear: Int
    let ownerIsMale: Bool
    let onConfirm: (FamilyRole, String?, Date?, Int, Bool) -> Void

    public init(
        isPresented: Binding<Bool>,
        ownerBirthYear: Int,
        ownerIsMale: Bool,
        onConfirm: @escaping (FamilyRole, String?, Date?, Int, Bool) -> Void
    ) {
        self._isPresented = isPresented
        self.ownerBirthYear = ownerBirthYear
        self.ownerIsMale = ownerIsMale
        self.onConfirm = onConfirm
    }

    public init(
        isPresented: Binding<Bool>,
        ownerBirthYear: Int,
        ownerIsMale: Bool,
        onConfirm: @escaping (FamilyRole, String?, Int, Bool) -> Void
    ) {
        self._isPresented = isPresented
        self.ownerBirthYear = ownerBirthYear
        self.ownerIsMale = ownerIsMale
        self.onConfirm = { role, name, _, year, isMale in
            onConfirm(role, name, year, isMale)
        }
    }

    @ObservedObject private var lang = LocalizationManager.shared
    @State private var selectedRole: FamilyRole = .spouse
    @State private var customName: String = ""
    @State private var inputMode: Int = 0 // 0: 精确公历生辰 (波轮 WheelDatePickerStyle), 1: 年份快速选择
    @State private var selectedDate: Date = Date()
    @State private var selectedYear: Int = 1990
    @State private var selectedIsMale: Bool = false
    @State private var isInitialized: Bool = false

    private var dateRange: ClosedRange<Date> {
        let cal = UserKuaProfileManager.gregorianCalendar()
        let start = cal.date(from: DateComponents(year: 1920, month: 1, day: 1)) ?? Date(timeIntervalSince1970: -1577923200)
        let end = cal.date(from: DateComponents(year: 2026, month: 12, day: 31)) ?? Date()
        return start...end
    }

    private var effectiveFengShuiYear: Int {
        if inputMode == 0 {
            return UserKuaProfileManager.fengShuiYear(for: selectedDate)
        } else {
            return selectedYear
        }
    }

    private var isDateBeforeLiChun: Bool {
        inputMode == 0 && SolarTimeCalculator.shared.isBeforeLiChun(for: selectedDate)
    }

    private var selectedDateFormatted: String {
        let cal = UserKuaProfileManager.gregorianCalendar()
        let y = cal.component(.year, from: selectedDate)
        let m = cal.component(.month, from: selectedDate)
        let d = cal.component(.day, from: selectedDate)
        return "\(y)年\(m)月\(d)日"
    }

    private func dateForYear(_ yr: Int) -> Date {
        let cal = UserKuaProfileManager.gregorianCalendar()
        let comp = cal.dateComponents([.month, .day], from: selectedDate)
        var newComp = DateComponents()
        newComp.year = yr
        newComp.month = comp.month ?? 6
        newComp.day = comp.day ?? 15
        return cal.date(from: newComp) ?? Date()
    }

    private func initDefaults() {
        guard !isInitialized else { return }
        isInitialized = true
        selectedRole = .spouse
        selectedIsMale = !ownerIsMale
        selectedYear = ownerBirthYear
        selectedDate = dateForYear(ownerBirthYear)
    }

    private func applyRolePreset(_ role: FamilyRole) {
        selectedRole = role
        switch role {
        case .spouse:
            selectedIsMale = !ownerIsMale
            selectedYear = ownerBirthYear
        case .father:
            selectedIsMale = true
            selectedYear = max(1930, ownerBirthYear - 28)
        case .mother:
            selectedIsMale = false
            selectedYear = max(1930, ownerBirthYear - 26)
        case .elder:
            selectedIsMale = true
            selectedYear = max(1930, ownerBirthYear - 28)
        case .son:
            selectedIsMale = true
            selectedYear = min(2026, max(1995, ownerBirthYear + 26))
        case .daughter:
            selectedIsMale = false
            selectedYear = min(2026, max(1995, ownerBirthYear + 28))
        case .child1:
            selectedIsMale = true
            selectedYear = min(2026, max(1995, ownerBirthYear + 26))
        case .child2:
            selectedIsMale = false
            selectedYear = min(2026, max(1995, ownerBirthYear + 28))
        case .other:
            selectedIsMale = true
            selectedYear = ownerBirthYear
        }
        selectedDate = dateForYear(selectedYear)
    }

    private var previewGuaBadge: String {
        let guaNum = UserKuaProfileManager.calcGuaNumber(birthYear: effectiveFengShuiYear, isMale: selectedIsMale)
        let guaKey = UserKuaProfileManager.guaKey(for: guaNum)
        let isEast = [1, 3, 4, 9].contains(guaNum)
        let guaItem = BaZhaiPalaceItem(id: 0, direction: "", guaName: guaKey, star: .fuWei)
        switch lang.effectiveLanguage {
        case .en:
            return "\(guaItem.localizedGuaName) · \(isEast ? "East 4" : "West 4")"
        case .zhHant, .ja:
            return "\(guaItem.localizedGuaName)命·\(isEast ? "東四命" : "西四命")"
        case .ko:
            return "\(guaItem.localizedGuaName)명·\(isEast ? "동사명" : "서사명")"
        case .vi:
            return "Mệnh \(guaItem.localizedGuaName)·\(isEast ? "Đông Tứ" : "Tây Tứ")"
        case .th:
            return "ดวง\(guaItem.localizedGuaName)·\(isEast ? "ตะวันออก" : "ตะวันตก")"
        case .id:
            return "Gua \(guaItem.localizedGuaName)·\(isEast ? "Timur" : "Barat")"
        case .auto, .zhHans:
            return "\(guaItem.localizedGuaName)命·\(isEast ? "东四命" : "西四命")"
        }
    }

    private var previewDirectionsSummary: String {
        let guaNum = UserKuaProfileManager.calcGuaNumber(birthYear: effectiveFengShuiYear, isMale: selectedIsMale)
        let guaKey = UserKuaProfileManager.guaKey(for: guaNum)
        let chart = BaZhaiEngine.shared.analyze(sittingPalace: guaKey, facingPalace: "离")
        let wDir = chart.items.first(where: { $0.star == .shengQi })?.localizedDirection ?? "-"
        let sDir = chart.items.first(where: { $0.star == .fuWei })?.localizedDirection ?? "-"
        let hDir = chart.items.first(where: { $0.star == .tianYi })?.localizedDirection ?? "-"
        switch lang.effectiveLanguage {
        case .en:
            return "Wealth: \(wDir) · Health: \(hDir) · Study: \(sDir)"
        case .zhHant, .ja:
            return "生氣財位:\(wDir) · 天醫康健:\(hDir) · 文昌伏位:\(sDir)"
        case .ko:
            return "생기:\(wDir) · 천의:\(hDir) · 문창:\(sDir)"
        case .vi:
            return "Sinh Khí:\(wDir) · Thiên Y:\(hDir) · Văn Xương:\(sDir)"
        case .th:
            return "โชคลาภ:\(wDir) · สุขภาพ:\(hDir) · การเรียน:\(sDir)"
        case .id:
            return "Rezeki:\(wDir) · Sehat:\(hDir) · Studi:\(sDir)"
        case .auto, .zhHans:
            return "生气财位:\(wDir) · 天医康健:\(hDir) · 文昌伏位:\(sDir)"
        }
    }

    public var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.15)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    // 1. 弹窗顶栏
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 16))
                            .foregroundColor(.yanCyan)
                        Text(dialogTitle)
                            .adaptiveFont(size: 15, weight: .bold)
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Text(dialogSubtitle)
                        .adaptiveFont(size: 11)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // 2. 身份关系网格
                    VStack(alignment: .leading, spacing: 6) {
                        Text(roleSectionTitle)
                            .adaptiveFont(size: 11, weight: .bold)
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 6)], spacing: 6) {
                            ForEach(FamilyRole.allCases) { role in
                                Button(action: {
                                    applyRolePreset(role)
                                }) {
                                    Text(role.localizedTitle)
                                        .adaptiveFont(size: 11, weight: selectedRole == role ? .bold : .medium)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(selectedRole == role ? Color.yanCyan.opacity(0.28) : Color.white.opacity(0.06))
                                        .foregroundColor(selectedRole == role ? .yanCyan : .white.opacity(0.85))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(selectedRole == role ? Color.yanCyan : Color.clear, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    // 3. 称呼/姓名（选填）与 性别选择
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(nameSectionTitle)
                                .adaptiveFont(size: 11, weight: .bold)
                                .foregroundColor(.white.opacity(0.85))
                            TextField(namePlaceholder, text: $customName)
                                .adaptiveFont(size: 12)
                                .padding(8)
                                .background(Color.white.opacity(0.08))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(genderSectionTitle)
                                .adaptiveFont(size: 11, weight: .bold)
                                .foregroundColor(.white.opacity(0.85))

                            HStack(spacing: 4) {
                                Button(action: { selectedIsMale = true }) {
                                    Text(maleText)
                                        .adaptiveFont(size: 11, weight: selectedIsMale ? .bold : .medium)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 7)
                                        .background(selectedIsMale ? Color.yanCyan.opacity(0.28) : Color.white.opacity(0.06))
                                        .foregroundColor(selectedIsMale ? .yanCyan : .white.opacity(0.8))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(selectedIsMale ? Color.yanCyan : Color.clear, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button(action: { selectedIsMale = false }) {
                                    Text(femaleText)
                                        .adaptiveFont(size: 11, weight: !selectedIsMale ? .bold : .medium)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 7)
                                        .background(!selectedIsMale ? Color.pink.opacity(0.28) : Color.white.opacity(0.06))
                                        .foregroundColor(!selectedIsMale ? Color.pink : .white.opacity(0.8))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(!selectedIsMale ? Color.pink : Color.clear, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .frame(width: 110)
                    }

                    // 4. 生辰输入模式切换（公历年月日波轮 / 年份快速选择）
                    Picker("", selection: $inputMode) {
                        Text(modeDateLabel).tag(0)
                        Text(modeYearLabel).tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    // 5. 日期波轮或年份快速选择内容
                    if inputMode == 0 {
                        // 精确公历生辰波轮 (WheelDatePickerStyle)
                        VStack(spacing: 6) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                Text(datePickerHint)
                                    .adaptiveFont(size: 12, weight: .semibold)
                                    .foregroundColor(.white.opacity(0.85))
                                Spacer()
                                Text(selectedDateFormatted)
                                    .adaptiveFont(size: 13, weight: .bold)
                                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                            }
                            .padding(.horizontal, 4)

                            DatePicker(
                                "",
                                selection: $selectedDate,
                                in: dateRange,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(WheelDatePickerStyle())
                        .environment(\.calendar, UserKuaProfileManager.gregorianCalendar())
                            .labelsHidden()
                            .frame(maxHeight: 140)
                            .clipped()
                            .colorScheme(.dark)
                            .onChange(of: selectedDate) { newDate in
                                selectedYear = UserKuaProfileManager.gregorianCalendar().component(.year, from: newDate)
                            }

                            // 立春换年解释或流年确认卡
                            HStack(spacing: 6) {
                                Image(systemName: isDateBeforeLiChun ? "info.circle.fill" : "sparkles")
                                    .font(.system(size: 11))
                                    .foregroundColor(isDateBeforeLiChun ? .orange : Color.yanCyan)
                                Text(liChunExplanationText)
                                    .adaptiveFont(size: 10.5)
                                    .foregroundColor(isDateBeforeLiChun ? .orange : .white.opacity(0.8))
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                        }
                    } else {
                        // 年份快速选择
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Button(action: {
                                    selectedYear = max(1920, selectedYear - 10)
                                    selectedDate = dateForYear(selectedYear)
                                }) {
                                    Text("-10")
                                        .adaptiveFont(size: 10, weight: .bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 7)
                                        .background(Color.white.opacity(0.08))
                                        .foregroundColor(.white.opacity(0.9))
                                        .cornerRadius(5)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button(action: {
                                    selectedYear = max(1920, selectedYear - 1)
                                    selectedDate = dateForYear(selectedYear)
                                }) {
                                    Text("-1")
                                        .adaptiveFont(size: 10, weight: .bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 7)
                                        .background(Color.white.opacity(0.08))
                                        .foregroundColor(.white.opacity(0.9))
                                        .cornerRadius(5)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Spacer()

                                Menu {
                                    ForEach((1920...2026).reversed(), id: \.self) { yr in
                                        Button(action: {
                                            selectedYear = yr
                                            selectedDate = dateForYear(yr)
                                        }) {
                                            HStack {
                                                Text("\(String(yr))年")
                                                if yr == selectedYear {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 3) {
                                        Text("\(String(selectedYear))年")
                                            .adaptiveFont(size: 13, weight: .bold)
                                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(5)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Spacer()

                                Button(action: {
                                    selectedYear = min(2026, selectedYear + 1)
                                    selectedDate = dateForYear(selectedYear)
                                }) {
                                    Text("+1")
                                        .adaptiveFont(size: 10, weight: .bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 7)
                                        .background(Color.white.opacity(0.08))
                                        .foregroundColor(.white.opacity(0.9))
                                        .cornerRadius(5)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button(action: {
                                    selectedYear = min(2026, selectedYear + 10)
                                    selectedDate = dateForYear(selectedYear)
                                }) {
                                    Text("+10")
                                        .adaptiveFont(size: 10, weight: .bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 7)
                                        .background(Color.white.opacity(0.08))
                                        .foregroundColor(.white.opacity(0.9))
                                        .cornerRadius(5)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                    }

                    // 6. 实时命卦排盘预览卡
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("【\(previewGuaBadge)】")
                                .adaptiveFont(size: 11, weight: .bold)
                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                            Spacer()
                        }
                        Text(previewDirectionsSummary)
                            .adaptiveFont(size: 9.5)
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)

                    // 7. 底部确认与取消按钮
                    HStack(spacing: 10) {
                        Button(action: { isPresented = false }) {
                            Text(cancelText)
                                .adaptiveFont(size: 13, weight: .semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white.opacity(0.85))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let birthDateToPass = (inputMode == 0) ? selectedDate : nil
                            onConfirm(selectedRole, trimmed.isEmpty ? nil : trimmed, birthDateToPass, effectiveFengShuiYear, selectedIsMale)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            isPresented = false
                        }) {
                            Text(confirmText)
                                .adaptiveFont(size: 13, weight: .bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(Color.yanCyan)
                                .foregroundColor(.black)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .frame(maxWidth: 440)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            initDefaults()
        }
    }

    // 多语言文案辅助
    private var dialogTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Add Family Member"
        case .zhHant: return "添加家庭成員"
        case .ja: return "家族メンバー追加"
        case .ko: return "가족 구성원 추가"
        case .vi: return "Thêm Thành Viên"
        case .th: return "เพิ่มสมาชิกครอบครัว"
        case .id: return "Tambah Keluarga"
        case .auto, .zhHans: return "添加家庭成员"
        }
    }

    private var dialogSubtitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Enter birth details for life gua and room recommendations"
        case .zhHant: return "錄入生辰以推演本命卦吉方與智能分房"
        case .ja: return "生年を登録して本命卦と部屋割を診断"
        case .ko: return "생년을 입력하여 본명괘와 방 배정을 확인하세요"
        case .vi: return "Nhập năm sinh để xem bản mệnh và gợi ý phân phòng"
        case .th: return "กรอกปีเกิดเพื่อตรวจดวงชะตาและจัดห้องมงคล"
        case .id: return "Masukkan tahun lahir untuk cek gua & kamar"
        case .auto, .zhHans: return "录入生辰以推演本命卦吉方与智能分房"
        }
    }

    private var roleSectionTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Family Relationship"
        case .zhHant: return "家庭關係/身份"
        case .ja: return "家族関係・続柄"
        case .ko: return "가족 관계/신분"
        case .vi: return "Mối Quan Hệ"
        case .th: return "ความสัมพันธ์"
        case .id: return "Hubungan Keluarga"
        case .auto, .zhHans: return "家庭关系/身份"
        }
    }

    private var nameSectionTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Nickname / Remark (Optional)"
        case .zhHant: return "稱謂/姓名（選填）"
        case .ja: return "呼び名・名前（任意）"
        case .ko: return "호칭/이름 (선택)"
        case .vi: return "Tên / Xưng hô (tùy chọn)"
        case .th: return "ชื่อ / คำเรียก (ไม่บังคับ)"
        case .id: return "Nama / Panggilan (opsional)"
        case .auto, .zhHans: return "称谓/姓名（选填）"
        }
    }

    private var namePlaceholder: String {
        switch lang.effectiveLanguage {
        case .en: return "e.g. Mom, Alex, Daughter"
        case .zhHant: return "例如：媽媽 / 大寶 / 哥哥"
        case .ja: return "例：母、太郎、長女"
        case .ko: return "예: 어머니, 첫째, 공주"
        case .vi: return "Ví dụ: Mẹ, Bé Bự, Anh Hai"
        case .th: return "เช่น คุณแม่, น้องบอส"
        case .id: return "Misal: Ibu, Kakak, Adik"
        case .auto, .zhHans: return "例如：妈妈 / 大宝 / 哥哥"
        }
    }

    private var genderSectionTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Gender"
        case .zhHant: return "性別"
        case .ja: return "性別"
        case .ko: return "성별"
        case .vi: return "Giới tính"
        case .th: return "เพศ"
        case .id: return "Jenis Kelamin"
        case .auto, .zhHans: return "性别"
        }
    }

    private var maleText: String {
        switch lang.effectiveLanguage {
        case .en: return "Male"
        case .zhHant, .ja: return "男"
        case .ko: return "남"
        case .vi: return "Nam"
        case .th: return "ชาย"
        case .id: return "Pria"
        case .auto, .zhHans: return "男"
        }
    }

    private var femaleText: String {
        switch lang.effectiveLanguage {
        case .en: return "Female"
        case .zhHant, .ja: return "女"
        case .ko: return "여"
        case .vi: return "Nữ"
        case .th: return "หญิง"
        case .id: return "Wanita"
        case .auto, .zhHans: return "女"
        }
    }

    private var modeDateLabel: String {
        switch lang.effectiveLanguage {
        case .en: return "Exact Birth Date"
        case .zhHant: return "公曆年月日"
        case .ja: return "生年月日"
        case .ko: return "생년월일"
        case .vi: return "Ngày sinh"
        case .th: return "วันเกิด"
        case .id: return "Tanggal Lahir"
        case .auto, .zhHans: return "公历年月日"
        }
    }

    private var modeYearLabel: String {
        switch lang.effectiveLanguage {
        case .en: return "Birth Year"
        case .zhHant: return "出生年份"
        case .ja: return "生まれ年"
        case .ko: return "출생연도"
        case .vi: return "Năm sinh"
        case .th: return "ปีเกิด"
        case .id: return "Tahun Lahir"
        case .auto, .zhHans: return "出生年份"
        }
    }

    private var datePickerHint: String {
        switch lang.effectiveLanguage {
        case .en: return "Select Birthday:"
        case .zhHant: return "選擇公曆生日："
        case .ja: return "誕生日を選択："
        case .ko: return "생년월일 선택:"
        case .vi: return "Chọn ngày sinh:"
        case .th: return "เลือกวันเกิด:"
        case .id: return "Pilih Tanggal Lahir:"
        case .auto, .zhHans: return "选择公历生日："
        }
    }

    private var liChunExplanationText: String {
        let y = effectiveFengShuiYear
        if isDateBeforeLiChun {
            switch lang.effectiveLanguage {
            case .en:
                return "Born before Li Chun (Feb 4). Life Gua calculated using previous Feng Shui year (\(y))."
            case .zhHant, .ja:
                return "公曆立春（約2月4日）前出生，依風水歲首以立春前一年（\(y)年）核算命卦。"
            default:
                return "公历立春（约2月4日）前出生，依风水岁首以立春前一年（\(y)年）核算命卦。"
            }
        } else {
            switch lang.effectiveLanguage {
            case .en:
                return "Feng Shui year: \(y)."
            default:
                return "对应风水流年：\(y)年。"
            }
        }
    }

    private var cancelText: String {
        switch lang.effectiveLanguage {
        case .en: return "Cancel"
        case .zhHant: return "取消"
        case .ja: return "キャンセル"
        case .ko: return "취소"
        case .vi: return "Hủy"
        case .th: return "ยกเลิก"
        case .id: return "Batal"
        case .auto, .zhHans: return "取消"
        }
    }

    private var confirmText: String {
        switch lang.effectiveLanguage {
        case .en: return "Confirm Add"
        case .zhHant: return "確認添加"
        case .ja: return "追加する"
        case .ko: return "추가하기"
        case .vi: return "Xác Nhận Thêm"
        case .th: return "ยืนยันการเพิ่ม"
        case .id: return "Tambahkan"
        case .auto, .zhHans: return "确认添加"
        }
    }
}

public struct EditOwnerKuaDialog: View {
    @Binding var isPresented: Bool
    public var sittingPalace: String = "坎"
    public var onSaved: (() -> Void)? = nil

    @ObservedObject var kua = UserKuaProfileManager.shared
    @ObservedObject var lang = LocalizationManager.shared

    @State private var inputMode: Int = 0 // 0: 精确公历日期, 1: 年份快速选择
    @State private var selectedDate: Date = Date()
    @State private var selectedYear: Int = 1990
    @State private var selectedIsMale: Bool = true
    @State private var isInitialized: Bool = false

    public init(isPresented: Binding<Bool>, sittingPalace: String = "坎", onSaved: (() -> Void)? = nil) {
        self._isPresented = isPresented
        self.sittingPalace = sittingPalace
        self.onSaved = onSaved
    }

    private var effectiveFengShuiYear: Int {
        if inputMode == 0 {
            return UserKuaProfileManager.fengShuiYear(for: selectedDate)
        } else {
            return selectedYear
        }
    }

    private var calculatedGuaNumber: Int {
        UserKuaProfileManager.calcGuaNumber(birthYear: effectiveFengShuiYear, isMale: selectedIsMale)
    }

    private var calculatedGuaKey: String {
        UserKuaProfileManager.guaKey(for: calculatedGuaNumber)
    }

    private var isEastLife: Bool {
        [1, 3, 4, 9].contains(calculatedGuaNumber)
    }

    private var houseIsEast: Bool {
        ["坎", "震", "巽", "离"].contains(sittingPalace)
    }

    private var isMatched: Bool {
        isEastLife == houseIsEast
    }

    private var ganzhiAndZodiac: String {
        let y = effectiveFengShuiYear
        let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
        let branches = ["子鼠", "丑牛", "寅虎", "卯兔", "辰龙", "巳蛇", "午马", "未羊", "申猴", "酉鸡", "戌狗", "亥猪"]
        let s = stems[((y - 4) % 10 + 10) % 10]
        let b = branches[((y - 4) % 12 + 12) % 12]
        return "\(s)\(b)年"
    }

    private var isDateBeforeLiChun: Bool {
        inputMode == 0 && SolarTimeCalculator.shared.isBeforeLiChun(for: selectedDate)
    }

    private var dateRange: ClosedRange<Date> {
        let cal = UserKuaProfileManager.gregorianCalendar()
        var startComp = DateComponents()
        startComp.year = 1920
        startComp.month = 1
        startComp.day = 1
        let start = cal.date(from: startComp) ?? Date(timeIntervalSince1970: 0)
        var endComp = DateComponents()
        endComp.year = 2030
        endComp.month = 12
        endComp.day = 31
        let end = cal.date(from: endComp) ?? Date()
        return start...end
    }

    private func setupInitialValues() {
        guard !isInitialized else { return }
        isInitialized = true
        let draft = BirthDateEditorState(date: kua.birthDate)
        selectedDate = draft.date
        selectedYear = draft.year
        selectedIsMale = kua.isMale
    }

    private var selectedDateFormatted: String {
        let cal = UserKuaProfileManager.gregorianCalendar()
        let y = cal.component(.year, from: selectedDate)
        let m = cal.component(.month, from: selectedDate)
        let d = cal.component(.day, from: selectedDate)
        return "\(y)年\(m)月\(d)日"
    }

    public var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.15)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    // 1. 顶栏标题与关闭按钮
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Text(dialogTitle)
                            .adaptiveFont(size: 15, weight: .bold)
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // 2. 模式切换：精确公历日期 / 年份快速选择
                    Picker("", selection: $inputMode) {
                        Text(modeDateLabel).tag(0)
                        Text(modeYearLabel).tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())

                // 3. 日期或年份选择内容
                if inputMode == 0 {
                    // 精确公历日期选择器（波轮样式 WheelDatePickerStyle）
                    VStack(spacing: 6) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                            Text(datePickerHint)
                                .adaptiveFont(size: 12, weight: .semibold)
                                .foregroundColor(.white.opacity(0.85))
                            Spacer()
                            Text(selectedDateFormatted)
                                .adaptiveFont(size: 13, weight: .bold)
                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        }
                        .padding(.horizontal, 4)

                        DatePicker(
                            "",
                            selection: $selectedDate,
                            in: dateRange,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(WheelDatePickerStyle())
                        .environment(\.calendar, UserKuaProfileManager.gregorianCalendar())
                        .labelsHidden()
                        .frame(maxHeight: 140)
                        .clipped()
                        .colorScheme(.dark)
                        .onChange(of: selectedDate) { newDate in
                            selectedYear = UserKuaProfileManager.gregorianCalendar().component(.year, from: newDate)
                        }

                        // 立春换年解释或流年确认卡
                        HStack(spacing: 6) {
                            Image(systemName: isDateBeforeLiChun ? "info.circle.fill" : "sparkles")
                                .font(.system(size: 11))
                                .foregroundColor(isDateBeforeLiChun ? .orange : Color.yanCyan)
                            Text(liChunExplanationText)
                                .adaptiveFont(size: 10.5)
                                .foregroundColor(isDateBeforeLiChun ? .orange : .white.opacity(0.8))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                } else {
                    // 年份快速选择器
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Button(action: {
                                selectedYear = max(1920, selectedYear - 10)
                            }) {
                                Text("-10")
                                    .adaptiveFont(size: 11, weight: .bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .foregroundColor(.white.opacity(0.9))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                selectedYear = max(1920, selectedYear - 1)
                            }) {
                                Text("-1")
                                    .adaptiveFont(size: 11, weight: .bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .foregroundColor(.white.opacity(0.9))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Spacer()

                            Menu {
                                ForEach((1920...2026).reversed(), id: \.self) { yr in
                                    Button(action: { selectedYear = yr }) {
                                        HStack {
                                            Text("\(String(yr))年")
                                            if yr == selectedYear {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("\(String(selectedYear))年")
                                        .adaptiveFont(size: 14, weight: .bold)
                                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Spacer()

                            Button(action: {
                                selectedYear = min(2026, selectedYear + 1)
                            }) {
                                Text("+1")
                                    .adaptiveFont(size: 11, weight: .bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .foregroundColor(.white.opacity(0.9))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                selectedYear = min(2026, selectedYear + 10)
                            }) {
                                Text("+10")
                                    .adaptiveFont(size: 11, weight: .bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .foregroundColor(.white.opacity(0.9))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                }

                // 4. 乾造 (男) / 坤造 (女) 选择
                HStack(spacing: 10) {
                    Button(action: { selectedIsMale = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.stand")
                            Text(maleTitle)
                        }
                        .adaptiveFont(size: 12, weight: selectedIsMale ? .bold : .medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedIsMale ? Color.yanCyan.opacity(0.28) : Color.white.opacity(0.06))
                        .foregroundColor(selectedIsMale ? .yanCyan : .white.opacity(0.75))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(selectedIsMale ? Color.yanCyan : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { selectedIsMale = false }) {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.stand.dress")
                            Text(femaleTitle)
                        }
                        .adaptiveFont(size: 12, weight: !selectedIsMale ? .bold : .medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(!selectedIsMale ? Color(red: 0.95, green: 0.5, blue: 0.7).opacity(0.28) : Color.white.opacity(0.06))
                        .foregroundColor(!selectedIsMale ? Color(red: 0.95, green: 0.5, blue: 0.7) : .white.opacity(0.75))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(!selectedIsMale ? Color(red: 0.95, green: 0.5, blue: 0.7) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // 5. 实时命卦与人宅合一配对卡
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("【\(calculatedGuaKey)卦 · \(isEastLife ? eastLifeText : westLifeText) · \(ganzhiAndZodiac)】")
                            .adaptiveFont(size: 12, weight: .bold)
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Spacer()
                        Text(isMatched ? matchedBadgeText : unmatchedBadgeText)
                            .adaptiveFont(size: 10, weight: .bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((isMatched ? Color.green : Color.orange).opacity(0.25))
                            .foregroundColor(isMatched ? .green : .orange)
                            .cornerRadius(4)
                    }

                    Text(isMatched ? matchedAdviceText : unmatchedAdviceText)
                        .adaptiveFont(size: 10.5)
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider().background(Color.white.opacity(0.1))

                    // 四大吉方与四大凶方方位速查
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auspiciousHeader)
                                .adaptiveFont(size: 9.5, weight: .semibold)
                                .foregroundColor(.green.opacity(0.9))
                            Text(auspiciousSummary)
                                .adaptiveFont(size: 10)
                                .foregroundColor(.white.opacity(0.85))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(inauspiciousHeader)
                                .adaptiveFont(size: 9.5, weight: .semibold)
                                .foregroundColor(.red.opacity(0.9))
                            Text(inauspiciousSummary)
                                .adaptiveFont(size: 10)
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
                .padding(10)
                .background(Color(red: 0.12, green: 0.13, blue: 0.18))
                .cornerRadius(8)

                // 6. 底部操作按钮
                HStack(spacing: 10) {
                    Button(action: { isPresented = false }) {
                        Text(cancelTitle)
                            .adaptiveFont(size: 13)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white.opacity(0.85))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        if inputMode == 0 {
                            kua.updateOwnerBirth(date: selectedDate, isMale: selectedIsMale)
                        } else {
                            kua.updateOwnerBirthYear(selectedYear, isMale: selectedIsMale)
                        }
                        onSaved?()
                        isPresented = false
                    }) {
                        Text(saveButtonTitle)
                            .adaptiveFont(size: 13, weight: .bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.95, green: 0.8, blue: 0.35), Color(red: 0.75, green: 0.55, blue: 0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.black)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(16)
            .frame(maxWidth: 480)
        }
    }
    .preferredColorScheme(.dark)
    .onAppear {
        setupInitialValues()
    }
}

    private var auspiciousSummary: String {
        let chart = BaZhaiEngine.shared.analyze(sittingPalace: calculatedGuaKey, facingPalace: sittingPalace)
        let shengQi = chart.items.first(where: { $0.star == .shengQi })?.localizedDirection ?? "-"
        let yanNian = chart.items.first(where: { $0.star == .yanNian })?.localizedDirection ?? "-"
        let tianYi = chart.items.first(where: { $0.star == .tianYi })?.localizedDirection ?? "-"
        let fuWei = chart.items.first(where: { $0.star == .fuWei })?.localizedDirection ?? "-"
        switch lang.effectiveLanguage {
        case .en:
            return "Wealth:\(shengQi) · Health:\(tianYi) · Harmony:\(yanNian)"
        default:
            return "财位:\(shengQi) · 康健:\(tianYi) · 合谐:\(yanNian) · 文昌:\(fuWei)"
        }
    }

    private var inauspiciousSummary: String {
        let chart = BaZhaiEngine.shared.analyze(sittingPalace: calculatedGuaKey, facingPalace: sittingPalace)
        let jueMing = chart.items.first(where: { $0.star == .jueMing })?.localizedDirection ?? "-"
        let wuGui = chart.items.first(where: { $0.star == .wuGui })?.localizedDirection ?? "-"
        let liuSha = chart.items.first(where: { $0.star == .liuSha })?.localizedDirection ?? "-"
        let huoHai = chart.items.first(where: { $0.star == .huoHai })?.localizedDirection ?? "-"
        switch lang.effectiveLanguage {
        case .en:
            return "Fatal:\(jueMing) · Ghost:\(wuGui) · Mishap:\(huoHai)"
        default:
            return "绝命:\(jueMing) · 五鬼:\(wuGui) · 六煞:\(liuSha) · 祸害:\(huoHai)"
        }
    }

    private var liChunExplanationText: String {
        let y = effectiveFengShuiYear
        if isDateBeforeLiChun {
            switch lang.effectiveLanguage {
            case .en:
                return "Born before Li Chun (Feb 4). Life Gua calculated using previous Feng Shui year (\(y))."
            case .zhHant, .ja:
                return "公曆立春（約2月4日）前出生，依風水歲首以立春前一年【\(ganzhiAndZodiac)】（\(y)年）核算命卦。"
            default:
                return "公历立春（约2月4日）前出生，依风水岁首以立春前一年【\(ganzhiAndZodiac)】（\(y)年）核算命卦。"
            }
        } else {
            switch lang.effectiveLanguage {
            case .en:
                return "Feng Shui year: \(ganzhiAndZodiac) (\(y))."
            default:
                return "对应风水流年：\(ganzhiAndZodiac)（\(y)年）。"
            }
        }
    }

    private var dialogTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Edit House Master Life Gua & Birth Date"
        case .zhHant: return "修改宅主生辰日期與命卦"
        case .ja: return "家主の生年月日・本命卦を変更"
        case .ko: return "건축주 생년월일 및 본명괘 수정"
        case .vi: return "Sửa Ngày Sinh & Bản Mệnh Trạch Chủ"
        case .th: return "แก้ไขวันเกิดและรหัสชีวิตเจ้าของบ้าน"
        case .id: return "Ubah Tanggal Lahir & Gua Pemilik"
        case .auto, .zhHans: return "修改宅主生辰日期与命卦"
        }
    }

    private var modeDateLabel: String {
        switch lang.effectiveLanguage {
        case .en: return "Exact Birth Date"
        case .zhHant: return "公曆年月日"
        case .ja: return "生年月日"
        case .ko: return "생년월일"
        case .vi: return "Ngày sinh"
        case .th: return "วันเกิด"
        case .id: return "Tanggal Lahir"
        case .auto, .zhHans: return "公历年月日"
        }
    }

    private var modeYearLabel: String {
        switch lang.effectiveLanguage {
        case .en: return "Birth Year"
        case .zhHant: return "出生年份"
        case .ja: return "生まれ年"
        case .ko: return "출생연도"
        case .vi: return "Năm sinh"
        case .th: return "ปีเกิด"
        case .id: return "Tahun Lahir"
        case .auto, .zhHans: return "出生年份"
        }
    }

    private var datePickerHint: String {
        switch lang.effectiveLanguage {
        case .en: return "Select Birthday:"
        case .zhHant: return "選擇公曆生日："
        case .ja: return "誕生日を選択："
        case .ko: return "생년월일 선택:"
        case .vi: return "Chọn ngày sinh:"
        case .th: return "เลือกวันเกิด:"
        case .id: return "Pilih Tanggal Lahir:"
        case .auto, .zhHans: return "选择公历生日："
        }
    }

    private var maleTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Male"
        case .zhHant, .ja: return "乾造 (男)"
        case .ko: return "건조 (남)"
        case .vi: return "Càn Tạo (Nam)"
        case .th: return "ชาย"
        case .id: return "Pria"
        case .auto, .zhHans: return "乾造 (男)"
        }
    }

    private var femaleTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Female"
        case .zhHant, .ja: return "坤造 (女)"
        case .ko: return "곤조 (여)"
        case .vi: return "Khôn Tạo (Nữ)"
        case .th: return "หญิง"
        case .id: return "Wanita"
        case .auto, .zhHans: return "坤造 (女)"
        }
    }

    private var eastLifeText: String {
        switch lang.effectiveLanguage {
        case .en: return "East 4 Life"
        case .zhHant, .ja: return "東四命"
        case .ko: return "동사명"
        case .vi: return "Đông Tứ Mệnh"
        case .th: return "ดวงตะวันออก"
        case .id: return "Gua Timur"
        case .auto, .zhHans: return "东四命"
        }
    }

    private var westLifeText: String {
        switch lang.effectiveLanguage {
        case .en: return "West 4 Life"
        case .zhHant, .ja: return "西四命"
        case .ko: return "서사명"
        case .vi: return "Tây Tứ Mệnh"
        case .th: return "ดวงตะวันตก"
        case .id: return "Gua Barat"
        case .auto, .zhHans: return "西四命"
        }
    }

    private var matchedBadgeText: String {
        switch lang.effectiveLanguage {
        case .en: return "House & Master Matched"
        case .zhHant: return "宅命相配 · 人宅合一"
        case .ja: return "宅命相配・人宅合一"
        case .ko: return "택명상배 · 인택합일"
        case .vi: return "Trạch Mệnh Tương Phối"
        case .th: return "สมดุลคนและบ้าน"
        case .id: return "Selaras Manusia & Rumah"
        case .auto, .zhHans: return "宅命相配 · 人宅合一"
        }
    }

    private var unmatchedBadgeText: String {
        switch lang.effectiveLanguage {
        case .en: return "Different Groups"
        case .zhHant: return "宅命不同組 · 宜起吉方"
        case .ja: return "宅命異組・吉方調候"
        case .ko: return "택명상이 · 길방조후"
        case .vi: return "Khác Cung · Dùng Cát Phương"
        case .th: return "คนละกลุ่ม · ปรับทิศมงคล"
        case .id: return "Beda Kelompok · Gunakan Arah Baik"
        case .auto, .zhHans: return "宅命不同组 · 宜起吉方"
        }
    }

    private var matchedAdviceText: String {
        switch lang.effectiveLanguage {
        case .en:
            return "Auspicious! The owner's life group matches the house's sitting energy, producing harmonious qi and fortune."
        case .zhHant:
            return "大吉！宅主命卦與宅盤五行同組相生，同氣相求，宅氣與人氣和諧共振，人宅兩旺。"
        case .ja:
            return "大吉！家主の本命卦と建物の座向が同組となり、人と家の気が調和して繁栄をもたらします。"
        case .ko:
            return "대길! 건축주의 본명괘와 건물의 좌향이 동조를 이루어 사람과 집의 기운이 조화롭게 번영합니다."
        case .vi:
            return "Đại cát! Mệnh quái trạch chủ đồng khí với trạch quái, nhân trạch hòa hợp, tài vận hanh thông."
        case .th:
            return "มงคลยิ่ง! รหัสชีวิตเจ้าของบ้านสมดุลกับทิศบ้าน พลังคนและบ้านสอดคล้อง นำพาความเจริญ"
        case .id:
            return "Sangat menguntungkan! Energi pemilik selaras dengan energi rumah, menghasilkan harmoni dan rezeki."
        case .auto, .zhHans:
            return "大吉！宅主命卦与宅盘五行同组相生，同气相求，宅气与人气和谐共振，人宅两旺。"
        }
    }

    private var unmatchedAdviceText: String {
        switch lang.effectiveLanguage {
        case .en:
            return "The owner and house belong to different groups. Prioritize placing the master bedroom and study in the owner's auspicious directions to balance the energy."
        case .zhHant:
            return "宅主與宅盤分屬不同組。建議將主臥室、辦公桌或書房安放於宅主本命之吉方（生氣、延年、天醫），以本命真氣調候宅氣。"
        case .ja:
            return "家主と建物が異なる組です。主寝室や書斎を家主の本命吉方位（生気・延年・天医）に配置して気を調和させましょう。"
        case .ko:
            return "건축주와 건물이 다른 조에 속합니다. 안방이나 서재를 본명 길방(생기·연년·천의)에 배치하여 기운을 조화롭게 다스리십시오."
        case .vi:
            return "Trạch chủ và nhà khác nhóm. Nên bố trí phòng ngủ chính hoặc bàn làm việc tại phương vị cát của bản mệnh để điều hòa."
        case .th:
            return "เจ้าของบ้านและบ้านอยู่คนละกลุ่ม แนะนำจัดห้องนอนหรือโต๊ะทำงานในทิศมงคลของเจ้าของบ้านเพื่อปรับสมดุลพลัง"
        case .id:
            return "Pemilik dan rumah berbeda kelompok. Tempatkan kamar utama atau ruang kerja di arah keberuntungan pemilik untuk menyeimbangkan energi."
        case .auto, .zhHans:
            return "宅主与宅盘分属不同组。建议将主卧室、办公桌或书房安放于宅主本命之吉方（生气、延年、天医），以本命真气调候宅气。"
        }
    }

    private var auspiciousHeader: String {
        switch lang.effectiveLanguage {
        case .en: return "Auspicious Directions"
        case .zhHant, .ja: return "四大吉方"
        case .ko: return "4대 길방"
        case .vi: return "Tứ Đại Cát Phương"
        case .th: return "4 ทิศมงคล"
        case .id: return "4 Arah Baik"
        case .auto, .zhHans: return "四大吉方"
        }
    }

    private var inauspiciousHeader: String {
        switch lang.effectiveLanguage {
        case .en: return "Inauspicious Directions"
        case .zhHant, .ja: return "四大凶方"
        case .ko: return "4대 흉방"
        case .vi: return "Tứ Đại Hung Phương"
        case .th: return "4 ทิศอัปมงคล"
        case .id: return "4 Arah Buruk"
        case .auto, .zhHans: return "四大凶方"
        }
    }

    private var cancelTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Cancel"
        case .zhHant: return "取消"
        case .ja: return "キャンセル"
        case .ko: return "취소"
        case .vi: return "Hủy"
        case .th: return "ยกเลิก"
        case .id: return "Batal"
        case .auto, .zhHans: return "取消"
        }
    }

    private var saveButtonTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Save & Update Life Gua"
        case .zhHant: return "保存生辰並更新命卦"
        case .ja: return "保存して本命卦を更新"
        case .ko: return "저장 및 본명괘 업데이트"
        case .vi: return "Lưu & Cập nhật Bản mệnh"
        case .th: return "บันทึกและอัปเดตรหัสชีวิต"
        case .id: return "Simpan & Perbarui Gua"
        case .auto, .zhHans: return "保存生辰并更新命卦"
        }
    }
}

    private enum Sheet: String, Identifiable {
        case editOwnerKua, addFamilyMember
        var id: String { rawValue }
    }
