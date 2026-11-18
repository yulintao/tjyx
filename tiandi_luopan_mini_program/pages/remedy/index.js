/**
 * pages/remedy/index.js
 * 化解清单：跨模块汇总玄空 / 紫白 / 八宅的化解动作，勾选完成、进度与周期提示
 * 结论优先：首屏只给「还剩几项 / 极凶几项 / 完成度」，逐项详解点开才显示
 */

const XK = require('../../utils/xuankong');
const ZB = require('../../utils/zibai');
const BZ = require('../../utils/bazhai');
const SF = require('../../utils/sitface');
const store = require('../../utils/store');
const nav = require('../../utils/nav');

// 玄空与紫白中需要动手化解的凶星
const BAD_CULPRIT = { 2: '二黑病符', 3: '三碧是非', 5: '五黄关煞', 7: '七赤破军', 9: '九紫火星' };

const SOURCE_LABEL = { xuankong: '玄空飞星', zibai: '流年紫白', bazhai: '八宅命卦' };

// 化解周期：形煞与飞星应期不同，按动作类型给复核建议
const CYCLE_HINT = {
  wuhuang: '五黄宜当年内处理，动土或修造前先化解，次月复核',
  erhei: '二黑主病符，宜 60 日内落实并复看睡卧方位',
  sanbi: '三碧主口舌是非，宜 30 日内落实',
  qichi: '七赤主破耗盗损，宜 30 日内落实并检查门窗',
  jiuzi: '九紫主火，宜入宅或换季前复核消防'
};

function cycleOf(starKey) {
  if (starKey === '5' || starKey === '五') return CYCLE_HINT.wuhuang;
  if (starKey === '2' || starKey === '二') return CYCLE_HINT.erhei;
  if (starKey === '3' || starKey === '三') return CYCLE_HINT.sanbi;
  if (starKey === '7' || starKey === '七') return CYCLE_HINT.qichi;
  if (starKey === '9' || starKey === '九') return CYCLE_HINT.jiuzi;
  return '按季度复核一次，换季或装修后重新评估';
}

function lockedSit() {
  const s = store.getSettings() || {};
  const lock = s.compassLock || {};
  if (lock && lock.locked && typeof lock.heading === 'number') {
    const idx = Math.round(((lock.heading % 360) + 360) % 360 / 15) % 24;
    return SF.MOUNTAINS_24[idx];
  }
  return '子';
}

Page({
  data: {
    sit: '子',
    face: '午',
    total: 0,
    doneCount: 0,
    percent: 0,
    criticalCount: 0,
    openCount: 0,
    counts: [],
    activeSource: 'all',
    visible: [],
    filteredCount: 0,
    expandedId: '',
    cycleNotes: []
  },

  onLoad() {
    this.build();
  },

  onShow() {
    this.build();
  },

  build() {
    const sit = lockedSit();
    const face = SF.opposite(sit);
    const period = XK.periodForYear(new Date().getFullYear());
    const chart = XK.calculateChart({ sitMountain: sit, faceMountain: face, period });
    const stored = store.getRemedyTasks() || [];
    const doneMap = {};
    stored.forEach((t) => { if (t && t.id) doneMap[t.id] = !!t.done; });

    const tasks = [];

    // 1) 玄空逐宫：凶星临宫即出化解动作
    chart.cells.forEach((c) => {
      if (!BAD_CULPRIT[c.culprit]) return;
      tasks.push({
        id: `xk_${c.palace}_${c.culprit}`,
        source: 'xuankong',
        sourceLabel: SOURCE_LABEL.xuankong,
        palace: c.palace,
        place: `${c.name}（${c.dir}）`,
        star: c.culpritName,
        starKey: String(c.culprit),
        level: c.culprit === 5 ? 'critical' : (c.culprit === 2 ? 'warning' : 'notice'),
        title: `${c.name}（${c.dir}）· ${c.culpritName}${c.alarm25 ? ' · 二五交加' : ''}`,
        detail: c.action || c.lore || '',
        cycle: cycleOf(String(c.culprit)),
        done: !!doneMap[`xk_${c.palace}_${c.culprit}`]
      });
    });

    // 2) 流年紫白：年星落二黑 / 五黄 / 七赤的宫位
    const zc = ZB.calculateChart();
    (zc.cells || []).forEach((c) => {
      if ([2, 5, 7].indexOf(c.year) < 0) return;
      tasks.push({
        id: `zb_${c.palace}_${c.year}`,
        source: 'zibai',
        sourceLabel: SOURCE_LABEL.zibai,
        palace: c.palace,
        place: `${c.name}（${c.dir}）`,
        star: c.yearTitle || `${c.year}星`,
        starKey: String(c.year),
        level: c.year === 5 ? 'critical' : (c.year === 2 ? 'warning' : 'notice'),
        title: `${c.name}（${c.dir}）· ${c.yearTitle || c.year + '星'}`,
        detail: c.yearRemedy || '',
        cycle: cycleOf(String(c.year)),
        done: !!doneMap[`zb_${c.palace}_${c.year}`]
      });
    });

    // 3) 八宅：每位家人的凶星方位（同一宫同星合并，标注适用人）
    const profiles = store.getProfiles() || {};
    const people = [];
    if (profiles.owner && profiles.owner.birthYear) {
      people.push({ name: profiles.owner.name || '本人', gua: BZ.lifeGua(profiles.owner.birthYear, profiles.owner.gender || '男') });
    }
    (profiles.members || []).forEach((m, i) => {
      if (!m || !m.birthYear) return;
      people.push({ name: m.name || m.role || `成员${i + 1}`, gua: BZ.lifeGua(m.birthYear, m.gender || '男') });
    });
    const bzMap = {};
    people.forEach((p) => {
      BZ.remediesOf(BZ.roamStars(p.gua.num)).forEach((t) => {
        if (!bzMap[t.id]) {
          bzMap[t.id] = Object.assign({}, t, { owners: [p.name] });
        } else if (bzMap[t.id].owners.indexOf(p.name) < 0) {
          bzMap[t.id].owners.push(p.name);
        }
      });
    });
    Object.keys(bzMap).forEach((id) => {
      const t = bzMap[id];
      tasks.push({
        id: `bz_${t.palaceNum}_${t.starKey}`,
        source: 'bazhai',
        sourceLabel: SOURCE_LABEL.bazhai,
        palace: t.palaceNum,
        place: `${t.palace}宫`,
        star: `${t.star}（${t.starName}）`,
        starKey: t.starKey,
        level: t.level >= 3 ? 'critical' : (t.level === 2 ? 'warning' : 'notice'),
        title: `${t.palace}宫 · ${t.star}（${t.starName}）· ${t.owners.join('、')} 适用`,
        detail: t.detail,
        cycle: '命卦方位属常驻性质，入住或换房后 30 日内落实，之后按年复核',
        done: !!doneMap[`bz_${t.palaceNum}_${t.starKey}`]
      });
    });

    const total = tasks.length;
    const doneCount = tasks.filter((t) => t.done).length;
    const percent = total ? Math.round((doneCount / total) * 100) : 0;
    const criticalCount = tasks.filter((t) => t.level === 'critical').length;

    const counts = ['xuankong', 'zibai', 'bazhai']
      .map((k) => ({
        key: k,
        label: SOURCE_LABEL[k],
        count: tasks.filter((t) => t.source === k).length,
        done: tasks.filter((t) => t.source === k && t.done).length
      }))
      .filter((c) => c.count > 0);

    const cycleNotes = [];
    if (criticalCount) {
      cycleNotes.push(`本年有五黄/二五交加 ${criticalCount} 处，属年内必办项：动土、修造、开门前先化解，并避开在该方久坐。`);
    }

    this._tasks = tasks;
    this.setData({
      sit,
      face,
      total,
      doneCount,
      openCount: total - doneCount,
      percent,
      criticalCount,
      counts,
      cycleNotes
    });
    this.applyFilter();
  },

  applyFilter() {
    const all = this._tasks || [];
    const src = this.data.activeSource;
    const filtered = src === 'all' ? all : all.filter((t) => t.source === src);
    this.setData({ visible: filtered, filteredCount: filtered.length });
  },

  onSourceFilter(e) {
    this.setData({ activeSource: e.currentTarget.dataset.key, expandedId: '' });
    this.applyFilter();
  },

  toggleTaskDetail(e) {
    const id = e.currentTarget.dataset.id;
    this.setData({ expandedId: this.data.expandedId === id ? '' : id });
  },

  onToggle(e) {
    const id = e.currentTarget.dataset.id;
    const task = (this._tasks || []).filter((t) => t.id === id)[0];
    if (!task) return;
    store.toggleRemedyTask({ id: task.id, title: task.title, source: task.source, level: task.level });
    this.build();
  },

  onClear(e) {
    const id = e.currentTarget.dataset.id;
    store.removeRemedyTask(id);
    this.build();
  },

  goModule(e) {
    const key = e.currentTarget.dataset.key;
    const page = { xuankong: '/pages/xuankong/index', zibai: '/pages/zibai/index', bazhai: '/pages/bazhai/index' }[key];
    if (!page) return;
    nav.go(page, { sit: this.data.sit, heading: SF.MOUNTAINS_24.indexOf(this.data.sit) * 15 });
  },

  back() { nav.back(); },

  onShareAppMessage() {
    return { title: '演象时空罗盘 · 化解清单', path: '/pages/remedy/index' };
  },

  /** 朋友圈分享：与好友分享区分，朋友圈侧只带标题与页面路径 */
  onShareTimeline() {
    return { title: '化解清单 · 玄空紫白八宅逐项化解' };
  }
});
