const store = require('../../utils/store');
const BZ = require('../../utils/bazhai');
const nav = require('../../utils/nav');

const ROLES = ['本人', '配偶', '子女', '父母', '其他'];

// iOS AddFamilyMemberDialog：角色预设（性别 + 参考出生年）
const ROLE_PRESETS = {
  '配偶': { gender: 'female', yearOffset: -2 },
  '子女': { gender: 'male', yearOffset: -25 },
  '父母': { gender: 'male', yearOffset: -28 },
  '其他': { gender: 'male', yearOffset: 0 }
};

/** iOS isDateBeforeLiChun / effectiveFengShuiYear：立春（约 2/4）前出生算上一年 */
function effectiveFengShuiYear(year, month, day) {
  const y = parseInt(year, 10);
  if (month < 2 || (month === 2 && day < 4)) return y - 1;
  return y;
}

function guaOf(year, gender) {
  try {
    const g = BZ.lifeGua(year, gender);
    return g || null;
  } catch (e) {
    return null;
  }
}

Page({
  data: {
    owner: null,
    ownerName: '',
    ownerBirthYear: '',
    ownerGenderIdx: 0,
    members: [],
    memberRows: [],
    roles: ROLES,
    hasData: false
  },

  onLoad() {
    this.load();
  },

  load() {
    const p = store.getProfiles() || { owner: null, members: [] };
    const owner = p.owner || null;
    const members = p.members || [];
    const rows = members.map((m, i) => {
      const g = guaOf(m.birthYear, m.gender);
      return {
        idx: i,
        role: m.role || '家人',
        name: m.name || '',
        birthYear: m.birthYear || '',
        genderIdx: m.gender === 'female' ? 1 : 0,
        gender: m.gender === 'male' ? '男' : '女',
        gua: g && g.name ? `${g.name}（${g.full || ''}）` : '',
        desc: g ? `${g.gender} · ${g.elem} · ${g.group || ''}` : '',
        elem: g && g.elem ? g.elem : ''
      };
    });
    this.setData({
      owner,
      ownerName: owner ? (owner.name || '') : '',
      ownerBirthYear: owner && owner.birthYear ? String(owner.birthYear) : '',
      ownerGenderIdx: owner && owner.gender === 'female' ? 1 : 0,
      members,
      memberRows: rows,
      hasData: !!(owner || members.length)
    });
  },

  onOwnerName(e) { this.setData({ ownerName: e.detail.value }); },
  onOwnerYear(e) { this.setData({ ownerBirthYear: e.detail.value }); },
  onOwnerGender(e) { this.setData({ ownerGenderIdx: e.detail.value ? 1 : 0 }); },

  saveOwner() {
    const year = parseInt(this.data.ownerBirthYear, 10);
    if (!year || year < 1900 || year > 2100) {
      wx.showToast({ title: '请填写 1900–2100 的出生年', icon: 'none' });
      return;
    }
    const p = store.getProfiles() || { owner: null, members: [] };
    p.owner = {
      name: this.data.ownerName || '宅主',
      birthYear: year,
      gender: this.data.ownerGenderIdx === 1 ? 'female' : 'male'
    };
    store.saveProfiles(p);
    const s = store.getSettings() || {};
    s.ownerBirthYear = year;
    store.saveSettings(s);
    this.load();
    wx.showToast({ title: '宅主档案已保存', icon: 'success' });
  },

  addMember() {
    // iOS AddFamilyMemberDialog.applyRolePreset：按角色预填性别/参考出生年
    wx.showActionSheet({
      itemList: ROLES,
      success: (res) => {
        const role = ROLES[res.tapIndex];
        const preset = ROLE_PRESETS[role] || { gender: 'male', yearOffset: 0 };
        const p = store.getProfiles() || { owner: null, members: [] };
        const members = (p.members || []).slice();
        const baseYear = p.owner && p.owner.birthYear ? parseInt(p.owner.birthYear, 10) : 1990;
        members.push({
          role,
          name: role + (members.length + 1),
          birthYear: baseYear + preset.yearOffset,
          gender: preset.gender
        });
        p.members = members;
        store.saveProfiles(p);
        this.load();
        wx.showToast({ title: `已按「${role}」预填，可改出生年`, icon: 'none' });
      }
    });
  },

  onMemberName(e) {
    const i = parseInt(e.currentTarget.dataset.idx, 10);
    const val = e.detail.value;
    if (!val) return;
    const p = store.getProfiles() || { owner: null, members: [] };
    const members = (p.members || []).slice();
    if (!members[i]) return;
    members[i] = Object.assign({}, members[i], { name: val });
    p.members = members;
    store.saveProfiles(p);
    this.load();
  },

  editMember(e) {
    const i = parseInt(e.currentTarget.dataset.idx, 10);
    const m = (this.data.members || [])[i];
    if (!m) return;
    wx.showActionSheet({
      itemList: ROLES,
      success: (res) => {
        const p = store.getProfiles() || { owner: null, members: [] };
        const members = (p.members || []).slice();
        members[i] = Object.assign({}, members[i], { role: ROLES[res.tapIndex] });
        p.members = members;
        store.saveProfiles(p);
        this.load();
      }
    });
  },

  onMemberYear(e) {
    const i = parseInt(e.currentTarget.dataset.idx, 10);
    const val = parseInt(e.detail.value, 10);
    if (!val) return;
    const p = store.getProfiles() || { owner: null, members: [] };
    const members = (p.members || []).slice();
    members[i] = Object.assign({}, members[i], { birthYear: val });
    p.members = members;
    store.saveProfiles(p);
    this.load();
  },

  onMemberGender(e) {
    const i = parseInt(e.currentTarget.dataset.idx, 10);
    const p = store.getProfiles() || { owner: null, members: [] };
    const members = (p.members || []).slice();
    members[i] = Object.assign({}, members[i], { gender: e.detail.value ? 'female' : 'male' });
    p.members = members;
    store.saveProfiles(p);
    this.load();
  },

  removeMember(e) {
    const i = parseInt(e.currentTarget.dataset.idx, 10);
    const m = (this.data.members || [])[i];
    if (!m) return;
    wx.showModal({
      title: '删除家人',
      content: `确认删除「${m.role}」？删除后不可恢复。`,
      confirmText: '删除',
      confirmColor: '#e74c3c',
      success: (res) => {
        if (!res.confirm) return;
        const p = store.getProfiles() || { owner: null, members: [] };
        const members = (p.members || []).slice();
        members.splice(i, 1);
        p.members = members;
        store.saveProfiles(p);
        this.load();
        wx.showToast({ title: '已删除', icon: 'none' });
      }
    });
  },

  clearAll() {
    wx.showModal({
      title: '清空家庭资料',
      content: '将删除宅主与全部家人资料，本命卦与分房分析将回到默认值。此操作不可恢复。',
      confirmText: '清空',
      confirmColor: '#e74c3c',
      success: (res) => {
        if (!res.confirm) return;
        const p = store.getProfiles() || { owner: null, members: [] };
        p.owner = null;
        p.members = [];
        store.saveProfiles(p);
        const s = store.getSettings() || {};
        s.ownerBirthYear = null;
        store.saveSettings(s);
        this.load();
        wx.showToast({ title: '已清空', icon: 'none' });
      }
    });
  },

  goBazhai() { wx.navigateTo({ url: '/pages/bazhai/index' }); },

  back() { nav.back(); },

  onShareAppMessage() {
    return { title: '演象时空罗盘 · 家庭资料', path: '/pages/index/index' };
  }
});
