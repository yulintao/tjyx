const BZ = require('../../utils/bazhai');
const SF = require('../../utils/sitface');
const store = require('../../utils/store');
const orientation = require('../../utils/orientation');

const DISPLAY = [4, 9, 2, 3, 5, 7, 8, 1, 6];

Page({
  data: {
    sitIdx: 0,
    sit: '子',
    mountainNames: SF.MOUNTAINS_24.map((m) => `${m} 山`),
    houseGua: '坎',
    houseGroup: '',
    year: 1980,
    genderIdx: 0,
    genderNames: ['男', '女'],
    life: null,
    compat: null,
    cells: [],
    picked: null,
    members: [],
    memberRows: [],
    tasks: [],
    tasksDone: 0
  },

  onLoad(options) {
    let sit = orientation.current().sit;
    if (options && options.sit && SF.MOUNTAINS_24.indexOf(options.sit) >= 0) sit = options.sit;
    const saved = store.getProfiles();
    const members = (saved && saved.members && saved.members.length)
      ? saved.members
      : [
        { role: '本人', birthYear: 1980, gender: 'male' },
        { role: '配偶', birthYear: 1985, gender: 'female' },
        { role: '子女', birthYear: 2012, gender: 'female' }
      ];
    this.setData({
      sitIdx: SF.MOUNTAINS_24.indexOf(sit),
      members: members,
      year: members[0].birthYear || 1980,
      genderIdx: members[0].gender === 'male' ? 0 : 1
    });
    this.persistMembers();
    this.recompute();
  },

  persistMembers() {
    const profiles = store.getProfiles() || { owner: null, members: [] };
    profiles.members = this.data.members;
    store.saveProfiles(profiles);
  },

  addMember() {
    const members = this.data.members.slice();
    members.push({ role: '家人' + (members.length + 1), birthYear: 1990, gender: 'male' });
    this.setData({ members });
    this.persistMembers();
    this.recompute();
  },

  removeMember(e) {
    const i = parseInt(e.currentTarget.dataset.idx, 10);
    if (this.data.members.length <= 1) {
      wx.showToast({ title: '至少保留一位家人', icon: 'none' });
      return;
    }
    wx.showModal({
      title: '删除家人',
      content: `确认删除「${this.data.members[i].role}」？`,
      success: (res) => {
        if (!res.confirm) return;
        const members = this.data.members.slice();
        members.splice(i, 1);
        this.setData({ members });
        this.persistMembers();
        this.recompute();
      }
    });
  },

  toggleTask(e) {
    const id = e.currentTarget.dataset.id;
    const title = e.currentTarget.dataset.title;
    store.toggleRemedyTask({ id, title, source: 'bazhai' });
    this.refreshTasks(this._remedies || []);
  },

  refreshTasks(remedies) {
    const done = store.getRemedyTasks();
    const doneIds = done.filter((t) => t.done).map((t) => t.id);
    const tasks = remedies.map((r) => Object.assign({}, r, { done: doneIds.indexOf(r.id) >= 0 }));
    this.setData({ tasks, tasksDone: tasks.filter((t) => t.done).length });
  },

  onSitChange(e) {
    const sitIdx = parseInt(e.detail.value, 10);
    this.setData({ sitIdx });
    orientation.fromManual(SF.MOUNTAINS_24[sitIdx]);
    const bar = this.selectComponent && this.selectComponent('ctx-bar');
    if (bar && bar.refresh) bar.refresh();
    this.recompute();
  },

  onYear(e) {
    this.setData({ year: parseInt(e.detail.value, 10) || 1980 });
    this.recompute();
  },

  onGender(e) {
    this.setData({ genderIdx: parseInt(e.detail.value, 10) });
    this.recompute();
  },

  onMemberYear(e) {
    const i = parseInt(e.currentTarget.dataset.idx, 10);
    const members = this.data.members.slice();
    members[i] = Object.assign({}, members[i], { birthYear: parseInt(e.detail.value, 10) || members[i].birthYear });
    this.setData({ members });
    this.persistMembers();
    this.recompute();
  },

  onMemberGender(e) {
    const i = parseInt(e.currentTarget.dataset.idx, 10);
    const members = this.data.members.slice();
    members[i] = Object.assign({}, members[i], { gender: parseInt(e.detail.value, 10) === 0 ? 'male' : 'female' });
    this.setData({ members });
    this.persistMembers();
    this.recompute();
  },

  onCell(e) {
    const p = parseInt(e.currentTarget.dataset.palace, 10);
    const cell = this.data.cells.filter((c) => c.palace === p)[0] || null;
    this.setData({ picked: cell && !cell.isCenter ? cell : null });
  },

  recompute() {
    const sit = SF.MOUNTAINS_24[this.data.sitIdx];
    const gua = SF.houseGuaName(sit);
    const roam = BZ.roamStars(gua);
    const life = BZ.lifeGua(this.data.year, this.data.genderIdx === 0 ? 'male' : 'female');
    const compat = BZ.compatibility(gua, life.num);
    const nayin = BZ.nayinCompat(gua, life.num, sit);

    const cells = DISPLAY.map((p) => {
      if (p === 5) {
        return { palace: 5, name: '中宫', star: '—', type: 'ping', isCenter: true, desc: '' };
      }
      const found = roam.cells.filter((c) => BZ.GUA_NUM_BY_NAME[c.palace] === p)[0];
      return {
        palace: p,
        name: found.palace,
        star: found.star,
        starName: found.starName,
        type: found.type,
        desc: found.use,
        lore: found.lore,
        use: found.use
      };
    });

    const memberRows = BZ.assignRooms(this.data.members, gua).map((row, i) => Object.assign({}, row, {
      zodiac: BZ.zodiacOf(this.data.members[i].birthYear)
    }));
    const remedies = BZ.remediesOf(roam);
    this._remedies = remedies;

    this.setData({
      sit,
      houseGua: gua,
      houseGroup: roam.group,
      life,
      compat,
      nayin,
      cells,
      picked: null,
      memberRows
    });
    this.refreshTasks(remedies);
  },

  back() { wx.navigateBack({ fail: () => wx.reLaunch({ url: '../index/index' }) }); }
,

  onShareAppMessage() {
    return { title: '演象时空罗盘 · 八宅明镜', path: '/pages/bazhai/index' };
  },

  /** 朋友圈分享：与好友分享区分，朋友圈侧只带标题与页面路径 */
  onShareTimeline() {
    return { title: '八宅明镜 · 命卦游年与家人配房' };
  }
});
