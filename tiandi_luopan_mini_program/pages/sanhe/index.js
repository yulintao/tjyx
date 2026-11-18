const SH = require('../../utils/sanhe');
const SF = require('../../utils/sitface');
const store = require('../../utils/store');
const orientation = require('../../utils/orientation');

Page({
  data: {
    sitIdx: 0,
    sit: '子',
    face: '午',
    mountainNames: SF.MOUNTAINS_24.map((m) => `${m} 山`),
    bureauName: '',
    phaseText: '',
    verdict: '平',
    verdictText: '',
    huangQuan: null,
    baSha: null,
    waterAdvice: '',
    drainAdvice: '',
    table: [],
    songs: null,
    evidence: null,
    showEvidence: true,
    // 水口合参
    shanNames: [],
    laiIdx: 0,
    quIdx: 0,
    laiShan: '',
    quShan: '',
    water: null,
    showDetail: false,
    // 兼向
    jianOptions: ['不兼（正向）', '兼前一山', '兼后一山'],
    jianIdx: 0,
    jian: null,
    jianLabel: '不兼（正向）'
  },

  onLoad(options) {
    let sit = orientation.current().sit;
    if (options && options.sit && SF.MOUNTAINS_24.indexOf(options.sit) >= 0) sit = options.sit;
    const s = store.getSettings() || {};
    this.setData({ sitIdx: SF.MOUNTAINS_24.indexOf(sit), showEvidence: s.showEvidence !== false });
    this.recompute();
  },

  onSitChange(e) {
    const sitIdx = parseInt(e.detail.value, 10);
    this.setData({ sitIdx, jianIdx: 0, jianLabel: '不兼（正向）' });
    orientation.fromManual(SF.MOUNTAINS_24[sitIdx]);
    const bar = this.selectComponent && this.selectComponent('ctx-bar');
    if (bar && bar.refresh) bar.refresh();
    // 换坐山后长生局整体变化，来去水默认重取该局最合宜的两字
    this._laiName = null;
    this._quName = null;
    this.recompute();
  },

  onJianChange(e) {
    this.setData({ jianIdx: parseInt(e.detail.value, 10) });
    this.recompute();
  },

  onLaiChange(e) {
    this._laiName = this.data.shanNames[parseInt(e.detail.value, 10)];
    this.judge();
  },

  onQuChange(e) {
    this._quName = this.data.shanNames[parseInt(e.detail.value, 10)];
    this.judge();
  },

  /** 点某字：直接设为来水或去水，省得两个下拉来回找 */
  onRowSet(e) {
    const shan = e.currentTarget.dataset.shan;
    wx.showActionSheet({
      itemList: [`设为来水：${shan}`, `设为去水：${shan}`],
      success: (res) => {
        if (res.tapIndex === 0) this._laiName = shan;
        else this._quName = shan;
        this.judge();
      }
    });
  },

  judge() {
    const table = this._table;
    if (!table || !table.length) return;
    const names = table.map((t) => t.shan);
    let laiName = this._laiName;
    let quName = this._quName;
    if (!laiName || names.indexOf(laiName) < 0) {
      const good = table.filter((t) => t.isGoodWater)[0];
      laiName = good ? good.shan : names[0];
    }
    if (!quName || names.indexOf(quName) < 0) {
      const good = table.filter((t) => t.isGoodDrain)[0];
      quName = good ? good.shan : names[names.length - 1];
    }
    this._laiName = laiName;
    this._quName = quName;

    const w = SH.judgeWater(table, laiName, quName);
    this.setData({
      shanNames: names,
      laiIdx: Math.max(0, names.indexOf(laiName)),
      quIdx: Math.max(0, names.indexOf(quName)),
      laiShan: laiName,
      quShan: quName,
      water: w,
      table: table.map((t) => ({
        ...t,
        tag: t.isGoodWater ? '宜来水' : (t.isGoodDrain ? '宜去水' : '平'),
        isLai: t.shan === laiName,
        isQu: t.shan === quName
      }))
    });
    this.updateJian(laiName, quName);
  },

  /** 兼向判定：兼左 / 兼右取邻山，看是否越出双山（出卦） */
  updateJian(laiName, quName) {
    const sit = this.data.sit;
    const face = this.data.face;
    const aux = this.data.jianIdx === 0 ? '' : SH.nextMountain(sit, this.data.jianIdx === 1 ? -1 : 1);
    const r = SH.jianXiangWater(sit, face, aux, laiName, quName);
    this.setData({
      jian: {
        ...r,
        tagText: r.level === 'ji' ? '成局' : (r.level === 'xiong' ? '出卦' : '需校'),
        tagClass: r.level === 'ji' ? 'tag-ji' : (r.level === 'xiong' ? 'tag-xiong' : 'tag-ping'),
        faceCheckText: r.faceOk ? '与坐山相对（合）' : `应为${r.expectFace}，今不合`
      },
      jianLabel: aux ? `${sit}兼${aux}` : '不兼（正向）'
    });
  },

  recompute() {
    const sit = SF.MOUNTAINS_24[this.data.sitIdx];
    const face = SF.opposite(sit);
    const r = SH.analyze(sit, face);
    this._table = r.table;
    this.setData({
      sit,
      face,
      bureauName: r.bureau.name,
      phaseText: `${r.phase.shan} · ${r.phase.phase}`,
      verdict: r.verdict,
      verdictText: r.verdictText,
      huangQuan: r.huangQuan,
      baSha: r.baSha,
      waterAdvice: r.waterAdvice,
      drainAdvice: r.drainAdvice,
      songs: r.songs,
      evidence: r.evidence
    });
    this.judge();
  },

  toggleDetail() { this.setData({ showDetail: !this.data.showDetail }); },

  back() { wx.navigateBack({ fail: () => wx.reLaunch({ url: '../index/index' }) }); },

  onShareAppMessage() {
    return {
      title: `演象时空罗盘 · 三合水法（${this.data.sit}山${this.data.face}向）`,
      path: `/pages/sanhe/index?sit=${this.data.sit}`
    };
  },

  /** 朋友圈分享：与好友分享区分，朋友圈侧只带标题与页面路径 */
  onShareTimeline() {
    return { title: '三合水法 · 八路黄泉与十二长生' };
  }
});
