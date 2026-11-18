const ZR = require('../../utils/zeri');
const SF = require('../../utils/sitface');
const ST = require('../../utils/solar-terms');
const store = require('../../utils/store');
const nav = require('../../utils/nav');
const orientation = require('../../utils/orientation');

Page({
  data: {
    dateStr: '',
    sitIdx: 0,
    sit: '子',
    mountainNames: SF.MOUNTAINS_24.map((m) => `${m} 山`),
    orientationLabel: '',
    orientationHint: '',
    concDate: '',
    concSit: '',
    concJianchu: '',
    concYi: '',
    concJi: '',
    concBest: '',
    concGod: '',
    concChong: '',
    concAudit: '',
    concAuditClass: 'ping',
    concTerm: '',
    showDetail: false,
    pillars: '',
    jianchu: '',
    jianchuText: '',
    yi: '',
    ji: '',
    shichen: [],
    best: '',
    warnings: [],
    upcoming: [],
    monthBreak: false,
    huangDaoHours: [],
    activities: [],
    directions: null,
    godText: '',
    godHits: [],
    badHits: [],
    badDays: [],
    chongSha: '',
    ownerYear: 0,
    ownerBranch: '',
    picked: null,
    audit: null,
    term: null,
    termPercent: 0,
    classicalSource: null,
    showEvidence: true,
    weekDays: [],
    weekOffset: 0
  },

  onLoad(options) {
    let sit = orientation.current().sit;
    if (options && options.sit && SF.MOUNTAINS_24.indexOf(options.sit) >= 0) sit = options.sit;
    const now = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    const settings = store.getSettings() || {};
    this.setData({
      sitIdx: SF.MOUNTAINS_24.indexOf(sit),
      dateStr: `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`,
      showEvidence: settings.showEvidence !== false
    });
    this.recompute(now);
  },

  // tabBar 页：一次性跳转参数优先，其次读全局方位源，
  // 让择日始终按当前坐山判冲山/三煞/吉方。
  onShow() {
    const pending = nav.take('/pages/zeri/index');
    let sit = null;
    if (pending && pending.sit && SF.MOUNTAINS_24.indexOf(pending.sit) >= 0) sit = pending.sit;
    if (pending && sit) orientation.applyPending(sit, null);
    if (!sit) sit = orientation.current().sit;
    const orient = orientation.display();
    if (sit && SF.MOUNTAINS_24.indexOf(sit) !== this.data.sitIdx) {
      this.setData({ sitIdx: SF.MOUNTAINS_24.indexOf(sit) });
      this.recompute(new Date(this.data.dateStr.replace(/-/g, '/')));
    } else if (orient.label !== this.data.orientationLabel) {
      this.setData({ orientationLabel: orient.label, orientationHint: orient.hint });
    }
  },

  onDate(e) {
    const d = new Date(e.detail.value.replace(/-/g, '/'));
    this.setData({ dateStr: e.detail.value });
    this.recompute(d);
  },

  onSitChange(e) {
    const sitIdx = parseInt(e.detail.value, 10);
    this.setData({ sitIdx });
    orientation.fromManual(SF.MOUNTAINS_24[sitIdx]);
    const bar = this.selectComponent && this.selectComponent('ctx-bar');
    if (bar && bar.refresh) bar.refresh();
    this.recompute(new Date(this.data.dateStr.replace(/-/g, '/')));
  },

  /** 宅主出生年：优先取档案里的「本人」，其次 settings.ownerBirthYear */
  ownerBirthYear() {
    const profiles = store.getProfiles() || {};
    if (profiles.owner && profiles.owner.birthYear) return parseInt(profiles.owner.birthYear, 10) || 0;
    const members = profiles.members || [];
    const self = members.filter((m) => m.role === '本人')[0] || members[0];
    if (self && self.birthYear) return parseInt(self.birthYear, 10) || 0;
    const s = store.getSettings() || {};
    return parseInt(s.ownerBirthYear, 10) || 0;
  },

  onHour(e) {
    const idx = parseInt(e.currentTarget.dataset.idx, 10);
    const item = this.data.shichen.filter((s) => s.idx === idx)[0] || null;
    this.setData({ picked: item });
  },

  /** 七日历条：今天起七天，标建除与吉凶，点一天即切到该日课期 */
  buildWeek(sit) {
    const ZHI = '子丑寅卯辰巳午未申酉戌亥';
    const WEEK = ['日', '一', '二', '三', '四', '五', '六'];
    const GOOD = ['成', '开', '定', '满', '除'];
    const pad = (n) => String(n).padStart(2, '0');
    const base = new Date();
    base.setHours(0, 0, 0, 0);
    base.setDate(base.getDate() + this.data.weekOffset * 7);
    const todayIso = this._iso(new Date());

    const weekDays = [];
    for (let i = 0; i < 7; i++) {
      const cur = new Date(base.getTime() + i * 86400000);
      const iso = this._iso(cur);
      const jc = ZR.jianChuOf(cur);
      const chongSit = ZHI.indexOf(jc.dayZhi) === (ZHI.indexOf(sit) + 6) % 12;
      weekDays.push({
        iso,
        weekday: WEEK[cur.getDay()],
        dayNum: cur.getDate(),
        month: cur.getMonth() + 1,
        jianChu: jc.name,
        good: GOOD.indexOf(jc.name) >= 0 && !chongSit,
        chong: chongSit,
        isToday: iso === todayIso
      });
    }
    this.setData({ weekDays });
  },

  _iso(d) {
    const pad = (n) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  },

  shiftWeek(e) {
    const delta = parseInt(e.currentTarget.dataset.d, 10) || 0;
    this.setData({ weekOffset: this.data.weekOffset + delta }, () => {
      this.buildWeek(SF.MOUNTAINS_24[this.data.sitIdx]);
    });
  },

  onWeekPick(e) {
    const iso = e.currentTarget.dataset.iso;
    if (!iso) return;
    this.setData({ dateStr: iso });
    this.recompute(new Date(iso.replace(/-/g, '/')));
  },

  recompute(date) {
    const sit = SF.MOUNTAINS_24[this.data.sitIdx];
    const ownerYear = this.ownerBirthYear();
    const r = ZR.analyze(date, sit, { ownerBirthYear: ownerYear });
    const audit = ZR.dayCourseAudit(date, sit, { ownerBirthYear: ownerYear });
    const term = ST.solarTermProgress(date);
    const upcoming = ZR.upcomingAuspicious(date, sit, 6);
    // 每个时辰带上该值神的专项宜忌，供点选查看
    const shichen = r.shichen.map((s) => Object.assign({}, s, { godText: ZR.officerSummary(s.god) }));
    const orient = orientation.display();
    const directions = r.directions || {};
    const wealth = directions.wealth ? `${directions.wealth.dir} ${directions.wealth.name}` : '—';
    const joy = directions.joy ? `${directions.joy.dir} ${directions.joy.name}` : '—';
    const auditOk = audit && audit.isAuspicious;

    this.setData({
      sit,
      orientationLabel: orient.label,
      orientationHint: orient.hint,
      concDate: r.dateText,
      concSit: `坐${sit} · ${r.pillars.fullStr}`,
      concJianchu: `${r.jianChu.name}日`,
      concYi: r.yi || '—',
      concJi: r.ji || '—',
      concBest: (r.bestShichen || []).map((s) => s.name).join('、') || '无',
      concGod: `财神 ${wealth} ｜ 喜神 ${joy}`,
      concChong: r.chongSha ? r.chongSha.text : '',
      concAudit: audit ? `${audit.overallStatus || ''}${audit.groundbreakBadge ? ' · ' + audit.groundbreakBadge : ''}` : '',
      concAuditClass: auditOk ? 'ji' : 'xiong',
      concTerm: `${term.name} · 距${term.nextName} ${term.daysToNext} 天`,
      pillars: r.pillars.fullStr,
      jianchu: r.jianChu.name,
      jianchuText: r.jianChu.text,
      yi: r.yi,
      ji: r.ji,
      shichen,
      best: r.bestShichen.map((s) => s.name).join('、') || '无',
      warnings: r.warnings,
      upcoming,
      monthBreak: r.monthBreak,
      huangDaoHours: r.huangDaoHours,
      activities: r.activities.map((a) => Object.assign({}, a, {
        hoursText: a.hours && a.hours.length
          ? a.hours.map((h) => `${h.name}${h.god ? '（' + h.god + '）' : ''}`).join('、') + (a.hoursFallback ? '（当日无黄道，取六合/三合时）' : '')
          : '本日无可用吉时'
      })),
      godText: r.godText || '',
      godHits: r.godHits || [],
      badHits: r.badHits || [],
      badDays: r.badDays || [],
      directions: r.directions,
      chongSha: r.chongSha.text,
      ownerYear,
      ownerBranch: r.ownerBranch || '',
      audit,
      term: {
        name: term.name,
        nextName: term.nextName,
        daysToNext: term.daysToNext
      },
      termPercent: Math.round(term.progress * 1000) / 10,
      classicalSource: r.classicalSource || null,
      picked: null
    });

    store.track({
      type: 'zeri',
      title: `择日 · ${r.dateText}`,
      sub: `${r.jianChu.name}日 · ${r.pillars.fullStr} · 坐${sit}`,
      sit,
      heading: this.data.sitIdx * 15
    });

    this.buildWeek(sit);
  },

  goDailyCard() {
    wx.navigateTo({ url: '/pages/dailycard/index' });
  },

  toggleDetail() { this.setData({ showDetail: !this.data.showDetail }); },

  back() { nav.back(); }
,

  onShareAppMessage() {
    return { title: '演象时空罗盘 · 择日课期', path: '/pages/zeri/index' };
  },

  /** 朋友圈分享：与好友分享区分，朋友圈侧只带标题与页面路径 */
  onShareTimeline() {
    return { title: '择日课期 · 建除黄黑道与日课自检' };
  }
});
