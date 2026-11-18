/**
 * pages/luban/index.js
 * 鲁班门光尺 / 丁兰尺测量（对齐 iOS AR 打点测量后的 LubanRulerEvaluation）
 * 小程序无 AR 打点，改为「输入实测宽高 + 常用门宽一键」的等价工具。
 */

const LB = require('../../utils/luban');
const nav = require('../../utils/nav');

const PRESETS = [
  { label: '入户门 90cm', cm: 90 },
  { label: '入户门 100cm', cm: 100 },
  { label: '卧室门 80cm', cm: 80 },
  { label: '卫生间门 70cm', cm: 70 },
  { label: '厨房门 75cm', cm: 75 },
  { label: '推拉门 160cm', cm: 160 }
];

Page({
  data: {
    cmInput: '90',
    result: null,
    nearest: null,
    presets: PRESETS,
    yangScale: LB.yangScale(),
    yinScale: LB.yinScale(),
    source: LB.SOURCE
  },

  onLoad(options) {
    const cm = options && options.cm ? String(options.cm) : '90';
    this.setData({ cmInput: cm });
    this.calc(cm);
  },

  onInput(e) {
    this.setData({ cmInput: e.detail.value });
    this.calc(e.detail.value);
  },

  onPreset(e) {
    const cm = String(e.currentTarget.dataset.cm);
    this.setData({ cmInput: cm });
    this.calc(cm);
  },

  /** 滑杆粗调 0–300cm，落点实时判定 */
  onSlider(e) {
    const cm = String(e.detail.value);
    this.setData({ cmInput: cm });
    this.calc(cm);
  },

  /** 一键取最近吉度：把实测值改成最近吉格对应的厘米数 */
  applyNearest() {
    const n = this.data.nearest;
    if (!n) return;
    const cm = String(n.cm);
    this.setData({ cmInput: cm });
    this.calc(cm);
    wx.showToast({ title: `已取 ${n.name} ${n.cm}cm`, icon: 'none' });
  },

  /** 标出当前尺寸落在哪一格（按尺的循环长度取余，42.9 / 39.0 逐圈递推） */
  markScale(scale, cm, cycle) {
    const n = parseFloat(cm);
    if (!isFinite(n)) return scale;
    const c = Number(cycle) > 0 ? Number(cycle) : 0;
    const inCycle = c ? n % c : n;
    return scale.map((s) => ({
      ...s,
      active: inCycle >= s.from && inCycle < s.to
    }));
  },

  calc(cm) {
    const n = parseFloat(cm);
    if (!isFinite(n) || n <= 0) {
      this.setData({ result: null, nearest: null });
      return;
    }
    const r = LB.evaluate(n / 100);
    this.setData({
      result: Object.assign({}, r, {
        cmText: `${Math.round(n * 10) / 10} cm`,
        yangTag: r.yangAuspicious ? '吉' : '凶',
        yinTag: r.yinAuspicious ? '吉' : '凶'
      }),
      nearest: LB.nearestAuspicious(n),
      yangScale: this.markScale(LB.yangScale(), n, LB.YANG_CYCLE_CM),
      yinScale: this.markScale(LB.yinScale(), n, LB.YIN_CYCLE_CM)
    });
  },

  copyResult() {
    const r = this.data.result;
    if (!r) return;
    wx.setClipboardData({
      data: `${r.summary}\n${r.source}`,
      success: () => wx.showToast({ title: '已复制', icon: 'success' })
    });
  },

  back() { nav.back(); },

  onShareAppMessage() {
    return { title: '鲁班门光尺 · 门宽吉凶速测', path: '/pages/luban/index' };
  },

  onShareTimeline() {
    return { title: '鲁班门光尺 · 门宽吉凶速测' };
  }
});
