import SwiftUI

/// 家人分房面板。原来是以 FamilyRoomAllocationSection 的身份嵌在户型页的滚动中段，
/// 用户要滑过画布、工具条、标注才看得到；现在是独立 sheet，从户型页操作条进入。
struct FamilyRoomAllocationPanel: View {
    let rooms: [FloorplanRoom]
    let centroid: CGPoint
    let heading: Double
    let aspectRatio: CGFloat
    let houseContext: CompassHeadingState
    let manualAssignments: [FamilyRoomAssignment]?
    let onUpdate: ([FamilyRoomAssignment]?) -> Void
    @Binding var showLabels: Bool

    @ObservedObject private var profile = UserKuaProfileManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @Environment(\.presentationMode) private var presentationMode
    @State private var showProfiles = false

    private var people: [FamilyRoomPerson] { FamilyRoomAllocationEngine.people(profile: profile) }

    private var assignments: [FamilyRoomAssignment] {
        FamilyRoomAllocationEngine.resolve(manual: manualAssignments, rooms: rooms, people: people,
            centroid: centroid, heading: heading, aspectRatio: aspectRatio, hasMembershipAccess: true)
    }

    private var assignableRooms: [FloorplanRoom] {
        rooms.filter(FamilyRoomAllocationEngine.isAssignable)
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
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !profile.isProfileEnabled {
                        // 没有家人档案时，面板里唯一该做的事就是先建档案。
                        VStack(alignment: .leading, spacing: 10) {
                            Text(lang.t("fra_note"))
                                .adaptiveFont(size: 12)
                                .foregroundColor(.white.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                            Button(lang.t("fra_add_family")) { showProfiles = true }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.yanCyan)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appInkRaised)
                        .cornerRadius(12)
                    } else {
                        summaryRow
                        actionRow

                        if assignments.isEmpty {
                            Text(lang.t("fra_no_match"))
                                .adaptiveFont(size: 12)
                                .foregroundColor(Color(red: 0.97, green: 0.48, blue: 0.58))
                        }

                        ForEach(assignableRooms) { room in
                            roomCard(room)
                        }

                        ForEach(unassignedPeople) { person in
                            Text(person.name + " · " + lang.t("fra_no_bedroom"))
                                .adaptiveFont(size: 12)
                                .foregroundColor(Color(red: 0.97, green: 0.48, blue: 0.58))
                        }
                    }
                }
                .padding(16)
                .foregroundColor(.white)
            }
            .background(Color.appInk.ignoresSafeArea())
            .navigationTitle(lang.t("fra_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(lang.t("done")) { presentationMode.wrappedValue.dismiss() }
                }
            }
            .sheet(isPresented: $showProfiles) {
                OwnerLifeGuaView(context: houseContext)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - 状态与动作

    private var summaryRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.2.fill")
                .foregroundColor(Color.yanCyan)
            Text(assignedPeopleCount + " / " + String(assignableRooms.count))
                .adaptiveFont(size: 13, weight: .bold)
                .foregroundColor(.white)
            Spacer(minLength: 0)
            Text(lang.t(manualAssignments == nil ? "fra_suggested" : "fra_assigned"))
                .adaptiveFont(size: 11)
                .foregroundColor(Color.yanGoldSoft)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.appInkRaised)
        .cornerRadius(12)
    }

    private var assignedPeopleCount: String {
        String(people.count - unassignedPeople.count)
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button(lang.t("fra_auto")) { onUpdate(nil) }
                .buttonStyle(.borderedProminent)
                .tint(Color.yanGold)
                .foregroundColor(.black)
            Button(lang.t("fra_clear")) { onUpdate([]) }
                .buttonStyle(.bordered)
            Spacer(minLength: 0)
            Toggle(lang.t("fra_show_labels"), isOn: $showLabels)
                .adaptiveFont(size: 11)
        }
        .adaptiveFont(size: 12)
    }

    // MARK: - 房间卡片

    private func roomCard(_ room: FloorplanRoom) -> some View {
        let fits = FamilyRoomAllocationEngine.fits(room: room, rooms: rooms, people: people,
            centroid: centroid, heading: heading, aspectRatio: aspectRatio)
        return VStack(alignment: .leading, spacing: 10) {
            Label(room.name + " · " + room.palaceName, systemImage: room.type.iconName)
                .adaptiveFont(size: 14, weight: .bold)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(fits, id: \.person.id) { fit in
                let selected = assignments.contains { $0.roomID == room.id && $0.personID == fit.person.id }
                Button {
                    onUpdate(FamilyRoomAllocationEngine.toggling(personID: fit.person.id, room: room,
                        assignments: assignments, rooms: rooms, people: people))
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selected ? Color.yanGold : .gray)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(fit.person.name)
                                    .adaptiveFont(size: 14, weight: .semibold)
                                    .foregroundColor(.white)
                                Spacer(minLength: 4)
                                // 三档色标：大中吉金黄、小吉青绿、凶位粉。
                                // 全 App 只有这里用颜色直接下结论。
                                Text(fit.star?.localizedName ?? lang.t("fra_check"))
                                    .adaptiveFont(size: 10, weight: .bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(tierColor(fit.star).opacity(0.18))
                                    .foregroundColor(tierColor(fit.star))
                                    .cornerRadius(5)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(lang.t(fit.reasonKey))
                                .adaptiveFont(size: 12)
                                .foregroundColor(.white.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                    .background(selected ? Color.yanGold.opacity(0.12) : Color.white.opacity(0.03))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appInkRaised)
        .cornerRadius(12)
    }

    /// 吉位分三档：生气、延年、天医为金；伏位为青；其余凶位为粉。
    private func tierColor(_ star: StarLuckType?) -> Color {
        switch star {
        case .shengQi?, .yanNian?, .tianYi?:
            return Color.yanGold
        case .fuWei?:
            return Color.yanCyan
        case nil:
            return Color.white.opacity(0.45)
        default:
            // 绝命、五鬼、六煞、祸害
            return Color(red: 0.97, green: 0.48, blue: 0.58)
        }
    }
}
