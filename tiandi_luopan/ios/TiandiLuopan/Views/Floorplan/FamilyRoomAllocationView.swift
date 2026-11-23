import SwiftUI

struct FamilyRoomAllocationSection: View {
    let rooms: [FloorplanRoom]
    let centroid: CGPoint
    let heading: Double
    let aspectRatio: CGFloat
    let houseContext: CompassHeadingState
    let manualAssignments: [FamilyRoomAssignment]?
    @Binding var showLabels: Bool
    let onUpdate: ([FamilyRoomAssignment]?) -> Void
    @ObservedObject private var iap = StoreKitIAPManager.shared
    @ObservedObject private var profile = UserKuaProfileManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @State private var showEditor = false
    @State private var showProfiles = false
    @State private var showPaywall = false

    init(rooms: [FloorplanRoom], centroid: CGPoint, heading: Double, aspectRatio: CGFloat,
         houseContext: CompassHeadingState, manualAssignments: [FamilyRoomAssignment]?,
         showLabels: Binding<Bool>, onUpdate: @escaping ([FamilyRoomAssignment]?) -> Void) {
        self.rooms = rooms
        self.centroid = centroid
        self.heading = heading
        self.aspectRatio = aspectRatio
        self.houseContext = houseContext
        self.manualAssignments = manualAssignments
        self._showLabels = showLabels
        self.onUpdate = onUpdate
    }

    private var people: [FamilyRoomPerson] { FamilyRoomAllocationEngine.people(profile: profile) }
    private var assignments: [FamilyRoomAssignment] {
        FamilyRoomAllocationEngine.resolve(manual: manualAssignments, rooms: rooms, people: people,
            centroid: centroid, heading: heading, aspectRatio: aspectRatio, hasMembershipAccess: iap.canUseFamilyRoomAllocation)
    }

    private var unassignedPeople: [FamilyRoomPerson] {
        let plan = assignments
        return people.filter { person in
            !plan.contains { assignment in
                assignment.personID == person.id && rooms.contains { $0.id == assignment.roomID && $0.type != .study }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.padM) {
            HStack {
                Label(lang.t("fra_title"), systemImage: "person.2.fill")
                    .adaptiveFont(size: 14, weight: .semibold)
                Spacer()
                // VIP 徽章卡片化：锁图标 + 描边，明确这是可点的会员入口
                HStack(spacing: 4) {
                    Image(systemName: "lock.circle.fill")
                    Text(lang.t("fra_membership"))
                }
                .adaptiveFont(size: DS.minBodyFont, weight: .bold)
                .foregroundColor(.goldText)
                .padding(.horizontal, DS.padS)
                .padding(.vertical, 4)
                .background(Color.goldPrimary.opacity(0.14))
                .cornerRadius(DS.radiusS)
                .overlay(RoundedRectangle(cornerRadius: DS.radiusS).stroke(Color.strokeGold, lineWidth: 1))
            }
            if !iap.canUseFamilyRoomAllocation {
                Text(lang.t("fra_paywall"))
                    .adaptiveFont(size: 12).foregroundColor(.white.opacity(0.7))
                Button(lang.t("fra_unlock")) { showPaywall = true }
                    .buttonStyle(DSPrimaryButtonStyle())
            } else if !profile.isProfileEnabled {
                Button(lang.t("fra_add_family")) { showProfiles = true }
                    .buttonStyle(DSPrimaryButtonStyle())
            } else {
                Toggle(lang.t("fra_show_labels"), isOn: $showLabels)
                    .adaptiveFont(size: 12)
                HStack(spacing: DS.padS) {
                    Button(lang.t("fra_manage")) { showEditor = true }
                        .buttonStyle(DSSecondaryButtonStyle())
                    Button(lang.t("fra_add_family")) { showProfiles = true }
                        .buttonStyle(DSSecondaryButtonStyle())
                }
                if assignments.isEmpty {
                    // 空状态补操作引导，而非一行孤零零的文字
                    VStack(spacing: DS.padS) {
                        Image(systemName: "person.2.slash").font(.title2).foregroundColor(.semWarn)
                        Text(lang.t("fra_no_match")).adaptiveFont(size: 12).foregroundColor(.semWarn)
                        Button(lang.t("fra_add_family")) { showProfiles = true }
                            .buttonStyle(DSSecondaryButtonStyle())
                    }.frame(maxWidth: .infinity)
                }
                else if !unassignedPeople.isEmpty {
                    Text(unassignedPeople.map(\.name).joined(separator: "、") + " · " + lang.t("fra_no_bedroom"))
                        .adaptiveFont(size: 12).foregroundColor(.semWarn)
                }
                Text(lang.t(manualAssignments == nil ? "fra_suggested" : "fra_assigned"))
                    .adaptiveFont(size: DS.minBodyFont).foregroundColor(.semInfo)
            }
        }
        .foregroundColor(.white)
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .sheet(isPresented: $showPaywall) { VIPPaywallSheet(defaultProductId: .vipYearly) }
        .sheet(isPresented: $showProfiles) {
            OwnerLifeGuaView(context: houseContext)
        }
        .sheet(isPresented: $showEditor) {
            NavigationView {
                Group {
                    if iap.canUseFamilyRoomAllocation && profile.isProfileEnabled { editor }
                    else { Text(lang.t("fra_paywall")).padding() }
                }
                .navigationTitle(lang.t("fra_title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) {
                    Button(lang.t("done")) { showEditor = false }
                } }
                .background(Color(red: 0.086, green: 0.075, blue: 0.059).ignoresSafeArea())
                .foregroundColor(.white)
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(lang.t("fra_note")).adaptiveFont(size: 12).foregroundColor(.white.opacity(0.7))
                HStack {
                    Button(lang.t("fra_auto")) { onUpdate(nil) }
                    Spacer()
                    Button(lang.t("fra_clear")) { onUpdate([]) }
                }.buttonStyle(.bordered)
                if !rooms.contains(where: FamilyRoomAllocationEngine.isAssignable) {
                    Text(lang.t("fra_no_rooms")).foregroundColor(.semWarn)
                }
                ForEach(rooms.filter(FamilyRoomAllocationEngine.isAssignable)) { room in
                    roomCard(room)
                }
                ForEach(unassignedPeople) { person in
                    Text(person.name + " · " + lang.t("fra_no_bedroom"))
                        .adaptiveFont(size: 12).foregroundColor(.semWarn)
                }
            }.padding(16)
        }
    }

    private func roomCard(_ room: FloorplanRoom) -> some View {
        let fits = FamilyRoomAllocationEngine.fits(room: room, rooms: rooms, people: people,
            centroid: centroid, heading: heading, aspectRatio: aspectRatio)
        return VStack(alignment: .leading, spacing: 10) {
            Label(room.name + " · " + room.palaceName, systemImage: room.type.iconName)
                .adaptiveFont(size: 14, weight: .bold)
            ForEach(fits, id: \.person.id) { fit in
                let selected = assignments.contains { $0.roomID == room.id && $0.personID == fit.person.id }
                Button {
                    // 无权限时不再静默无响应：明确拉起付费页
                    guard iap.canUseFamilyRoomAllocation else { showPaywall = true; return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onUpdate(FamilyRoomAllocationEngine.toggling(personID: fit.person.id, room: room,
                        assignments: assignments, rooms: rooms, people: people))
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selected ? .semInfo : .gray)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(fit.person.name).adaptiveFont(size: 14, weight: .semibold)
                                Spacer()
                                Text(lang.t(fit.isRecommended ? "fra_good" : "fra_check"))
                                    .adaptiveFont(size: DS.minBodyFont)
                                    .foregroundColor(fit.isRecommended ? .semJi : .semWarn)
                            }
                            Text(lang.t(fit.reasonKey)).adaptiveFont(size: 12).foregroundColor(.white.opacity(0.7))
                            if let star = fit.star {
                                Text(star.localizedName).adaptiveFont(size: DS.minBodyFont).foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    .padding(DS.padM)
                    .frame(maxWidth: .infinity, minHeight: DS.touchMin, alignment: .leading)
                    .background(selected ? Color.semInfo.opacity(0.12) : Color.white.opacity(0.03))
                    .cornerRadius(DS.radiusS)
                    .overlay(RoundedRectangle(cornerRadius: DS.radiusS)
                        .stroke(selected ? Color.semInfo.opacity(0.4) : Color.clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(fit.person.name)：\(selected ? "已分配" : "未分配")")
            }
        }.padding(12).background(Color.white.opacity(0.05)).cornerRadius(12)
    }
}
