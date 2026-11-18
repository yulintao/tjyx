/**
 * pages/gua64/index.js
 * 六十四卦：坐向起卦 + 手动起卦（上下卦）+ 点爻抽爻换象
 * 交互对齐 iOS 的「拨盘取卦 → 点爻成动 → 之卦/互卦/错综并观」
 */

const hex = require('../../utils/hexagram.js');
const JF = require('../../utils/jingfang.js');
const astronomy = require('../../utils/astronomy.js');

const TRIGRAM_NAMES = hex.TRIGRAMS.map((t) => `${t.name}（${t.nature}）`);
const DAY_GANS = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];

Page({
  data: {
    heading: 0,
    manual: false,
    upperIdx: 0,
    lowerIdx: 0,
    upperName: '乾（天）',
    lowerName: '乾（天）',
    trigrams: TRIGRAM_NAMES,
    base: null,
    changed: null,
    mutual: null,
    inverse: null,
    reverse: null,
    lines: [],
    movingYao: 0,
    yaoText: '',
    text: '',
    grid: [],
    showAll: false,
    // 京房八宫
    jf: null,
    dayGans: DAY_GANS,
    dayGanIdx: 0,
    dayGan: '甲'
  },

  onLoad(options) {
    const h = Number(options && options.heading);
    const heading = isNaN(h) ? 0 : ((h % 360) + 360) % 360;
    let dayGan = '甲';
    try {
      const pillars = astronomy.calculateFourPillars(new Date(), 120);
      dayGan = pillars.dayPillar[0] || '甲';
    } catch (e) { dayGan = '甲'; }
    this.setData({
      grid: hex.HEXAGRAMS,
      dayGan,
      dayGanIdx: Math.max(0, DAY_GANS.indexOf(dayGan))
    });
    this.applyByHeading(heading);
  },

  /** 京房八宫：宫 / 卦型 / 世应 / 纳甲六亲，六爻自上而下排 */
  buildJf(binary) {
    const jf = JF.analyze(binary, this.data.dayGan);
    if (!jf) return null;
    return Object.assign({}, jf, {
      viewLines: jf.lines.slice().reverse().map((l) => Object.assign({}, l, {
        tag: l.isShi ? '世' : (l.isYing ? '应' : ''),
        tagClass: l.isShi ? 'tag-ji' : (l.isYing ? 'tag-ping' : '')
      }))
    });
  },

  onDayGanChange(e) {
    const idx = Number(e.detail.value);
    this.setData({ dayGanIdx: idx, dayGan: DAY_GANS[idx] });
    if (this._binary) this.setData({ jf: this.buildJf(this._binary) });
  },

  /** 按坐向起卦：角度落到 5.625° 卦区，再由偏角定动爻 */
  applyByHeading(heading) {
    const r = hex.divine(heading);
    this._binary = r.base.binary;
    this.setData({
      heading,
      manual: false,
      movingYao: r.base.yao,
      yaoText: `${r.base.yaoName}${r.base.yaoKind}`
    });
    this.applyBinary(this._binary, r.base.yao, `坐向 ${heading.toFixed(1)}° 落 ${r.base.name}（${r.base.upper}上${r.base.lower}下）`);
  },

  /** 按六爻二进制起卦（手动） */
  applyBinary(binary, movingYao, headline) {
    this._binary = binary;
    const base = hex.byBinary(binary);
    if (!base) return;
    const changed = movingYao ? hex.changeYao(binary, movingYao) : null;
    const lines = [];
    for (let i = 0; i < 6; i++) {
      lines.push({
        pos: i + 1,
        yang: binary.charAt(i) === '1',
        moving: movingYao === i + 1,
        name: hex.YAO_NAMES[i]
      });
    }
    // 上爻在上方显示，初爻在最下
    const viewLines = lines.slice().reverse();
    const head = headline || `本卦 ${base.name}（${base.upper}上${base.lower}下）`;
    const tail = movingYao
      ? `${hex.YAO_NAMES[movingYao - 1]}${binary.charAt(movingYao - 1) === '1' ? '阳' : '阴'}爻动，之卦 ${changed ? changed.name : '—'}`
      : '六爻皆静，无之卦';
    // 上下卦下拉与当前卦象保持同步
    const upperIdx = Math.max(0, hex.TRIGRAMS.map((t) => t.name).indexOf(base.upper));
    const lowerIdx = Math.max(0, hex.TRIGRAMS.map((t) => t.name).indexOf(base.lower));
    this.setData({
      base,
      changed,
      mutual: hex.mutual(binary),
      inverse: hex.inverse(binary),
      reverse: hex.reverse(binary),
      lines: viewLines,
      movingYao,
      upperIdx,
      lowerIdx,
      upperName: TRIGRAM_NAMES[upperIdx],
      lowerName: TRIGRAM_NAMES[lowerIdx],
      yaoText: movingYao ? `${hex.YAO_NAMES[movingYao - 1]}${binary.charAt(movingYao - 1) === '1' ? '阳爻' : '阴爻'}` : '静卦（无动爻）',
      text: `${head}，${tail}。`,
      jf: this.buildJf(binary)
    });
  },

  /** 点某一爻：该爻成动爻（阴阳翻转），再点一次取消 */
  onYaoTap(e) {
    const pos = Number(e.currentTarget.dataset.pos);
    const moving = this.data.movingYao === pos ? 0 : pos;
    const base = this.data.base;
    const headline = `本卦 ${base.name}（${base.upper}上${base.lower}下）`;
    this.setData({ manual: true, movingYao: moving });
    this.applyBinary(this._binary, moving, headline);
  },

  onUpperChange(e) {
    const idx = Number(e.detail.value);
    this.setData({ upperIdx: idx, manual: true, movingYao: 0 });
    this.applyManual(idx, this.data.lowerIdx);
    wx.showToast({ title: `上卦改为 ${hex.TRIGRAMS[idx].name}`, icon: 'none' });
  },

  onLowerChange(e) {
    const idx = Number(e.detail.value);
    this.setData({ lowerIdx: idx, manual: true, movingYao: 0 });
    this.applyManual(this.data.upperIdx, idx);
    wx.showToast({ title: `下卦改为 ${hex.TRIGRAMS[idx].name}`, icon: 'none' });
  },

  applyManual(upperIdx, lowerIdx) {
    // 二进制自下而上：下卦 3 位 + 上卦 3 位
    const binary = hex.TRIGRAMS[lowerIdx].bin + hex.TRIGRAMS[upperIdx].bin;
    this.applyBinary(binary, 0, '');
    this.setData({ manual: true });
  },

  resetHeading() {
    const h = this.data.heading;
    this.applyByHeading(h);
    wx.showToast({ title: '已回到坐向起卦', icon: 'none' });
  },

  onSlide(e) {
    this.applyByHeading(Number(e.detail.value));
  },

  pick(e) {
    const idx = Number(e.currentTarget.dataset.idx);
    const h = Math.round(hex.HEXAGRAMS[idx].angleCenter * 10) / 10;
    this.setData({ upperIdx: 0, lowerIdx: 0 });
    this.applyByHeading(h);
  },

  toggleAll() {
    this.setData({ showAll: !this.data.showAll });
  },

  back() { wx.navigateBack({ delta: 1, fail: () => wx.reLaunch({ url: '../index/index' }) }); },

  onShareAppMessage() {
    return {
      title: '演象时空罗盘 · 六十四卦抽爻',
      path: '/pages/gua64/index?heading=' + this.data.heading
    };
  },

  /** 朋友圈分享：与好友分享区分，朋友圈侧只带标题与页面路径 */
  onShareTimeline() {
    return { title: '六十四卦 · 抽爻换象与互错综' };
  }
});
