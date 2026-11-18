const RC = require('../../utils/reportcard');
const FP = require('../../utils/floorplan');
const store = require('../../utils/store');
const G = require('../../utils/geom');

Page({
  data: {
    title: '',
    subtitle: '',
    score: 0,
    baseDims: [],
    geomDims: [],
    corners: [],
    xiong: [],
    footer: '',
    canvasH: 1334,
    cardPath: '',
    saved: false,
    hasPlan: false,
    planLabel: ''
  },

  onLoad() {
    // 1. 优先取户型页刚写入的报告草稿 → 2. 最近一次存档 → 3. 示例户型
    let plan = null;
    try {
      plan = store.read('yj_report_draft', null);
    } catch (e) {
      plan = null;
    }
    if (!plan || !plan.rooms || !plan.rooms.length) {
      const list = store.getFloorplans() || [];
      plan = list[0] || null;
    }
    const fallback = !plan;
    if (fallback) {
      plan = {
        label: '示例户型（未录入户型时的演示数据）',
        sit: '子',
        face: '午',
        widthMeters: '10',
        rooms: FP.sampleRooms()
      };
    }

    this.plan = plan;
    const payload = RC.build(plan, {});
    this.payload = payload;

    const corners = payload.corners.map((c) => ({
      title: c.title,
      hurt: c.hurt.join(''),
      remedy: c.remedy.join('')
    }));
    const xiong = payload.xiong.map((lines) => lines.join(''));

    // iOS GeometryUtils 精确几何指标：逐房间面积/重心 + 全宅主轴角，
    // 与 reportcard 的概览 dims 并列展示，避免覆盖原有口径。
    const geomDims = [];
    const rooms = plan.rooms || [];
    rooms.forEach((room) => {
      const pts = (room.points || room.corners || []).map((p) => ({ x: Number(p.x), y: Number(p.y) }));
      if (pts.length < 3) return;
      const area = G.polygonArea(pts);
      const c = G.polygonCentroid(pts);
      geomDims.push(`${room.name || '房间'}：面积 ${area.toFixed(1)}（归一化²）· 形心 (${c.x.toFixed(1)}, ${c.y.toFixed(1)})`);
    });
    const outer = rooms.reduce((acc, r) => acc.concat((r.points || r.corners || []).map((p) => ({ x: Number(p.x), y: Number(p.y) }))), []);
    if (outer.length >= 3) {
      geomDims.push(`全宅主轴角：${G.primaryAxisAngle(G.convexHull(outer)).toFixed(1)}°`);
    }
    const baseDims = (payload.dims || []).slice();

    this.setData({
      title: payload.title,
      subtitle: payload.subtitle,
      score: payload.metrics.score,
      baseDims,
      geomDims,
      corners,
      xiong,
      footer: payload.footer.join(''),
      canvasH: payload.height,
      hasPlan: !fallback,
      planLabel: plan.label || ''
    });

    setTimeout(() => this.draw(), 120);
  },

  draw() {
    const q = wx.createSelectorQuery().in(this);
    q.select('#reportCanvas').fields({ node: true, size: true }).exec((res) => {
      const item = res && res[0];
      if (!item || !item.node) return;
      const canvas = item.node;
      const ctx = canvas.getContext('2d');
      const W = RC.W;
      const H = this.payload ? this.payload.height : 1334;
      const scale = 2;
      canvas.width = W * scale;
      canvas.height = H * scale;
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.scale(scale, scale);
      ctx.clearRect(0, 0, W, H);
      RC.draw(ctx, W, H, this.payload);
      wx.canvasToTempFilePath({
        canvas,
        x: 0,
        y: 0,
        width: W * scale,
        height: H * scale,
        destWidth: W * scale,
        destHeight: H * scale,
        success: (r) => this.setData({ cardPath: r.tempFilePath }),
        fail: () => wx.showToast({ title: '报告图生成失败', icon: 'none' })
      });
    });
  },

  save() {
    if (!this.data.cardPath) {
      wx.showToast({ title: '报告尚未生成', icon: 'none' });
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
          content: '保存报告图到相册需要授权，请在设置中开启“保存到相册”。',
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

  copyText() {
    const text = RC.toText(this.payload);
    wx.setClipboardData({
      data: text,
      success: () => wx.showToast({ title: '报告全文已复制', icon: 'none' })
    });
  },

  goFloorplan() {
    wx.navigateBack({
      delta: 1,
      fail: () => wx.switchTab({ url: '/pages/floorplan/index' })
    });
  },

  back() {
    wx.navigateBack({
      delta: 1,
      fail: () => wx.switchTab({ url: '/pages/floorplan/index' })
    });
  },

  onShareAppMessage() {
    const p = this.payload || {};
    return {
      title: `${p.sit || ''}山${p.face || ''}向 · 空间得分 ${p.metrics ? p.metrics.score : ''} 分 · 全屋测绘存证`,
      path: '/pages/report/index',
      imageUrl: this.data.cardPath || ''
    };
  },

  onShareTimeline() {
    return { title: '全屋空间测绘报告 · 尺寸 / 缺角 / 凶宫化解' };
  }
});
