const XK = require('../../utils/xuankong');
const SF = require('../../utils/sitface');
const store = require('../../utils/store');
const TE = require('../../utils/traditional-evidence');

const PERIOD_NAMES = ['一运', '二运', '三运', '四运', '五运', '六运', '七运', '八运', '九运'];

Page({
  data: {
    sitIdx: 0,
    sit: '子',
    face: '午',
    mountainNames: SF.MOUNTAINS_24.map((m) => `${m} 山`),
    periodIdx: 0,
    periodNames: PERIOD_NAMES,
    periodText: '',
    rangeText: '',
    chartTypeText: '',
    patternText: '',
    patternLevel: 'ping',
    cells: [],
    picked: null,
    tiGua: false,
    tiGuaLocked: false,
    autoJian: false,
    heading: null,
    headingText: '',
    flowOn: true,
    flowYear: 0,
    flowMonth: 0,
    // 手动兼向微调（无传感器时也能起替卦）
    jianDevIdx: 0,
    jianDevOptions: ['正针 0°', '兼向右 2°', '兼向右 4°', '兼向右 6°'],
    jianDevList: [0, 2, 4, 6],
    sanBanText: '',
    qiXingText: '',
    // iOS 迁移字段：现场事实 / 实用动作 / 古籍引用
    siteFactFields: [],
    practicalActions: [],
    visibleActions: [],
    evidence: [],
    showEvidence: true,
    actionsExpanded: false,
    // 结论看板
    concSitFace: '',
    concPeriod: '',
    concPattern: '',
    concSanBan: '',
    concQiXing: '',
    concAlarm: '',
    showDetail: false
  },

  onLoad(options) {
    let sit = '子';
    if (options && options.sit && SF.MOUNTAINS_24.indexOf(options.sit) >= 0) sit = options.sit;
    const cur = XK.periodForYear(new Date().getFullYear());
    const heading = options && options.heading !== undefined ? parseFloat(options.heading) : null;
    const settings = store.getSettings() || {};
    this.setData({
      sitIdx: SF.MOUNTAINS_24.indexOf(sit),
      periodIdx: cur - 1,
      heading,
      showEvidence: settings.showEvidence !== false
    });
    this.recompute();
  },

  toggleActions() {
    const expanded = !this.data.actionsExpanded;
    this.setData({
      actionsExpanded: expanded,
      visibleActions: this.buildVisibleActions(this.data.practicalActions, expanded)
    });
  },

  buildVisibleActions(actions, expanded) {
    const list = actions || [];
    return list.map((a, i) => ({ key: a.key, no: i + 1, text: a.text }))
      .filter((a) => expanded || a.no <= 4);
  },

  onSitChange(e) {
    // 手选坐山后不再跟随传感器兼向判定
    this.setData({ sitIdx: parseInt(e.detail.value, 10), heading: null, autoJian: false, jianDevIdx: 0 });
    this.recompute();
  },

  /** 手动兼向：按坐山对宫加偏移，交给 diagnoseHeading 自动判兼向 / 出卦 */
  onJianDev(e) {
    const idx = parseInt(e.detail.value, 10);
    const sitIdx = this.data.sitIdx;
    const dev = this.data.jianDevList[idx] || 0;
    const heading = dev ? (sitIdx * 15 + 180 + dev) % 360 : null;
    this.setData({ jianDevIdx: idx, heading, tiGuaLocked: false });
    this.recompute();
  },

  onPeriodChange(e) {
    this.setData({ periodIdx: parseInt(e.detail.value, 10) });
    this.recompute();
  },

  /** 手动切换下卦 / 替卦，切换后锁定，不再被实测兼向覆盖 */
  onTiGua(e) {
    this.setData({ tiGua: e.detail.value, tiGuaLocked: true });
    this.recompute();
  },

  onFlow(e) {
    this.setData({ flowOn: e.detail.value });
    this.recompute();
  },

  onCell(e) {
    const p = parseInt(e.currentTarget.dataset.palace, 10);
    const cell = this.data.cells.filter((c) => c.palace === p)[0];
    if (!cell) return;
    // iOS XuanKongStarPair：山向星组的五行关系与 motif 语义 + 证据链
    const pair = TE.starPair(cell.shan, cell.xiang);
    const motifs = [];
    if (pair.hasEarthCaution) motifs.push('二五关煞，宜静不宜动土');
    if (pair.isStudy) motifs.push('文昌组合，宜书房与学习');
    if (pair.isFriction) motifs.push('三四/三七摩擦，注意口舌');
    if (pair.isHeat) motifs.push('火燥组合，注意散热与光源');
    const pairEvidence = TE.pairEvidence(cell.shan, cell.xiang, `${cell.name}宫 山${cell.shan}向${cell.xiang}`);
    this.setData({
      picked: Object.assign({}, cell, {
        pairRelation: pair.relationTitle,
        pairMotifs: motifs,
        pairEvidence
      })
    });
  },

  recompute() {
    const sit = SF.MOUNTAINS_24[this.data.sitIdx];
    const face = SF.opposite(sit);
    const period = this.data.periodIdx + 1;

    // 实测向首 → 兼向自动判定（≤3° 正针 / 3–6° 兼向须起替卦）
    let headingText = '';
    let autoJian = false;
    if (this.data.heading !== null && !isNaN(this.data.heading)) {
      const diag = SF.diagnoseHeading(this.data.heading);
      headingText = `向首 ${this.data.heading.toFixed(1)}° · ${diag.text}`;
      autoJian = diag.needTiGua;
    }
    const tiGua = this.data.tiGuaLocked ? this.data.tiGua : autoJian;

    const chart = XK.calculateChart({ sitMountain: sit, faceMountain: face, period, isTiGua: tiGua });
    const flow = this.data.flowOn ? XK.withFlow(chart, new Date().getFullYear()) : null;

    const cells = (flow ? flow.cells : chart.cells).map((c) => Object.assign({}, c, { dirShort: c.dir }));
    // SITE_FACT_FIELDS 是 { key: { label, hint } }，转成数组便于 WXML 遍历
    const factFields = chart.siteFactFields || {};
    const siteFactFields = Object.keys(factFields).map((key) => Object.assign({ key }, factFields[key]));
    const alarmCells = (flow ? flow.cells : chart.cells).filter((c) => c.alarm25 || c.flowAlarm);

    this.setData({
      sit,
      face,
      concSitFace: `${sit}山${face}向 · ${chart.chartTypeText}`,
      concPeriod: `${chart.periodText}（${chart.periodRange.start}–${chart.periodRange.end}）`,
      concPattern: chart.patternText.split(' · ')[0],
      concSanBan: chart.sanBanText || '未成三般卦',
      concQiXing: chart.qiXingText || '未成七星打劫局',
      concAlarm: alarmCells.length
        ? `二五交加 / 流年煞：${alarmCells.map((c) => c.name).join('、')}`
        : '当前无二五交加或流年煞宫',
      periodText: chart.periodText,
      rangeText: `${chart.periodRange.start}–${chart.periodRange.end}`,
      chartTypeText: chart.chartTypeText,
      patternText: chart.patternText,
      patternLevel: chart.patternLevel,
      sanBanText: chart.sanBanText,
      qiXingText: chart.qiXingText,
      tiGua,
      autoJian,
      headingText,
      flowYear: flow ? flow.year : 0,
      flowMonth: flow ? flow.month : 0,
      cells,
      picked: cells.filter((c) => c.palace === chart.sitPalace)[0],
      siteFactFields,
      practicalActions: chart.practicalActions || [],
      visibleActions: this.buildVisibleActions(chart.practicalActions, this.data.actionsExpanded),
      evidence: chart.evidence || []
    });

    store.track({
      type: 'xuankong',
      title: `玄空 · ${sit}山${face}向 ${period}运`,
      sub: chart.patternText.split(' · ')[0] + ' · ' + chart.chartTypeText,
      sit,
      heading: this.data.sitIdx * 15
    });
  },

  toggleDetail() { this.setData({ showDetail: !this.data.showDetail }); },

  copySource(e) {
    const url = e.currentTarget.dataset.url;
    if (!url) return;
    wx.setClipboardData({ data: url, success: () => wx.showToast({ title: '出处链接已复制', icon: 'none' }) });
  },

  back() { wx.navigateBack({ fail: () => wx.reLaunch({ url: '../index/index' }) }); }
,

  onShareAppMessage() {
    return { title: '演象时空罗盘 · 玄空飞星', path: '/pages/xuankong/index' };
  },

  /** 朋友圈分享：与好友分享区分，朋友圈侧只带标题与页面路径 */
  onShareTimeline() {
    return { title: '玄空飞星盘 · 山向飞星与化解' };
  }
});
