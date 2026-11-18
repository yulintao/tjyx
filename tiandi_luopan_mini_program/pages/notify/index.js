/**
 * pages/notify/index.js
 * 提醒中心（替代 iOS 的 setSolarTermNotifications / toggleAuspiciousDayReminder 系统通知）
 * 三层：页内提醒卡（必达）→ 订阅消息（需模板 ID，授权后由云函数下发）→ 复制/桌面快捷方式兜底
 */

const RM = require('../../utils/reminders');
const store = require('../../utils/store');
const nav = require('../../utils/nav');

Page({
  data: {
    prefs: RM.DEFAULT_PREFS,
    todayItems: [],
    list: [],
    sit: '',
    days: 7,
    tmplInput: '',
    subscribeState: '未订阅',
    copyText: ''
  },

  onLoad() {
    this.build();
  },

  onShow() {
    this.build();
  },

  build() {
    const s = store.getSettings() || {};
    const prefs = RM.normalizePrefs(s.reminders);
    const sit = RM.lockedSit(s);
    const todayItems = RM.filterByPrefs(RM.today(new Date(), { sitMountain: sit, ownerBirthYear: s.ownerBirthYear }), prefs);
    const list = RM.filterByPrefs(RM.upcoming(new Date(), {
      days: this.data.days,
      sitMountain: sit,
      ownerBirthYear: s.ownerBirthYear
    }), prefs);
    const sub = prefs.subscribedAt ? `已授权（${new Date(prefs.subscribedAt).toLocaleDateString()}）` : '未订阅';
    this.setData({
      prefs,
      sit: sit || '',
      todayItems,
      list,
      tmplInput: prefs.tmplIds || '',
      subscribeState: sub,
      copyText: RM.toText(list)
    });
  },

  savePrefs(patch) {
    const s = store.getSettings() || {};
    s.reminders = Object.assign({}, RM.normalizePrefs(s.reminders), patch);
    store.saveSettings(s);
    this.build();
  },

  onToggle(e) {
    const key = e.currentTarget.dataset.key;
    const value = e.detail.value;
    this.savePrefs({ [key]: value });
  },

  onDays(e) {
    this.setData({ days: parseInt(e.detail.value, 10) || 7 });
    this.build();
  },

  onTmplInput(e) {
    this.setData({ tmplInput: e.detail.value });
  },

  saveTmpl() {
    this.savePrefs({ tmplIds: String(this.data.tmplInput || '').trim() });
    wx.showToast({ title: '模板 ID 已保存', icon: 'none' });
  },

  /** 请求订阅消息授权：一次最多 3 个模板 */
  subscribe() {
    const p = RM.normalizePrefs((store.getSettings() || {}).reminders);
    const ids = String(p.tmplIds || '').split(/[,，\s]+/).filter(Boolean).slice(0, 3);
    if (!ids.length) {
      wx.showModal({
        title: '需先填模板 ID',
        content: '在微信公众平台「订阅消息」中选用节气提醒 / 吉日提醒模板，把模板 ID 填到上面输入框。未配置模板时，本页提醒卡与复制到备忘录仍可正常使用。',
        showCancel: false
      });
      return;
    }
    if (typeof wx.requestSubscribeMessage !== 'function') {
      wx.showToast({ title: '当前环境不支持订阅消息', icon: 'none' });
      return;
    }
    wx.requestSubscribeMessage({
      tmplIds: ids,
      success: (res) => {
        const accepted = ids.filter((id) => res[id] === 'accept');
        if (accepted.length) {
          this.savePrefs({ subscribedAt: Date.now(), tmplIds: ids.join(',') });
          wx.showToast({ title: `已授权 ${accepted.length} 个模板`, icon: 'success' });
        } else {
          wx.showToast({ title: '未授权，仅页内提醒生效', icon: 'none' });
        }
      },
      fail: () => wx.showToast({ title: '授权失败，稍后重试', icon: 'none' })
    });
  },

  copyList() {
    wx.setClipboardData({ data: this.data.copyText, success: () => wx.showToast({ title: '已复制到剪贴板', icon: 'success' }) });
  },

  /** 桌面快捷方式：小程序自身无法直接添加，给出系统菜单路径 */
  addShortcut() {
    wx.showModal({
      title: '添加到桌面 / 我的小程序',
      content: '点右上角「···」→「添加到桌面」或「添加到我的小程序」，即可像小组件一样一键进入罗盘。iOS 可在「···」→「添加到主屏幕」。',
      confirmText: '知道了',
      showCancel: false
    });
  },

  /**
   * 同步到云端推送：把未来提醒写入 luopan_notify_plan，
   * 由云函数 almanac-notify 每日 8:00 扫描下发（算法仍在客户端算，避免两端口径不一致）
   */
  cloudUpload() {
    const ids = String((this.data.prefs || {}).tmplIds || '').split(/[,，\s]+/).filter(Boolean);
    if (!ids.length) {
      wx.showToast({ title: '先填写并授权模板 ID', icon: 'none' });
      return;
    }
    if (typeof wx.cloud !== 'function') {
      wx.showToast({ title: '当前环境未开通云开发', icon: 'none' });
      return;
    }
    const s = store.getSettings() || {};
    const items = this.data.list || [];
    if (!items.length) {
      wx.showToast({ title: '未来几日无可推送提醒', icon: 'none' });
      return;
    }
    wx.showLoading({ title: '同步中' });
    const db = wx.cloud.database();
    const col = db.collection('luopan_notify_plan');
    let ok = 0;
    const tasks = items.map((it) => {
      const dateStr = it.date || '';
      const dueAt = new Date(`${dateStr.replace(/-/g, '/')} 08:00:00`).getTime();
      return col.add({
        data: {
          title: it.title || it.name || '历法提醒',
          date: dateStr,
          detail: it.desc || it.text || '',
          tmplId: ids[0],
          dueAt,
          sent: false,
          createdAt: Date.now(),
          envNote: s.cloudEnv || ''
        }
      }).then(() => { ok += 1; }).catch(() => {});
    });
    Promise.all(tasks)
      .then(() => {
        wx.hideLoading();
        wx.showToast({ title: `已同步 ${ok} 条提醒`, icon: 'none' });
      })
      .catch(() => {
        wx.hideLoading();
        wx.showToast({ title: '同步失败，需部署云函数', icon: 'none' });
      });
  },

  goZeri() {
    nav.go('/pages/zeri/index', { sit: this.data.sit || '子' });
  },

  back() { nav.back(); }
});
