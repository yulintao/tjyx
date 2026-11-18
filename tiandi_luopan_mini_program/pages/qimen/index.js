const QM = require('../../utils/qimen');
const store = require('../../utils/store');

Page({
  data: {
    dateStr: '',
    timeStr: '',
    juText: '',
    dun: '',
    term: '',
    yuan: '',
    pillars: '',
    zhiFu: null,
    zhiShi: null,
    summary: '',
    monthText: '',
    goodDirs: [],
    cells: [],
    scenarios: [],
    activeKey: '',
    activeScenario: null,
    birthYear: '',
    lifeYear: null,
    pickedPalace: null,
    classicalSource: null,
    showEvidence: true
  },

  onLoad() {
    const now = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    const settings = store.getSettings() || {};
    this.setData({
      dateStr: `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`,
      timeStr: `${pad(now.getHours())}:${pad(now.getMinutes())}`,
      showEvidence: settings.showEvidence !== false
    });
    this.recompute(now);
  },

  onDate(e) {
    this.setData({ dateStr: e.detail.value });
    this.recompute(this.compose());
  },

  onTime(e) {
    this.setData({ timeStr: e.detail.value });
    this.recompute(this.compose());
  },

  compose() {
    return new Date(`${this.data.dateStr.replace(/-/g, '/')} ${this.data.timeStr}`);
  },

  recompute(d) {
    const chart = QM.calculateChart(d);
    this._chart = chart;
    this.setData({
      juText: chart.juText,
      dun: chart.dun,
      term: chart.term,
      yuan: chart.yuan,
      pillars: chart.pillars.fullStr,
      zhiFu: chart.zhiFu,
      zhiShi: chart.zhiShi,
      summary: chart.summary,
      monthText: chart.monthText || '',
      goodDirs: chart.goodDirs,
      cells: chart.cells,
      pickedPalace: null,
      classicalSource: chart.classicalSource || null,
      scenarios: QM.SCENARIOS.map((s) => ({ key: s.key, name: s.name }))
    });
    this.evaluate(this.data.activeKey || 'wealth');
  },

  evaluate(key) {
    if (!this._chart) return;
    const r = QM.evaluateScenario(this._chart, key);
    this.setData({ activeScenario: r, activeKey: key });
  },

  onScenario(e) {
    this.evaluate(e.currentTarget.dataset.key);
  },

  /** 点九宫任一宫：出该宫门 / 星 / 神组合与断语 */
  onCellTap(e) {
    const palace = parseInt(e.currentTarget.dataset.palace, 10);
    const cell = (this.data.cells || []).filter((c) => c.palace === palace)[0];
    if (!cell) return;
    this.setData({ pickedPalace: QM.palaceLine(cell) });
  },

  onBirth(e) {
    const birthYear = e.detail.value;
    this.setData({ birthYear });
    const y = parseInt(birthYear, 10);
    if (y > 1900 && y < 2100 && this._chart) {
      this.setData({ lifeYear: QM.lifeYearPalace(this._chart, y) });
    }
  },

  back() { wx.navigateBack({ fail: () => wx.reLaunch({ url: '../index/index' }) }); }
,

  onShareAppMessage() {
    return { title: '演象时空罗盘 · 奇门遁甲', path: '/pages/qimen/index' };
  },

  /** 朋友圈分享：与好友分享区分，朋友圈侧只带标题与页面路径 */
  onShareTimeline() {
    return { title: '奇门遁甲 · 时家奇门用神场景' };
  }
});
