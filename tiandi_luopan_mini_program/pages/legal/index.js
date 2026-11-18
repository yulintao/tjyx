const LT = require('../../utils/legal-text');
const nav = require('../../utils/nav');

const KEYS = ['terms', 'compliance'];

Page({
  data: {
    active: 'terms',
    tabs: [
      { key: 'terms', label: LT.TERMS_TITLE },
      { key: 'compliance', label: LT.COMPLIANCE_TITLE }
    ],
    title: LT.TERMS_TITLE,
    paras: []
  },

  onLoad(options) {
    const key = options && KEYS.indexOf(options.type) >= 0 ? options.type : 'terms';
    this.setData({ active: key });
    this.load(key);
  },

  load(key) {
    const doc = LT.getDoc(key) || LT.getDoc('terms');
    this.setData({ title: doc.title, paras: LT.paragraphs(doc.key) });
  },

  onTab(e) {
    const key = e.currentTarget.dataset.key;
    if (key === this.data.active) return;
    this.setData({ active: key });
    this.load(key);
    wx.pageScrollTo({ scrollTop: 0, duration: 0 });
  },

  copyEmail() {
    wx.setClipboardData({
      data: 'support@sdnlink.cn',
      success: () => wx.showToast({ title: '邮箱已复制', icon: 'none' })
    });
  },

  back() { nav.back(); },

  onShareAppMessage() {
    return { title: `演象时空罗盘 · ${this.data.title}`, path: '/pages/legal/index' };
  }
});
