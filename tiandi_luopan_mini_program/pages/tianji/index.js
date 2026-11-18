const TJ = require('../../utils/tianji');
const SF = require('../../utils/sitface');
const SP = require('../../utils/scroll-painter');

Page({
  data: {
    sitIdx: 0,
    sit: '子',
    face: '午',
    mountainNames: SF.MOUNTAINS_24.map((m) => `${m} 山`),
    title: '',
    dateText: '',
    sections: [],
    digest: [],
    guidance: '',
    score: 0,
    grade: '',
    risks: [],
    exporting: false,
    highCount: 0,
    showRisks: false,
    showScroll: false
  },

  toggleRisks() { this.setData({ showRisks: !this.data.showRisks }); },
  toggleScroll() { this.setData({ showScroll: !this.data.showScroll }); },

  onLoad(options) {
    let sit = '子';
    if (options && options.sit && SF.MOUNTAINS_24.indexOf(options.sit) >= 0) sit = options.sit;
    this.setData({ sitIdx: SF.MOUNTAINS_24.indexOf(sit) });
    this.recompute();
  },

  onSitChange(e) {
    this.setData({ sitIdx: parseInt(e.detail.value, 10) });
    this.recompute();
  },

  recompute() {
    const sit = SF.MOUNTAINS_24[this.data.sitIdx];
    const face = SF.opposite(sit);
    const scroll = TJ.buildScroll({ sitMountain: sit, faceMountain: face, date: new Date() });
    const deep = TJ.deepAnalysis(scroll);
    this.setData({
      sit,
      face,
      title: scroll.title,
      dateText: scroll.dateText,
      sections: scroll.sections,
      digest: scroll.digest,
      guidance: scroll.guidance || '',
      score: deep.score,
      grade: deep.grade,
      risks: deep.risks.slice(0, 6),
      highCount: (deep.risks || []).filter((r) => r.level === 'high').length
    });
    this._scroll = scroll;
    this._deep = deep;
  },

  copyText() {
    const s = this._scroll;
    if (!s) return;
    const d = this._deep || {};
    const head = [s.title, s.dateText, '', `总评：${d.grade || ''}（${d.score || 0} 分）`, s.guidance || '', ''];
    const text = head
      .concat(s.sections.map((sec) => `${sec.title}\n${sec.rows.join('\n')}`))
      .join('\n');
    wx.setClipboardData({ data: text });
  },

  exportImage() {
    const s = this._scroll;
    if (!s || this.data.exporting) return;
    this.setData({ exporting: true });

    const d = this._deep || {};
    const payload = {
      title: s.title,
      dateText: s.dateText,
      grade: d.grade,
      score: d.score,
      guidance: s.guidance || '',
      sections: s.sections
    };

    const pg = SP.paginate(payload);
    const dpr = Math.min(2.5, (wx.getSystemInfoSync().pixelRatio || 2));

    const query = wx.createSelectorQuery();
    query.select('#reportCanvas').fields({ node: true, size: true }).exec((res) => {
      const canvas = res && res[0] && res[0].node;
      if (!canvas) {
        this.setData({ exporting: false });
        this.copyText();
        return;
      }

      const paths = [];
      const renderPage = (i) => {
        if (i >= pg.pages.length) {
          this.setData({ exporting: false });
          this.finishExport(paths);
          return;
        }
        try {
          const page = pg.pages[i];
          const W = pg.W;
          canvas.width = Math.round(W * dpr);
          canvas.height = Math.round(page.H * dpr);
          const ctx = canvas.getContext('2d');
          ctx.setTransform(1, 0, 0, 1, 0, 0);
          ctx.scale(dpr, dpr);
          SP.paint(ctx, page, {
            W,
            pageCount: pg.pages.length,
            title: payload.title,
            dateText: payload.dateText,
            grade: payload.grade,
            score: payload.score
          });
          wx.canvasToTempFilePath({
            canvas,
            success: (r) => {
              paths.push(r.tempFilePath);
              renderPage(i + 1);
            },
            fail: () => {
              this.setData({ exporting: false });
              this.copyText();
            }
          });
        } catch (err) {
          this.setData({ exporting: false });
          this.copyText();
        }
      };
      renderPage(0);
    });
  },

  /** 单页直接入相册；多页走预览，长按可逐张保存（避免反复弹权限） */
  finishExport(paths) {
    if (!paths.length) {
      this.copyText();
      return;
    }
    if (paths.length === 1) {
      wx.saveImageToPhotosAlbum({
        filePath: paths[0],
        success: () => wx.showToast({ title: '已保存到相册', icon: 'success' }),
        fail: () => wx.previewImage({ urls: paths })
      });
      return;
    }
    wx.showToast({ title: `已导出 ${paths.length} 张`, icon: 'none' });
    wx.previewImage({ urls: paths, current: paths[0] });
  },

  back() { wx.navigateBack({ fail: () => wx.reLaunch({ url: '../index/index' }) }); }
,

  onShareAppMessage() {
    return { title: '演象时空罗盘 · 天机长卷', path: '/pages/tianji/index' };
  },

  /** 朋友圈分享：与好友分享区分，朋友圈侧只带标题与页面路径 */
  onShareTimeline() {
    return { title: '天机长卷 · 全盘汇总一图导出' };
  }
});
