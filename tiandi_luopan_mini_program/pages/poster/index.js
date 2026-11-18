const SF = require('../../utils/sitface');
const FENJIN = require('../../utils/fenjin');
const XK = require('../../utils/xuankong');
const POSTER = require('../../utils/poster');
const store = require('../../utils/store');

Page({
  data: {
    sit: '子',
    face: '午',
    heading: 0,
    jiazi: '',
    grade: '',
    nayin: '',
    period: 9,
    shan: '',
    xiang: '',
    pattern: '',
    dateText: '',
    posterPath: '',
    saved: false
  },

  onLoad(options) {
    let heading = Number(options && options.heading);
    if (isNaN(heading)) {
      const sitFromOpt = options && options.sit;
      const idx = SF.MOUNTAINS_24.indexOf(sitFromOpt);
      // 传入的是坐山，朝向取其对宫（子山午向 → 180°）
      heading = idx >= 0 ? ((idx + 12) % 24) * 15 : 0;
    }
    heading = ((heading % 360) + 360) % 360;

    const sit = SF.fromHeading(heading).sit;
    const face = SF.opposite(sit);
    const year = new Date().getFullYear();
    const period = XK.periodForYear(year);
    const chart = XK.calculateChart({ sitMountain: sit, faceMountain: face, period });
    const fj = FENJIN.resolve(heading);

    const now = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    const dateText = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;

    this.setData({
      sit,
      face,
      heading: Math.round(heading * 10) / 10,
      jiazi: fj.jiazi,
      grade: fj.grade,
      nayin: fj.nayin,
      period,
      shan: chart.shanStar,
      xiang: chart.xiangStar,
      pattern: chart.patternText,
      dateText
    });

    setTimeout(() => this.draw(chart), 120);
  },

  draw(chart) {
    const q = wx.createSelectorQuery().in(this);
    q.select('#posterCanvas').fields({ node: true, size: true }).exec((res) => {
      const item = res && res[0];
      if (!item || !item.node) return;
      const canvas = item.node;
      const ctx = canvas.getContext('2d');
      const W = 750;
      const H = 1200;
      const scale = 2;
      canvas.width = W * scale;
      canvas.height = H * scale;
      ctx.scale(scale, scale);

      const data = this.data;
      POSTER.draw(ctx, W, H, {
        sit: data.sit,
        face: data.face,
        heading: data.heading,
        jiazi: data.jiazi,
        grade: data.grade,
        nayin: data.nayin,
        period: data.period,
        shan: data.shan,
        xiang: data.xiang,
        pattern: data.pattern,
        dateText: data.dateText
      });

      wx.canvasToTempFilePath({
        canvas,
        x: 0,
        y: 0,
        width: W * scale,
        height: H * scale,
        destWidth: W * scale,
        destHeight: H * scale,
        success: (r) => {
          this.setData({ posterPath: r.tempFilePath });
          store.pushHistory({
            type: 'poster',
            title: `海报 · ${data.sit}山${data.face}向`,
            sub: `${data.jiazi} ${data.grade} · ${data.period}运 ${data.shan}${data.xiang}`,
            sit: data.sit,
            heading: data.heading
          });
        },
        fail: () => wx.showToast({ title: '海报生成失败', icon: 'none' })
      });
    });
  },

  save() {
    if (!this.data.posterPath) {
      wx.showToast({ title: '海报尚未生成', icon: 'none' });
      return;
    }
    wx.saveImageToPhotosAlbum({
      filePath: this.data.posterPath,
      success: () => {
        this.setData({ saved: true });
        wx.showToast({ title: '已存入相册', icon: 'success' });
      },
      fail: () => wx.showToast({ title: '保存失败，请允许相册权限', icon: 'none' })
    });
  },

  preview() {
    if (!this.data.posterPath) return;
    wx.previewImage({ urls: [this.data.posterPath], current: this.data.posterPath });
  },

  back() { wx.navigateBack({ delta: 1 }); },

  onShareAppMessage() {
    return {
      title: `演象时空罗盘 · ${this.data.sit}山${this.data.face}向`,
      path: `/pages/poster/index?sit=${this.data.sit}`,
      imageUrl: this.data.posterPath || ''
    };
  },

  /** 朋友圈分享：与好友分享区分，朋友圈侧只带标题与页面路径 */
  onShareTimeline() {
    return { title: '分享海报 · 盘面海报一图存相证' };
  },
});
