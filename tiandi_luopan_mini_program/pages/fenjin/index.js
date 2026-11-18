const fenjin = require('../../utils/fenjin.js');
const kongwang = require('../../utils/kongwang.js');

Page({
  data: {
    heading: 0,
    current: null,
    detail: null,
    kongwang: null,
    mountainName: '',
    mountainRows: [],
    auspicious: [],
    allRows: [],
    showAll: false
  },

  onLoad(options) {
    const h = Number(options && options.heading);
    const heading = isNaN(h) ? 0 : ((h % 360) + 360) % 360;
    this.setData({ heading });
    this.refresh(heading);
    this.setData({ auspicious: fenjin.auspiciousByMountain() });
    this.setData({ allRows: fenjin.TABLE });
  },

  refresh(heading) {
    const cur = fenjin.resolve(heading);
    const rows = fenjin.forMountain(cur.mountain);
    this.setData({
      current: cur,
      detail: fenjin.degreeReading(heading),
      kongwang: kongwang.reading(heading),
      mountainName: cur.mountain + '山',
      mountainRows: rows
    });
  },

  /** 一键取最近吉度 */
  onTakeNearest() {
    const d = this.data.detail;
    if (!d || !d.nearest) {
      wx.showToast({ title: '附近 ±8° 内没有可用吉度', icon: 'none' });
      return;
    }
    const heading = d.nearest.deg;
    this.setData({ heading });
    this.refresh(heading);
    wx.showToast({ title: `已取 ${d.nearest.jiazi}·${d.nearest.nayin}（${d.nearest.deg}°）`, icon: 'none' });
  },

  onSlide(e) {
    const heading = Number(e.detail.value);
    this.setData({ heading });
    this.refresh(heading);
  },

  /** 点本山五分金中的某一位：直接把罗盘度数跳到该位中心 */
  onFenjinPick(e) {
    const start = Number(e.currentTarget.dataset.start);
    const end = Number(e.currentTarget.dataset.end);
    if (!isFinite(start) || !isFinite(end)) return;
    const heading = Math.round(((start + end) / 2) % 360 * 10) / 10;
    this.setData({ heading });
    this.refresh(heading);
    const cur = this.data.current;
    wx.showToast({ title: `已取 ${cur.jiazi}（${cur.grade}）`, icon: 'none' });
  },

  /** 点二十四山吉度中的某山：跳到该山第一个吉度，没有吉度就取山中心 */
  onMountainPick(e) {
    const mountain = e.currentTarget.dataset.mountain;
    const rows = fenjin.forMountain(mountain) || [];
    const usable = rows.filter((r) => r.usable)[0];
    const target = usable || rows[0];
    if (!target) return;
    const heading = Math.round(((target.start + target.end) / 2) % 360 * 10) / 10;
    this.setData({ heading });
    this.refresh(heading);
    wx.showToast({
      title: usable ? `${mountain}山 ${usable.jiazi}（${usable.count || ''}）` : `${mountain}山无吉度，仅供比对`,
      icon: 'none'
    });
  },

  toggleAll() {
    this.setData({ showAll: !this.data.showAll });
  },

  back() {
    wx.navigateBack({ delta: 1 });
  },

  onShareAppMessage() {
    const c = this.data.current;
    return {
      title: '演象时空罗盘 · 一百二十分金',
      path: '/pages/fenjin/index?heading=' + this.data.heading,
      imageUrl: ''
    };
  },

  /** 朋友圈分享：与好友分享区分，朋友圈侧只带标题与页面路径 */
  onShareTimeline() {
    return { title: '分金一百二十 · 珠宝火坑与纳音断语' };
  },
});
