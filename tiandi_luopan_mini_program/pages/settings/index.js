const store = require('../../utils/store.js');
const nav = require('../../utils/nav');
const I18N = require('../../utils/i18n');

Page({
  data: {
    settings: {},
    version: '2.0.0',
    ownerText: '未设置',
    memberCount: 0,
    showMore: false,
    langs: I18N.APP_LANGUAGES,
    langIdx: 0,
    i18n: {}
  },

  toggleMore() { this.setData({ showMore: !this.data.showMore }); },

  onHaptic(e) {
    const s = store.getSettings() || {};
    s.haptic = e.detail.value;
    store.saveSettings(s);
    this.setData({ settings: s });
    if (e.detail.value) { try { wx.vibrateShort({ type: 'light' }); } catch (err) {} }
  },

  buildI18n() {
    const keys = ['settings_title', 'settings_appearance', 'settings_more', 'settings_language',
      'settings_unit', 'settings_notify', 'settings_evidence', 'settings_vip', 'settings_terms',
      'settings_compliance', 'settings_privacy', 'settings_rate', 'settings_guide', 'settings_about',
      'footer_note'];
    const map = {};
    keys.forEach((k) => { map[k] = I18N.t(k); });
    const idx = I18N.APP_LANGUAGES.map((l) => l.key).indexOf(I18N.currentSettingLang());
    this.setData({ i18n: map, langIdx: idx < 0 ? 0 : idx });
  },

  onLanguage(e) {
    const key = I18N.APP_LANGUAGES[parseInt(e.detail.value, 10)].key;
    I18N.setLanguage(key);
    this.buildI18n();
    wx.showToast({ title: '已切换界面语言', icon: 'none' });
  },

  onLoad() {
    const s = store.getSettings();
    const p = store.getProfiles() || {};
    const owner = p.owner;
    const members = p.members || [];
    this.setData({
      settings: s,
      ownerText: owner
        ? `${owner.name || '宅主'} · ${owner.birthYear || '—'} 年 · ${owner.gender === 'female' ? '女' : '男'}`
        : '未设置',
      memberCount: members.length
    });
    this.buildI18n();
  },

  onShow() {
    this.onLoad();
  },

  goFamily() { wx.navigateTo({ url: '/pages/family/index' }); },
  goNotify() { wx.navigateTo({ url: '/pages/notify/index' }); },
  goBackup() { wx.navigateTo({ url: '/pages/backup/index' }); },
  goVip() { wx.navigateTo({ url: '/pages/vip/index' }); },
  goRemedy() { wx.navigateTo({ url: '/pages/remedy/index' }); },
  goTerms() { wx.navigateTo({ url: '/pages/legal/index?type=terms' }); },
  goCompliance() { wx.navigateTo({ url: '/pages/legal/index?type=compliance' }); },

  /** 评分与反馈引导：小程序无法跳 App Store 写评，改为「复制反馈邮箱 + 引导小程序内 stars」 */
  rateApp() {
    wx.showModal({
      title: '喜欢这个工具吗？',
      content: '小程序不支持直接跳转商店评分。若本工具对你有帮助，欢迎把反馈发给我们；你的意见会直接影响后续改进。',
      confirmText: '复制邮箱反馈',
      cancelText: '稍后',
      success: (res) => {
        if (!res.confirm) return;
        wx.setClipboardData({
          data: 'support@sdnlink.cn',
          success: () => wx.showToast({ title: '邮箱已复制', icon: 'none' })
        });
      }
    });
  },

  replayGuide() {
    const s = store.getSettings() || {};
    s.guideSeen = false;
    store.saveSettings(s);
    wx.navigateTo({ url: '/pages/guide/index' });
  },

  save(patch) {
    const s = Object.assign({}, this.data.settings, patch);
    store.saveSettings(s);
    this.setData({ settings: s });
  },

  onUnit(e) {
    this.save({ unit: e.detail.value ? 'imperial' : 'metric' });
  },

  onNotify(e) {
    this.save({ notify: e.detail.value });
  },

  onEvidence(e) {
    this.save({ showEvidence: e.detail.value });
  },

  clearHistory() {
    store.clearHistory();
    wx.showToast({ title: '历史已清空', icon: 'none' });
  },

  clearAll() {
    wx.showModal({
      title: '清除全部数据',
      content: '将删除本地档案、化解任务、户型存档、历史与设置，不可恢复。',
      confirmText: '确认清除',
      success: (res) => {
        if (res.confirm) {
          store.clearAll();
          wx.showToast({ title: '已清除', icon: 'none' });
          this.onLoad();
        }
      }
    });
  },

  about() {
    wx.showModal({
      title: '演象时空罗盘',
      content: '传统堪舆工具：罗盘定向、玄空飞星、八宅、紫白、三合、择日、奇门、天机长卷、户型、分金、六十四卦与外煞自查。所有推算在本机完成，不上传数据。',
      showCancel: false
    });
  },

  back() { nav.back(); },

  onShareAppMessage() {
    return { title: '演象时空罗盘', path: '/pages/index/index' };
  }
});
