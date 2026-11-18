/**
 * pages/history/index.js
 * 浏览历史：结论优先（最近几条 / 今天几条 / 类型分布），列表可筛可展开
 */

const store = require('../../utils/store');
const nav = require('../../utils/nav');

const TYPE_LABEL = {
  analysis: '盘解',
  poster: '海报',
  zeri: '择日',
  xuankong: '玄空',
  tianji: '天机',
  floorplan: '户型',
  sha: '外煞'
};

Page({
  data: {
    total: 0,
    todayCount: 0,
    counts: [],
    activeType: 'all',
    showAll: false,
    visible: [],
    pageSize: 8
  },

  onLoad() {
    this.refresh();
  },

  onShow() {
    this.refresh();
  },

  refresh() {
    const raw = store.getHistory();
    const now = Date.now();
    const pad = (n) => String(n).padStart(2, '0');
    const all = raw.map((h) => {
      const d = new Date(h.at);
      const hm = `${pad(d.getHours())}:${pad(d.getMinutes())}`;
      const sameDay = new Date(now).toDateString() === d.toDateString();
      const atText = sameDay ? `今天 ${hm}` : `${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${hm}`;
      return Object.assign({}, h, {
        typeLabel: TYPE_LABEL[h.type] || '记录',
        atText
      });
    });

    // 类型分布：给筛选条用的计数
    const map = {};
    all.forEach((h) => {
      map[h.type] = (map[h.type] || 0) + 1;
    });
    const counts = Object.keys(map)
      .map((k) => ({ key: k, label: TYPE_LABEL[k] || '记录', count: map[k] }))
      .sort((a, b) => b.count - a.count);

    const today = new Date(now).toDateString();
    const todayCount = all.filter((h) => new Date(h.at).toDateString() === today).length;

    this._all = all;
    this.setData({ total: all.length, todayCount, counts });
    this.applyFilter();
  },

  applyFilter() {
    const all = this._all || [];
    const type = this.data.activeType;
    const filtered = type === 'all' ? all : all.filter((h) => h.type === type);
    const visible = this.data.showAll ? filtered : filtered.slice(0, this.data.pageSize);
    this.setData({ visible, filteredCount: filtered.length });
  },

  onFilter(e) {
    const type = e.currentTarget.dataset.type;
    this.setData({ activeType: type, showAll: false });
    this.applyFilter();
  },

  toggleAll() {
    this.setData({ showAll: !this.data.showAll });
    this.applyFilter();
  },

  _find(e) {
    const id = e.currentTarget.dataset.id;
    return (this._all || []).filter((h) => h.id === id)[0];
  },

  open(e) {
    const item = this._find(e);
    if (!item) return;
    if (item.type === 'poster') {
      wx.navigateTo({ url: `/pages/poster/index?sit=${item.sit}&heading=${item.heading}` });
      return;
    }
    nav.go('/pages/analysis/index', { sit: item.sit });
  },

  remove(e) {
    const item = this._find(e);
    if (!item) return;
    wx.showModal({
      title: '删除记录',
      content: `删除「${item.title}」？`,
      success: (res) => {
        if (!res.confirm) return;
        store.removeHistory(item.id);
        this.refresh();
      }
    });
  },

  clear() {
    if (!this.data.total) return;
    wx.showModal({
      title: '清空历史',
      content: '将删除全部浏览与海报记录，不可恢复。',
      success: (res) => {
        if (!res.confirm) return;
        store.clearHistory();
        this.setData({ activeType: 'all', showAll: false });
        this.refresh();
        wx.showToast({ title: '已清空', icon: 'none' });
      }
    });
  },

  back() { wx.navigateBack({ delta: 1 }); },

  onShareAppMessage() {
    return { title: '演象时空罗盘', path: '/pages/index/index' };
  },

  /** 朋友圈分享：与好友分享区分，朋友圈侧只带标题与页面路径 */
  onShareTimeline() {
    return { title: '浏览历史 · 最近盘解留痕' };
  }
});
