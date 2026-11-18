/**
 * pages/backup/index.js
 * 备份与恢复（替代 iOS iCloud KVS）：导出 JSON / 粘贴恢复 / 选择文件恢复 / 云开发（可选）
 */

const BK = require('../../utils/backup');
const store = require('../../utils/store');
const nav = require('../../utils/nav');

Page({
  data: {
    summary: null,
    pending: null,
    pendingSummary: null,
    mode: 'merge',
    preview: '',
    previewLines: [],
    diff: null,
    cloudReady: false,
    cloudEnv: '',
    cloudState: '未初始化',
    result: '',
    storageHint: '',
    undo: null
  },

  onLoad() {
    this.refresh();
  },

  refresh() {
    const s = BK.summaryOf(BK.collect());
    this.setData({
      summary: s,
      storageHint: this.storageHint(),
      undo: BK.getUndo(),
      log: this.formatLog(BK.getLog()),
      cloudReady: BK.cloudAvailable(),
      cloudEnv: (store.getSettings() || {}).cloudEnv || ''
    });
  },

  /** 容量预警：存储快满时提示，恢复失败会自动回滚但仍值得先知道 */
  storageHint() {
    try {
      const info = wx.getStorageInfoSync();
      if (!info || !info.limitSize) return '';
      const pct = Math.round((info.currentSize / info.limitSize) * 100);
      if (pct < 85) return '';
      return `本机存储已用 ${pct}%（${info.currentSize}KB / ${info.limitSize}KB），恢复可能因空间不足中断，失败会自动回滚。`;
    } catch (e) {
      return '';
    }
  },

  /** 导出：写临时文件并尝试分享，失败则复制到剪贴板 */
  onExport() {
    const text = BK.serialize();
    wx.setClipboardData({
      data: text,
      success: () => wx.showToast({ title: '备份已复制', icon: 'success' }),
      fail: () => wx.showToast({ title: '复制失败', icon: 'none' })
    });
  },

  onExportFile() {
    const text = BK.serialize();
    try {
      const fs = wx.getFileSystemManager();
      const path = `${wx.env.USER_DATA_PATH}/luopan-backup-${Date.now()}.json`;
      fs.writeFileSync(path, text, 'utf8');
      wx.showModal({
        title: '备份文件已生成',
        content: '可在「聊天文件」或开发者工具的 用户目录 找到该文件；也可直接复制文本备份。',
        confirmText: '复制文本',
        success: (r) => { if (r.confirm) this.onExport(); }
      });
    } catch (e) {
      this.onExport();
    }
  },

  /** 从剪贴板读取备份 */
  onPaste() {
    wx.getClipboardData({
      success: (res) => {
        const r = BK.parse(res.data);
        if (r.error) {
          wx.showToast({ title: r.error, icon: 'none' });
          return;
        }
        this.setData({ pending: r.data, pendingSummary: r.summary, preview: this.brief(r.summary), mode: 'merge' });
        this.refreshPreview();
      },
      fail: () => wx.showToast({ title: '读取剪贴板失败', icon: 'none' })
    });
  },

  /** 从聊天文件读取备份 */
  onChooseFile() {
    if (typeof wx.chooseMessageFile !== 'function') {
      wx.showToast({ title: '当前环境不支持选择文件', icon: 'none' });
      return;
    }
    wx.chooseMessageFile({
      count: 1,
      type: 'file',
      extension: ['json'],
      success: (res) => {
        const f = res.tempFiles && res.tempFiles[0];
        if (!f) return;
        try {
          const fs = wx.getFileSystemManager();
          const text = fs.readFileSync(f.path, 'utf8');
          const r = BK.parse(text);
          if (r.error) {
            wx.showToast({ title: r.error, icon: 'none' });
            return;
          }
          this.setData({ pending: r.data, pendingSummary: r.summary, preview: this.brief(r.summary), mode: 'merge' });
        this.refreshPreview();
        } catch (e) {
          wx.showToast({ title: '文件读取失败', icon: 'none' });
        }
      }
    });
  },

  brief(s) {
    if (!s) return '';
    const extra = [
      s.placeName ? `位置 ${s.placeName}` : '',
      s.hasOrientation ? '坐向' : '',
      s.shaChecked ? `外煞勾选 ${s.shaChecked} 项` : ''
    ].filter(Boolean).join(' · ');
    return `备份时间 ${s.at} · 家人 ${s.members} 人 · 户型 ${s.floorplans} 套 · 化解 ${s.remedyTasks} 项 · 历史 ${s.history} 条${extra ? ' · ' + extra : ''}`;
  },

  /** 导入前差异：这份备份落到本机会变成什么样 */
  buildPreview(data, mode) {
    if (!data) return { lines: [], diff: null };
    const d = BK.diff(data, mode);
    const extraText = { none: '不含此段', keep: '保留本机', overwrite: '覆盖本机', set: '补入本机' };
    const lines = [];
    if (d.mode === 'merge') {
      lines.push(`家人：新增 ${d.members.add} 人 · 已存在 ${d.members.dup} 人（去重后最多 12 人）`);
      lines.push(`户型：新增 ${d.floorplans.add} 套 · 已存在 ${d.floorplans.dup} 套（最多 20 套）`);
      lines.push(`化解：新增 ${d.tasks.add} 项 · 已存在 ${d.tasks.dup} 项${d.tasks.dup && d.tasks.newlyDone ? `，其中 ${d.tasks.newlyDone} 项将标记为已完成` : ''}`);
      lines.push(`历史：新增 ${d.history.add} 条 · 已存在 ${d.history.dup} 条（最多 30 条）`);
      lines.push(`设置：${d.settings.changed ? '以本机为准，' + d.settings.keys.join('、') + ' 保持本机值' : '与备份一致'}`);
    } else {
      lines.push(`家人：将替换为 ${d.members.incoming} 人`);
      lines.push(`户型：将替换为 ${d.floorplans.incoming} 套${d.floorplans.dropped ? `，本机多出的 ${d.floorplans.dropped} 套会被丢弃` : ''}`);
      lines.push(`化解：将替换为 ${d.tasks.incoming} 项`);
      lines.push(`历史：将替换为 ${d.history.incoming} 条${d.history.dropped ? `，本机多出的 ${d.history.dropped} 条会被丢弃` : ''}`);
      lines.push(`设置：${d.settings.changed ? '将改为备份值（' + d.settings.keys.join('、') + '）' : '与备份一致'}`);
    }
    lines.push(`位置：${extraText[d.place.action]}${d.place.placeName ? '（' + d.place.placeName + '）' : ''}`);
    lines.push(`坐向：${extraText[d.orientation.action]}`);
    lines.push(`外煞勾选：${extraText[d.shaCheck.action]}${d.shaCheck.action !== 'none' ? `（本机 ${d.shaCheck.local} 项 / 备份 ${d.shaCheck.incoming} 项）` : ''}`);
    if (d.reportDraft.action !== 'none') lines.push(`报告草稿：${extraText[d.reportDraft.action]}`);
    return { lines, diff: d };
  },

  refreshPreview() {
    const p = this.buildPreview(this.data.pending, this.data.mode);
    this.setData({ previewLines: p.lines, diff: p.diff });
  },

  onMode(e) {
    const mode = e.currentTarget.dataset.mode === 'replace' ? 'replace' : 'merge';
    this.setData({ mode });
    this.refreshPreview();
  },

  onApply() {
    if (!this.data.pending) {
      wx.showToast({ title: '请先读取备份', icon: 'none' });
      return;
    }
    wx.showModal({
      title: this.data.mode === 'replace' ? '覆盖本机数据？' : '合并到本机数据？',
      content: (this.data.mode === 'replace'
        ? '将用备份内容替换本机的档案、户型、化解任务、历史，以及位置、坐向、外煞勾选与报告草稿，此操作不可撤销。'
        : '将把备份中的档案、户型、任务与历史并入本机，重复项按 id 去重；位置、坐向等现场数据本机已有则保留本机。')
        + (this.data.storageHint ? '\n\n' + this.data.storageHint : ''),
      success: (r) => {
        if (!r.confirm) return;
        try {
          const st = BK.apply(this.data.pending, this.data.mode);
          if (st.error) {
            this.setData({ result: '恢复失败：' + st.error });
            wx.showToast({ title: st.error, icon: 'none' });
            this.refresh();
            return;
          }
          this.setData({
            pending: null,
            pendingSummary: null,
            preview: '',
            previewLines: [],
            result: `恢复完成：家人 ${st.members} 人 · 户型 ${st.floorplans} 套 · 化解 ${st.remedyTasks} 项 · 历史 ${st.history} 条 · 位置 ${st.place ? '已恢复' : '无'} · 外煞勾选 ${st.shaCheck} 项（${st.mode === 'replace' ? '覆盖' : '合并'}）`
          });
          this.refresh();
        } catch (e) {
          wx.showToast({ title: '恢复失败：' + (e.message || ''), icon: 'none' });
        }
      }
    });
  },

  /** 恢复日志只展示最近 5 条，其余留在本机 */
  formatLog(list) {
    return (list || []).slice(0, 5).map((x) => ({
      id: x.id,
      atText: x.at ? new Date(x.at).toLocaleString() : '',
      title: x.action === 'undo' ? '撤销' : '恢复',
      modeText: x.mode === 'replace' ? '覆盖' : (x.mode === 'merge' ? '合并' : ''),
      ok: !!x.ok,
      text: x.ok
        ? `成功 · 家人 ${x.members || 0} 人 · 户型 ${x.floorplans || 0} 套 · 化解 ${x.remedyTasks || 0} 项`
        : `失败 · ${x.error || '写入未完成'}`
    }));
  },

  /** 撤销上一次恢复：用恢复前的撤销点整体覆盖回去 */
  onUndo() {
    const u = this.data.undo;
    if (!u) {
      wx.showToast({ title: '没有可撤销的恢复记录', icon: 'none' });
      return;
    }
    if (u.expired) {
      wx.showToast({ title: '撤销点已超过 7 天，已清除', icon: 'none' });
      BK.restoreUndo();
      this.refresh();
      return;
    }
    wx.showModal({
      title: '撤销上次恢复？',
      content: `将回到 ${u.atText} 恢复前的数据（家人 ${u.summary.members} 人 · 户型 ${u.summary.floorplans} 套 · 化解 ${u.summary.remedyTasks} 项 · 历史 ${u.summary.history} 条）。撤销本身也会留一个撤销点，可再撤回来。`,
      success: (r) => {
        if (!r.confirm) return;
        const st = BK.restoreUndo();
        if (st.error) {
          this.setData({ result: '撤销失败：' + st.error });
          wx.showToast({ title: st.error, icon: 'none' });
          this.refresh();
          return;
        }
        this.setData({ result: `已撤销上次恢复：家人 ${st.members} 人 · 户型 ${st.floorplans} 套 · 化解 ${st.remedyTasks} 项 · 历史 ${st.history} 条` });
        this.refresh();
      }
    });
  },

  onCloudEnv(e) {
    this.setData({ cloudEnv: e.detail.value });
  },

  onCloudInit() {
    const env = String(this.data.cloudEnv || '').trim();
    const r = BK.cloudInit(env || undefined);
    if (r.error) {
      wx.showToast({ title: r.error, icon: 'none' });
      return;
    }
    const s = store.getSettings() || {};
    s.cloudEnv = env;
    store.saveSettings(s);
    this.setData({ cloudState: '已初始化' });
    wx.showToast({ title: '云开发已初始化', icon: 'success' });
  },

  onCloudSave() {
    BK.cloudSave()
      .then(() => {
        this.setData({ cloudState: '已上传云端' });
        wx.showToast({ title: '已备份到云端', icon: 'success' });
      })
      .catch((e) => wx.showToast({ title: e.message || '上传失败', icon: 'none' }));
  },

  onCloudLoad() {
    BK.cloudLoad()
      .then((doc) => {
        if (!doc) {
          wx.showToast({ title: '云端暂无备份', icon: 'none' });
          return;
        }
        const r = BK.parse(JSON.stringify(doc));
        if (r.error) {
          wx.showToast({ title: r.error, icon: 'none' });
          return;
        }
        this.setData({ pending: r.data, pendingSummary: r.summary, preview: this.brief(r.summary), mode: 'merge' });
        this.refreshPreview();
      })
      .catch((e) => wx.showToast({ title: e.message || '读取失败', icon: 'none' }));
  },

  back() { nav.back(); }
});
