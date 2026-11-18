const SF = require('../../utils/sitface');
const XK = require('../../utils/xuankong');
const BZ = require('../../utils/bazhai');
const ZB = require('../../utils/zibai');
const SH = require('../../utils/sanhe');
const ZR = require('../../utils/zeri');
const QM = require('../../utils/qimen');
const store = require('../../utils/store');
const nav = require('../../utils/nav');
const orientation = require('../../utils/orientation');

Page({
  data: {
    sitIdx: 0,
    sit: '子',
    face: '午',
    heading: null,
    mountainNames: SF.MOUNTAINS_24.map((m, i) => `${m} 山`),
    orientationLabel: '',
    orientationHint: '',
    orientationSource: 'default',
    headingText: '',
    concSitFace: '',
    concPattern: '',
    concGua: '',
    concBest: '',
    concWufang: '',
    concJianchu: '',
    concWater: '',
    showDetail: false,
    showTools: false,
    statusText: '',
    periodText: '',
    patternText: '',
    patternLevel: 'ping',
    quick: [],
    entries: [
      { name: '玄空飞星', glyph: '飛', badge: '理气', desc: '三元九运 · 山向飞星 · 81 组合断', url: '../xuankong/index' },
      { name: '八宅明镜', glyph: '宅', badge: '理气', desc: '命卦 · 大游年 · 家人配房', url: '../bazhai/index' },
      { name: '紫白九星', glyph: '紫', badge: '流年', desc: '年月紫白 · 五黄二黑 · 太岁三煞', url: '../zibai/index' },
      { name: '三合水法', glyph: '水', badge: '理气', desc: '八路黄泉 · 八煞 · 十二长生', url: '../sanhe/index' },
      { name: '择日课期', glyph: '曆', badge: '择吉', desc: '建除十二神 · 黄黑道 · 事项择日', url: '../zeri/index' },
      { name: '今日日签', glyph: '籤', badge: '择吉', desc: '干支宜忌 · 财神喜神 · 存相册分享', url: '../dailycard/index' },
      { name: '化解清单', glyph: '化', badge: '落实', desc: '玄空紫白八宅 · 逐项化解 · 完成度', url: '../remedy/index' },
      { name: '提醒中心', glyph: '鈴', badge: '日程', desc: '节气换月 · 岁破冲山 · 未来吉日 · 订阅授权', url: '../notify/index' },
      { name: '备份与恢复', glyph: '備', badge: '数据', desc: '导出入 JSON · 合并恢复 · 云开发可选', url: '../backup/index' },
      { name: '功能权益', glyph: '權', badge: '说明', desc: '原会员权益对照 · 本版全部开放', url: '../vip/index' },
      { name: '鲁班门光尺', glyph: '尺', badge: '测量', desc: '门宽吉凶速测 · 门光尺 / 丁兰尺双口径', url: '../luban/index' },
      { name: '奇门遁甲', glyph: '奇', badge: '择吉', desc: '时家奇门 · 值符值使 · 用神场景', url: '../qimen/index' },
      { name: '户型九宫', glyph: '宮', badge: '空间', desc: '房间归宫 · 缺角 · 房间审计', url: '../floorplan/index' },
      { name: '测绘报告', glyph: '圖', badge: '空间', desc: '面宽进深 · 空间得分 · 缺角凶宫长图', url: '../report/index' },
      { name: '天机长卷', glyph: '卷', badge: '综合', desc: '全盘汇总 · 一图导出', url: '../tianji/index' },
      { name: '分金一百二十', glyph: '金', badge: '立向', desc: '珠宝火坑 · 纳音断语 · 二十四山吉度', url: '../fenjin/index' },
      { name: '六十四卦', glyph: '卦', badge: '易理', desc: '抽爻换象 · 之卦互卦错卦综卦', url: '../gua64/index' },
      { name: '外煞自查', glyph: '煞', badge: '形煞', desc: '形煞辨识 · 影响 · 化解', url: '../sha/index' },
      { name: '实景叠盘', glyph: '景', badge: '实景', desc: '相机取景 · 靶心测角 · 水印存证', url: '../ar/index' },
      { name: '设置', glyph: '設', badge: '配置', desc: '单位 · 清除数据 · 关于', url: '../settings/index' },
      { name: '分享海报', glyph: '報', badge: '分享', desc: '盘面海报 · 存相册 · 分享卡片', url: '../poster/index' },
      { name: '浏览历史', glyph: '跡', badge: '记录', desc: '最近 30 条盘解/海报留痕', url: '../history/index' }
    ]
  },

  onLoad(options) {
    let sit = null;
    let heading = null;
    if (options && options.sit && SF.MOUNTAINS_24.indexOf(options.sit) >= 0) {
      sit = options.sit;
    } else if (options && options.heading !== undefined) {
      heading = parseFloat(options.heading);
      sit = SF.fromHeading(heading).sit;
    }
    if (options && options.heading !== undefined) heading = parseFloat(options.heading);
    if (!sit) {
      const cur = orientation.current();
      sit = cur.sit;
      if (heading === null) heading = cur.heading;
    }
    this.setData({ sitIdx: Math.max(0, SF.MOUNTAINS_24.indexOf(sit)), heading });
    this.recompute();
  },

  // tabBar 页无法用 url 带参：优先取一次性跳转参数，其次取全局方位源，
  // 保证从任意 tab 进入、或罗盘方位改变后再回来，都按当前坐向重算。
  onShow() {
    const pending = nav.take('/pages/analysis/index');
    let sit = null;
    let heading = null;
    if (pending) {
      if (pending.sit && SF.MOUNTAINS_24.indexOf(pending.sit) >= 0) {
        sit = pending.sit;
      } else if (pending.heading !== undefined && pending.heading !== null && !isNaN(Number(pending.heading))) {
        heading = Number(pending.heading);
        sit = SF.fromHeading(heading).sit;
      }
      if (pending.heading !== undefined && pending.heading !== null && !isNaN(Number(pending.heading))) {
        heading = Number(pending.heading);
      }
    }
    if (pending && sit) {
      // 一次性跳转参数同样写回全局，保证其余页与「坐向来源」标签一致
      orientation.applyPending(sit, heading);
    }
    const cur = orientation.current();
    if (!sit) {
      sit = cur.sit;
      heading = cur.heading;
    }
    const nextIdx = Math.max(0, SF.MOUNTAINS_24.indexOf(sit));
    if (nextIdx !== this.data.sitIdx || heading !== this.data.heading || cur.source !== this.data.orientationSource) {
      this.setData({ sitIdx: nextIdx, heading });
      this.recompute();
    } else {
      this.refreshCtxBar();
    }
    this.startCompassFollow();
  },

  onHide() {
    this.stopCompassFollow();
  },

  onUnload() {
    this.stopCompassFollow();
  },

  refreshCtxBar() {
    const bar = this.selectComponent && this.selectComponent('#ctxBar');
    if (bar && typeof bar.refresh === 'function') bar.refresh();
  },

  startCompassFollow() {
    if (this._compassFollowing) return;
    if (typeof wx === 'undefined' || typeof wx.startCompass !== 'function' || typeof wx.onCompassChange !== 'function') return;
    const cur = orientation.current();
    const lock = (store.getSettings() || {}).compassLock || {};
    if (cur.source === 'manual' || lock.locked) return;

    this._compassFollowing = true;
    this._lastFollowAt = 0;
    this._compassHandler = (res) => {
      if (!this._compassFollowing) return;
      if (res.direction === undefined || res.direction === null || isNaN(res.direction)) return;
      const curState = orientation.current();
      const lockState = (store.getSettings() || {}).compassLock || {};
      if (curState.source === 'manual' || lockState.locked) return;

      const now = Date.now();
      const dir = ((res.direction % 360) + 360) % 360;
      const diag = SF.diagnoseHeading(dir);
      const nextIdx = SF.MOUNTAINS_24.indexOf(diag.sit);
      const prevH = this.data.heading;
      const diff = (prevH === null || prevH === undefined) ? 999 : Math.abs(((dir - prevH + 540) % 360) - 180);
      const sitChanged = nextIdx >= 0 && nextIdx !== this.data.sitIdx;

      if (!sitChanged && diff < 1.5) return;
      if (!sitChanged && now - this._lastFollowAt < 250) return;
      this._lastFollowAt = now;

      const next = orientation.fromCompass(dir);
      const roundedDeg = Math.round(dir * 10) / 10;
      if (sitChanged || next.source !== this.data.orientationSource) {
        this.setData({ sitIdx: nextIdx, heading: roundedDeg });
        this.recompute(true);
      } else {
        this.setData({
          heading: roundedDeg,
          headingText: `${roundedDeg.toFixed(1)}°`
        });
        this.refreshCtxBar();
      }
    };

    wx.startCompass({
      interval: 'ui',
      success: () => {
        if (this._compassFollowing) wx.onCompassChange(this._compassHandler);
      },
      fail: () => {
        this._compassFollowing = false;
      }
    });
  },

  stopCompassFollow() {
    this._compassFollowing = false;
    if (typeof wx !== 'undefined') {
      if (typeof wx.offCompassChange === 'function' && this._compassHandler) {
        wx.offCompassChange(this._compassHandler);
      }
      if (typeof wx.stopCompass === 'function') {
        wx.stopCompass();
      }
    }
    this._compassHandler = null;
  },

  resumeCompassFollow() {
    const s = store.getSettings() || {};
    if (s.compassLock && s.compassLock.locked) {
      s.compassLock.locked = false;
      store.saveSettings(s);
    }
    orientation.releaseManual();
    const cur = orientation.current();
    this.setData({
      sitIdx: Math.max(0, SF.MOUNTAINS_24.indexOf(cur.sit)),
      heading: cur.heading
    });
    this.recompute(true);
    this.startCompassFollow();
    wx.showToast({ title: '已恢复跟随罗盘实时方位', icon: 'none' });
  },

  onSitChange(e) {
    const sitIdx = parseInt(e.detail.value, 10);
    const sit = SF.MOUNTAINS_24[sitIdx];
    const heading = SF.azimuthOf(sit);
    this.setData({ sitIdx, heading });
    // 手选坐山写回全局，择日/户型页随后进入时同步
    orientation.fromManual(sit);
    this.recompute();
  },

  recompute(skipTrack) {
    const sit = SF.MOUNTAINS_24[this.data.sitIdx];
    const face = SF.opposite(sit);
    const now = new Date();
    const period = XK.periodForYear(now.getFullYear());

    const xk = XK.calculateChart({ sitMountain: sit, faceMountain: face, period });
    const gua = SF.houseGuaName(sit);
    const roam = BZ.roamStars(gua);
    const zb = ZB.calculateChart(now, { sitPalace: xk.sitPalace, facePalace: xk.facePalace });
    const sh = SH.analyze(sit, face);
    const zr = ZR.analyze(now, sit);
    const qm = QM.calculateChart(now);

    const quick = [
      { k: '元运', v: `${xk.periodText}（${xk.periodRange.start}–${xk.periodRange.end}）` },
      { k: '格局', v: xk.patternText.split(' · ')[0] },
      { k: '宅卦', v: `${gua}宅 · ${roam.group}` },
      { k: '第一吉方', v: `${roam.best.palace}（${roam.best.star}）` },
      { k: '流年五黄', v: XK.PALACE_INFO[zb.fivePalace].dir },
      { k: '二黑', v: XK.PALACE_INFO[zb.twoPalace].dir },
      { k: '水法', v: `${sh.bureau.name} · ${sh.verdict}` },
      { k: '今日建除', v: `${zr.jianChu.name}日` },
      { k: '奇门局', v: qm.juText }
    ];

    const orient = orientation.display();
    const headingVal = (this.data.heading !== null && this.data.heading !== undefined && !isNaN(Number(this.data.heading)))
      ? Number(this.data.heading)
      : orient.heading;
    const headingText = (headingVal !== null && headingVal !== undefined && !isNaN(headingVal))
      ? `${(((headingVal % 360) + 360) % 360).toFixed(1)}°`
      : '';

    this.setData({
      sit,
      face,
      orientationLabel: orient.label,
      orientationHint: orient.hint,
      orientationSource: orient.source,
      headingText,
      concSitFace: `${sit}山${face}向 · ${xk.periodText}`,
      concPattern: xk.patternText.split(' · ')[0],
      concGua: `${gua}宅 · 第一吉方 ${roam.best.palace}（${roam.best.star}）`,
      concBest: `吉时 ${(zr.bestShichen || []).map((s) => s.name).join('、') || '无'}`,
      concWufang: `五黄 ${XK.PALACE_INFO[zb.fivePalace].dir} · 二黑 ${XK.PALACE_INFO[zb.twoPalace].dir}`,
      concJianchu: `今日${zr.jianChu.name}日 · 宜 ${zr.yi}`,
      concWater: `${sh.bureau.name} · ${sh.verdict}`,
      statusText: `${sit}山${face}向 · ${xk.chartTypeText}`,
      periodText: xk.periodText,
      patternText: xk.patternText,
      patternLevel: xk.patternLevel,
      quick
    });
    this.refreshCtxBar();

    if (!skipTrack) {
      store.track({
        type: 'analysis',
        title: `盘解 · ${sit}山${face}向`,
        sub: `${xk.periodText} · ${xk.patternText.split(' · ')[0]} · ${roam.group}`,
        sit,
        heading: headingVal !== undefined && headingVal !== null ? headingVal : this.data.sitIdx * 15
      });
    }
  },

  onEntry(e) {
    const url = e.currentTarget.dataset.url;
    if (!url) return;
    if (/fenjin|gua64|poster/.test(url)) {
      // 这几页按「朝向」取度数：优先传当前精确朝向角，否则取坐山对宫
      const faceIdx = (this.data.sitIdx + 12) % 24;
      const h = (this.data.heading !== null && this.data.heading !== undefined && !isNaN(Number(this.data.heading)))
        ? Number(this.data.heading)
        : faceIdx * 15;
      nav.go(url, { heading: h });
      return;
    }
    const needSit = /xuankong|bazhai|zibai|sanhe|zeri|qimen|tianji|remedy|sha|floorplan/.test(url);
    nav.go(url, needSit ? { sit: this.data.sit, heading: this.data.heading } : null);
  },

  goXuankong() { nav.go('../xuankong/index', { sit: this.data.sit, heading: this.data.heading }); },
  goBazhai() { nav.go('../bazhai/index', { sit: this.data.sit }); },
  goZibai() { nav.go('../zibai/index', { sit: this.data.sit }); },
  goSanhe() { nav.go('../sanhe/index', { sit: this.data.sit }); },
  goZeri() { nav.go('../zeri/index', { sit: this.data.sit }); },
  goQimen() { nav.go('../qimen/index', { sit: this.data.sit }); },
  goTianji() { nav.go('../tianji/index', { sit: this.data.sit }); },
  goFloorplan() { nav.go('../floorplan/index', { sit: this.data.sit }); },
  goCompass() { nav.go('../index/index'); },
  toggleDetail() { this.setData({ showDetail: !this.data.showDetail }); },
  toggleTools() { this.setData({ showTools: !this.data.showTools }); },
  back() { nav.back(); }
,

  onShareAppMessage() {
    return { title: '演象时空罗盘 · 盘解', path: '/pages/analysis/index' };
  },

  /** 朋友圈分享：与好友分享区分，朋友圈侧只带标题与页面路径 */
  onShareTimeline() {
    return { title: '盘解 · 玄空八宅紫白一屏看尽' };
  }
});
