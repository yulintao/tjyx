const ZB = require('../../utils/zibai');
const XK = require('../../utils/xuankong');
const SF = require('../../utils/sitface');
const orientation = require('../../utils/orientation');

Page({
  data: {
    dateStr: '',
    sit: '子',
    face: '午',
    year: 2026,
    yearCenter: 0,
    monthCenter: 0,
    monthText: '',
    cells: [],
    warnings: [],
    hits: [],
    picked: null,
    fiveDir: '',
    twoDir: '',
    showDetail: false
  },

  onLoad(options) {
    let sit = orientation.current().sit;
    if (options && options.sit && SF.MOUNTAINS_24.indexOf(options.sit) >= 0) sit = options.sit;
    const now = new Date();
    this._base = now;
    const pad = (n) => String(n).padStart(2, '0');
    this.setData({
      sit,
      face: SF.opposite(sit),
      dateStr: `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`
    });
    this.recompute(now);
  },

  onDate(e) {
    const d = new Date(e.detail.value.replace(/-/g, '/'));
    this._base = d;
    this.setData({ dateStr: e.detail.value, monthShift: 0 });
    this.recompute(d);
  },

  /** 流月前后推移：看下月九星到宫，取目标月中旬避开节气边界 */
  shiftMonth(e) {
    const delta = Number(e.currentTarget.dataset.delta) || 0;
    const shift = (this.data.monthShift || 0) + delta;
    const d = new Date(this._base.getTime());
    d.setMonth(d.getMonth() + shift);
    d.setDate(15);
    const pad = (n) => String(n).padStart(2, '0');
    this.setData({
      monthShift: shift,
      dateStr: `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
    });
    this.recompute(d);
  },

  resetMonth() {
    const now = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    this._base = now;
    this.setData({
      monthShift: 0,
      dateStr: `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`
    });
    this.recompute(now);
  },

  onCell(e) {
    const p = parseInt(e.currentTarget.dataset.palace, 10);
    const cell = this.data.cells.filter((c) => c.palace === p)[0] || null;
    this.setData({ picked: cell });
  },

  recompute(now) {
    const chart = ZB.calculateChart(now, {
      sitPalace: SF.palaceNum(this.data.sit),
      facePalace: SF.palaceNum(this.data.face)
    });
    const zhiNames = ['寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥', '子', '丑'];
    this.setData({
      year: chart.year,
      yearCenter: chart.yearCenter,
      monthCenter: chart.monthCenter,
      monthText: `${zhiNames[(chart.solarMonth - 1) % 12]}月（节气月）`,
      cells: chart.cells,
      warnings: chart.warnings,
      hits: chart.hits,
      fiveDir: XK.PALACE_INFO[chart.fivePalace] ? XK.PALACE_INFO[chart.fivePalace].dir : '',
      twoDir: XK.PALACE_INFO[chart.twoPalace] ? XK.PALACE_INFO[chart.twoPalace].dir : '',
      picked: null
    });
  },

  toggleDetail() { this.setData({ showDetail: !this.data.showDetail }); },

  back() { wx.navigateBack({ fail: () => wx.reLaunch({ url: '../index/index' }) }); }
,

  onShareAppMessage() {
    return { title: '演象时空罗盘 · 紫白九星', path: '/pages/zibai/index' };
  },

  /** 朋友圈分享：与好友分享区分，朋友圈侧只带标题与页面路径 */
  onShareTimeline() {
    return { title: '紫白九星 · 年月飞星与太岁三煞' };
  }
});
