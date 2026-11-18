const sha = require('../../utils/sha.js');
const store = require('../../utils/store');

Page({
  data: {
    items: [],
    checked: [],
    summary: [],
    severityName: {},
    total: 0,
    hitCount: 0,
    hits: [],
    criticalCount: 0,
    showDetail: false,
    sitMountain: '',
    evidencePath: '',
    savedAt: ''
  },

  onLoad(options) {
    const s = store.getSettings() || {};
    const saved = store.read('yj_sha_check', null) || {};
    const checked = Array.isArray(saved.checked) ? saved.checked : [];
    this.setData({
      items: sha.ITEMS.map((i) => Object.assign({}, i, { hit: checked.indexOf(i.id) >= 0 })),
      checked,
      showEvidence: s.showEvidence !== false,
      severityName: {
        critical: '极凶',
        warning: '中凶',
        minor: '轻微',
        notice: '吉象'
      },
      distanceGradeName: {
        criticalNear: '近距加重',
        staticLevel: '静态等级',
        mitigatedFar: '远距减轻'
      },
      distances: (saved && saved.distances) || {},
      total: sha.ITEMS.length,
      sitMountain: (options && options.sit) || saved.sit || '',
      savedAt: saved.at || ''
    });
    this.calc();
  },

  toggle(e) {
    const id = e.currentTarget.dataset.id;
    const checked = this.data.checked.slice();
    const idx = checked.indexOf(id);
    if (idx >= 0) checked.splice(idx, 1);
    else checked.push(id);
    this.setData({ checked });
    this.calc();
    this.persist(checked);
  },

  /** 勾选结果落本机，下次进来接着填，不用从头再点一遍 */
  persist(checked) {
    const now = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    const at = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}`;
    store.write('yj_sha_check', { checked, sit: this.data.sitMountain, at, distances: this.data.distances });
    this.setData({ savedAt: at });
  },

  calc() {
    const res = sha.audit(this.data.checked, this.data.sitMountain);
    const dist = this.data.distances || {};
    const hits = (res.hits || []).map((h) => {
      const meters = dist[h.id] === undefined || dist[h.id] === '' ? null : Number(dist[h.id]);
      const grade = sha.distanceGrade(meters);
      const eff = sha.effectiveSeverity(h.severity, meters);
      return {
        id: h.id,
        name: h.name,
        severity: h.severity,
        severityText: this.data.severityName[h.severity] || '',
        distanceMeters: meters,
        distanceGrade: grade,
        distanceGradeText: this.data.distanceGradeName[grade] || '',
        effectiveSeverity: eff,
        effectiveSeverityText: this.data.severityName[eff] || '',
        changed: eff !== h.severity,
        remedy: h.remedy
      };
    });
    this.setData({
      summary: res.summary,
      hits,
      hitCount: hits.length,
      criticalCount: hits.filter((h) => h.effectiveSeverity === 'critical').length,
      items: this.data.items.map((i) => Object.assign({}, i, { hit: this.data.checked.indexOf(i.id) >= 0 }))
    });
  },

  onDistanceInput(e) {
    const id = e.currentTarget.dataset.id;
    const distances = Object.assign({}, this.data.distances || {});
    distances[id] = e.detail.value;
    this.setData({ distances });
    this.calc();
    this.persist(this.data.checked);
  },

  toggleDetail() { this.setData({ showDetail: !this.data.showDetail }); },

  clear() {
    this.setData({ checked: [] });
    this.calc();
    this.persist([]);
  },

  /**
   * 现场留证（替代 iOS OnDeviceShaAnalyzer 的端侧自动识别）
   * 端侧识别在小程序无可用模型，改为「拍照 + 勾选 + 归档」：照片存本机记录，勾选项写历史
   */
  onCapture() {
    wx.chooseMedia({
      count: 1,
      mediaType: ['image'],
      sourceType: ['camera', 'album'],
      success: (res) => {
        const f = res.tempFiles && res.tempFiles[0];
        if (!f) return;
        const hits = sha.audit(this.data.checked, this.data.sitMountain).hits;
        store.track({
          type: 'sha',
          title: `外煞留证 · ${hits.length} 项`,
          sub: hits.slice(0, 3).map((h) => h.name).join('、') || '未勾选煞项',
          sit: this.data.sitMountain
        });
        this.setData({ evidencePath: f.tempFilePath });
        wx.previewImage({ urls: [f.tempFilePath] });
        wx.showToast({ title: '已留证，可对照勾选', icon: 'none' });
      },
      fail: () => wx.showToast({ title: '未拍摄，可用勾选方式自查', icon: 'none' })
    });
  },

  saveEvidence() {
    if (!this.data.evidencePath) {
      wx.showToast({ title: '先拍摄留证', icon: 'none' });
      return;
    }
    wx.saveImageToPhotosAlbum({
      filePath: this.data.evidencePath,
      success: () => wx.showToast({ title: '已存入相册', icon: 'success' }),
      fail: () => wx.showToast({ title: '保存失败，请允许相册权限', icon: 'none' })
    });
  },

  clearEvidence() {
    this.setData({ evidencePath: '' });
  },

  back() { wx.navigateBack({ delta: 1 }); },

  onShareAppMessage() {
    return {
      title: '演象时空罗盘 · 外煞自查与化解',
      path: '/pages/sha/index?sit=' + this.data.sitMountain
    };
  },

  /** 朋友圈分享：与好友分享区分，朋友圈侧只带标题与页面路径 */
  onShareTimeline() {
    return { title: '外煞自查 · 形煞辨识影响与化解' };
  },
});
