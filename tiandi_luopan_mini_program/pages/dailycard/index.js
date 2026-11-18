const ZR = require('../../utils/zeri');
const DC = require('../../utils/dailycard');
const ST = require('../../utils/solar-terms');

const WEEK = ['日', '一', '二', '三', '四', '五', '六'];

Page({
  data: {
    dateText: '',
    weekText: '',
    yearPillar: '',
    monthPillar: '',
    dayPillar: '',
    jianChu: '',
    godName: '',
    solarName: '',
    yi: '',
    ji: '',
    wealthDir: '',
    wealthName: '',
    wealthAngle: '',
    joyDir: '',
    joyName: '',
    joyAngle: '',
    chongText: '',
    bestHours: [],
    warnings: [],
    officerText: '',
    cardPath: '',
    saved: false
  },

  onLoad() {
    this.compute();
  },

  compute() {
    const now = new Date();
    const a = ZR.analyze(now, null, {});
    const dirs = ZR.dailyCompassDirections(now);
    let solarName = '';
    try {
      const t = ST.getTodayMountainInfo();
      solarName = (t && t.solarName) || '';
    } catch (e) {
      solarName = '';
    }

    // 日值神：十二值神按日支轮值，子时之神即为当日值神
    const godName = (a.todayGods && a.todayGods[0]) || '';
    const officerText = godName ? ZR.officerSummary(godName) : '';

    const jc = a.jianChu || {};
    const yiText = Array.isArray(a.yi) ? a.yi.join('、') : (a.yi || '');
    const jiText = Array.isArray(a.ji) ? a.ji.join('、') : (a.ji || '');

    // 节气进度（对齐 iOS WidgetAlmanacSnapshot / SolarTimeCalculator.solarTermProgress）
    let termPercent = 0;
    let nextTermText = '';
    try {
      const tp = ST.solarTermProgress(now);
      termPercent = Math.round(tp.progress * 100);
      nextTermText = `${tp.nextName} · ${tp.daysToNext} 天后`;
    } catch (e) {}

    this.payload = {
      dateText: a.dateText,
      weekText: WEEK[now.getDay()],
      lunarText: solarName ? `节气·${solarName}` : '',
      pillars: a.pillars,
      jianChu: jc,
      godName,
      solarName,
      wealth: dirs.wealth,
      joy: dirs.joy,
      chong: a.chongSha,
      yi: yiText,
      ji: jiText,
      bestHours: (a.bestShichen || []).map((s) => s.name),
      warnings: a.warnings || []
    };

    this.setData({
      dateText: a.dateText,
      weekText: WEEK[now.getDay()],
      yearPillar: a.pillars.yearPillar,
      monthPillar: a.pillars.monthPillar,
      dayPillar: a.pillars.dayPillar,
      jianChu: jc.name,
      godName,
      solarName,
      yi: yiText,
      ji: jiText,
      wealthDir: dirs.wealth.dir,
      wealthName: dirs.wealth.name,
      wealthAngle: dirs.wealth.angle,
      joyDir: dirs.joy.dir,
      joyName: dirs.joy.name,
      joyAngle: dirs.joy.angle,
      chongText: a.chongSha.text,
      bestHours: (a.bestShichen || []).map((s) => s.name),
      warnings: a.warnings || [],
      officerText,
      termPercent,
      nextTermText
    });

    setTimeout(() => this.draw(), 120);
  },

  draw() {
    const q = wx.createSelectorQuery().in(this);
    q.select('#dailyCardCanvas').fields({ node: true, size: true }).exec((res) => {
      const item = res && res[0];
      if (!item || !item.node) return;
      const canvas = item.node;
      const ctx = canvas.getContext('2d');
      const W = 750;
      const H = 1334;
      const scale = 2;
      canvas.width = W * scale;
      canvas.height = H * scale;
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.scale(scale, scale);
      ctx.clearRect(0, 0, W, H);

      DC.draw(ctx, W, H, this.payload || {});

      wx.canvasToTempFilePath({
        canvas,
        x: 0,
        y: 0,
        width: W * scale,
        height: H * scale,
        destWidth: W * scale,
        destHeight: H * scale,
        success: (r) => this.setData({ cardPath: r.tempFilePath }),
        fail: () => wx.showToast({ title: '日签生成失败', icon: 'none' })
      });
    });
  },

  save() {
    if (!this.data.cardPath) {
      wx.showToast({ title: '日签尚未生成', icon: 'none' });
      return;
    }
    wx.saveImageToPhotosAlbum({
      filePath: this.data.cardPath,
      success: () => {
        this.setData({ saved: true });
        wx.showToast({ title: '已存入相册', icon: 'success' });
      },
      fail: () => {
        wx.showModal({
          title: '需要相册权限',
          content: '保存日签到相册需要授权，请在设置中开启“保存到相册”。',
          confirmText: '去设置',
          success: (r) => {
            if (r.confirm) wx.openSetting({});
          }
        });
      }
    });
  },

  preview() {
    if (!this.data.cardPath) return;
    wx.previewImage({ urls: [this.data.cardPath], current: this.data.cardPath });
  },

  goZeri() {
    wx.navigateTo({ url: '/pages/zeri/index' });
  },

  back() { wx.navigateBack({ delta: 1 }); },

  onShareAppMessage() {
    const d = this.payload || {};
    return {
      title: `${d.dateText || ''} ${d.jianChu ? d.jianChu.name + '日' : ''} · 今日财神${d.wealth ? d.wealth.dir : ''}`,
      path: '/pages/dailycard/index',
      imageUrl: this.data.cardPath || ''
    };
  },

  /** 朋友圈分享：与好友分享区分，朋友圈侧只带标题与页面路径 */
  onShareTimeline() {
    return { title: '今日日签 · 干支宜忌与财神喜神' };
  },
});
