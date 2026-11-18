const SF = require('../../utils/sitface');
const FENJIN = require('../../utils/fenjin');
const VK = require('../../utils/visionkit-measure');
const SHA = require('../../utils/sha');
const HL = require('../../utils/heading-lock');

// 二十四山在盘面上的角度：子 = 0°，顺时针每山 15°
Page({
  data: {
    heading: 0,
    headingText: '0.0°',
    sitText: '坐子向午',
    fenjinText: '',
    shaText: '',
    shaRemedy: '',
    offset: 0,
    levelText: '水平待测',
    bubbleLeft: 50,
    bubbleTop: 50,
    snapPath: '',
    cameraReady: false,
    recording: false,
    statusBarHeight: 20,
    // VisionKit v2 实景测距：支持时显示入口，否则沿用靶心测角
    vkSupported: false,
    vkReason: '',
    vkMeasureText: '',
    vkMeasuring: false,
    // 点画面取方位：把屏幕横向位置换算成镜头偏角，出该方位的结论
    pick: null,
    pickLeft: 50,
    // 稳持锁定：镜头在 ±1.2° 内保持 1.5s 即锁定读数，避免近楼反光让数字一直跳
    locked: false,
    lockText: ''
  },

  onLoad() {
    this.offsetDeg = 0;
    this._lock = HL.create();
    const vkInfo = VK.detect();
    this.setData({ vkSupported: vkInfo.supported, vkReason: vkInfo.reason });
    // 相机是全屏 fixed 容器，自定义导航栏下需要自己避开状态栏/刘海，
    // 否则顶部的「返回」与读数会被状态栏压住、点不中。
    let sb = 20;
    try {
      const info = wx.getWindowInfo ? wx.getWindowInfo() : wx.getSystemInfoSync();
      if (info && typeof info.statusBarHeight === 'number') sb = info.statusBarHeight;
    } catch (e) {
      sb = 20;
    }
    this.setData({ statusBarHeight: sb });
    this.startSensors();
  },

  onUnload() {
    this.stopSensors();
    this.stopVKMeasure();
  },

  onHide() {
    this.stopSensors();
    this.stopVKMeasure();
  },

  onShow() {
    this.startSensors();
  },

  startSensors() {
    if (this._compassOn) return;
    this._compassOn = true;
    wx.onCompassChange((res) => {
      const heading = ((res.direction + this.offsetDeg) % 360 + 360) % 360;
      this._heading = heading;

      // ---- 稳持锁定（状态机在 utils/heading-lock.js） ----
      // 停住 1.5s 锁定读数；锁定后偏离 >12° 且持续 0.8s 自动解锁；手动解锁后需转动 >8° 才恢复
      const lockRes = HL.step(this._lock, heading, Date.now());
      this._lock = lockRes.state;
      if (lockRes.justLocked) {
        this.setData({ locked: true, lockText: heading.toFixed(1) + '°' });
        return;
      }
      if (lockRes.justUnlocked) {
        this.setData({ locked: false, lockText: '' });
      }
      if (this._lock.locked) return;

      const sit = SF.fromHeading(heading).sit;
      const face = SF.opposite(sit);
      const fj = FENJIN.resolve(heading);
      // 八宫方位主应形煞随镜头实时联动（iOS ARVisionView.resolvedShaIndex 口径）
      const sha = SHA.resolveShaByHeading(heading);
      this.setData({
        heading: Math.round(heading * 10) / 10,
        headingText: heading.toFixed(1) + '°',
        sitText: `坐${sit}向${face}`,
        fenjinText: `${fj.jiazi} 分金 · ${fj.grade}`,
        shaText: sha.name ? `${sha.dir}${sha.palace}宫 · ${sha.name}` : '',
        shaRemedy: sha.remedy || ''
      });
    });
    wx.onDeviceMotionChange((res) => {
      // beta: 前后俯仰，gamma: 左右倾斜；用于简易水平气泡
      const beta = res.beta || 0;
      const gamma = res.gamma || 0;
      const tilt = Math.max(Math.abs(beta - 90), Math.abs(gamma));
      const bubbleLeft = 50 + Math.max(-28, Math.min(28, gamma * 2));
      const bubbleTop = 50 + Math.max(-28, Math.min(28, (beta - 90) * 2));
      this.setData({
        levelText: tilt <= 1.5 ? '水平良好' : (tilt <= 4 ? '略有倾斜' : '倾斜较大，宜校平'),
        bubbleLeft,
        bubbleTop
      });
    });
  },

  stopSensors() {
    if (!this._compassOn) return;
    this._compassOn = false;
    if (wx.offCompassChange) wx.offCompassChange();
    if (wx.offDeviceMotionChange) wx.offDeviceMotionChange();
  },

  onCameraReady() {
    this.setData({ cameraReady: true });
  },

  /** 手动解锁：先压住自动锁定，等真正转头 >8° 再恢复 */
  onUnlockTap() {
    this._lock = HL.unlock(this._lock, this._heading || 0);
    this.setData({ locked: false, lockText: '' });
  },

  /** 点画面取方位：把屏幕横向位置换算成镜头偏角，出该方位的结论 */
  onPickTap(e) {
    let w = 375;
    try {
      const info = wx.getWindowInfo ? wx.getWindowInfo() : wx.getSystemInfoSync();
      if (info && info.windowWidth) w = info.windowWidth;
    } catch (err) { w = 375; }
    const detail = (e && e.detail) || {};
    // 点选时先解锁，读数回到实时；cover-view 的 tap 在部分机型不带坐标，退回靶心方位
    if (this.data.locked) this.onUnlockTap();
    const x = typeof detail.x === 'number' ? detail.x
      : (typeof detail.clientX === 'number' ? detail.clientX : w / 2);
    this.applyPick(((this._heading || 0) + ((x - w / 2) / w) * 62 + 360) % 360, (x / w) * 100);
  },

  /** 左右寻：不点屏幕也能按邻山步进（每次 7.5°） */
  onPickStep(e) {
    const dir = Number(e.currentTarget.dataset.dir) || 0;
    const base = this.data.pick ? this.data.pick.heading : (this._heading || 0);
    const next = ((base + dir * 7.5) % 360 + 360) % 360;
    this.applyPick(next, this.data.pick ? this.data.pick.left : 50);
  },

  clearPick() {
    this.setData({ pick: null });
  },

  /** 取该方位结论：山向 / 分金 / 八宫主应形煞 / 化解 */
  applyPick(pickedHeading, leftPct) {
    const h = ((pickedHeading % 360) + 360) % 360;
    const sit = SF.fromHeading(h).sit;
    const face = SF.opposite(sit);
    const fj = FENJIN.resolve(h);
    const sha = SHA.resolveShaByHeading(h);
    this.setData({
      pickLeft: Math.max(6, Math.min(94, leftPct)),
      pick: {
        heading: Math.round(h * 10) / 10,
        headingText: h.toFixed(1) + '°',
        sitFace: `坐${sit}向${face}`,
        mountain: sit,
        fenjin: `${fj.jiazi} · ${fj.grade}`,
        sha: sha.name ? `${sha.dir}${sha.palace}宫 · ${sha.name}` : '此方不犯主应形煞',
        remedy: sha.remedy || '',
        level: sha.name ? 'xiong' : 'ji',
        left: Math.max(6, Math.min(94, leftPct))
      }
    });
  },

  /**
   * VisionKit v2 实景测距：从 WebGL canvas 取 gl 建会话，
   * 两次落点取平面锚点的真实 3D 距离（米）。不支持的设备不会走到这里。
   */
  startVKMeasure() {
    if (!this.data.vkSupported) {
      wx.showToast({ title: this.data.vkReason || '当前设备不支持实景测距，请用靶心测角', icon: 'none' });
      return;
    }
    if (this._vkMeasure) {
      this.stopVKMeasure();
      return;
    }
    if (typeof wx.createOffscreenCanvas !== 'function') {
      wx.showToast({ title: '基础库不支持离屏 WebGL，请用靶心测角', icon: 'none' });
      return;
    }
    let gl = null;
    try {
      const canvas = wx.createOffscreenCanvas({ type: 'webgl', width: 1280, height: 720 });
      gl = canvas && canvas.getContext('webgl');
    } catch (e) {
      gl = null;
    }
    const session = VK.createMeasureSession(gl);
    if (!session) {
      wx.showToast({ title: '设备不支持 VisionKit v2 测距', icon: 'none' });
      return;
    }
    this._vkMeasure = session;
    this.setData({ vkMeasuring: true, vkMeasureText: '移动手机对准平面，点「起点」「终点」取距' });
    session.start((err) => {
      if (err) {
        wx.showToast({ title: '测距启动失败，请用靶心测角', icon: 'none' });
        this.stopVKMeasure();
      }
    });
  },

  vkMarkStart() {
    if (!this._vkMeasure) return this.startVKMeasure();
    const m = this._vkMeasure.markStart();
    this.setData({ vkMeasureText: m ? '起点已记录，再点「终点」' : '未识别到平面，请对准地面/桌面' });
  },

  vkMarkEnd() {
    if (!this._vkMeasure) return;
    this._vkMeasure.markEnd();
    const d = this._vkMeasure.measuredDistance();
    this.setData({ vkMeasureText: d === null
      ? '缺少落点，请重新取距'
      : `实测距离 ${d.toFixed(2)} 米（约 ${(d * 3).toFixed(2)} 尺）` });
  },

  stopVKMeasure() {
    if (!this._vkMeasure) return;
    this._vkMeasure.destroy();
    this._vkMeasure = null;
    this.setData({ vkMeasureText: '', vkMeasuring: false });
  },

  calibrate() {
    const h = this._heading || 0;
    const delta = (-h + 360) % 360;
    this.offsetDeg = delta;
    this.setData({ offset: Math.round(delta) });
    wx.showToast({ title: '已按当前朝向校北', icon: 'none' });
  },

  clearCalibrate() {
    this.offsetDeg = 0;
    this.setData({ offset: 0 });
  },

  takePhoto() {
    if (this.data.recording) return;
    this.setData({ recording: true });
    const ctx = wx.createCameraContext();
    ctx.takePhoto({
      quality: 'high',
      success: (res) => {
        this.drawSnap(res.tempImagePath);
      },
      fail: () => {
        this.setData({ recording: false });
        wx.showToast({ title: '拍照失败，请检查相机权限', icon: 'none' });
      }
    });
  },

  drawSnap(path) {
    const q = wx.createSelectorQuery().in(this);
    q.select('#snapCanvas').fields({ node: true, size: true }).exec((res) => {
      const item = res && res[0];
      if (!item || !item.node) {
        this.setData({ recording: false });
        return;
      }
      const canvas = item.node;
      const ctx = canvas.getContext('2d');
      const W = 1200;
      const H = 1600;
      canvas.width = W;
      canvas.height = H;

      const img = canvas.createImage();
      img.onload = () => {
        // 按比例铺满（cover 裁切）
        const scale = Math.max(W / img.width, H / img.height);
        const dw = img.width * scale;
        const dh = img.height * scale;
        ctx.drawImage(img, (W - dw) / 2, (H - dh) / 2, dw, dh);
        this.paintDial(ctx, W, H);
        wx.canvasToTempFilePath({
          canvas,
          x: 0,
          y: 0,
          width: W,
          height: H,
          destWidth: W,
          destHeight: H,
          success: (r) => this.setData({ snapPath: r.tempFilePath, recording: false }),
          fail: () => {
            this.setData({ recording: false });
            wx.showToast({ title: '合成失败', icon: 'none' });
          }
        });
      };
      img.onerror = () => {
        this.setData({ recording: false });
        wx.showToast({ title: '照片读取失败', icon: 'none' });
      };
      img.src = path;
    });
  },

  paintDial(ctx, W, H) {
    const heading = this._heading || 0;
    const cx = W / 2;
    const cy = H * 0.44;
    const R = W * 0.42;

    // 半透明底盘
    ctx.beginPath();
    ctx.arc(cx, cy, R * 1.12, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(10,13,20,0.34)';
    ctx.fill();

    // 外圈
    ctx.beginPath();
    ctx.arc(cx, cy, R, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(233,216,166,0.9)';
    ctx.lineWidth = 4;
    ctx.stroke();

    // 二十四山刻线与山名（盘面随朝向反向旋转）
    const MOUNTAINS = SF.MOUNTAINS_24;
    for (let i = 0; i < 24; i++) {
      const a = i * 15;
      const screen = ((a - heading) % 360 + 360) % 360;
      const rad = (screen * Math.PI) / 180;
      const x1 = cx + (R - 26) * Math.sin(rad);
      const y1 = cy - (R - 26) * Math.cos(rad);
      const x2 = cx + R * Math.sin(rad);
      const y2 = cy - R * Math.cos(rad);
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x2, y2);
      ctx.strokeStyle = 'rgba(233,216,166,0.55)';
      ctx.lineWidth = 2;
      ctx.stroke();

      const lx = cx + (R - 62) * Math.sin(rad);
      const ly = cy - (R - 62) * Math.cos(rad);
      ctx.fillStyle = i % 3 === 0 ? '#e9d8a6' : 'rgba(226,232,244,0.8)';
      ctx.font = '28px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(MOUNTAINS[i], lx, ly + 9);
    }

    // 每 5° 细刻度
    for (let d = 0; d < 360; d += 5) {
      const screen = ((d - heading) % 360 + 360) % 360;
      const rad = (screen * Math.PI) / 180;
      const r1 = R + 6;
      const r2 = d % 30 === 0 ? R + 22 : R + 14;
      ctx.beginPath();
      ctx.moveTo(cx + r1 * Math.sin(rad), cy - r1 * Math.cos(rad));
      ctx.lineTo(cx + r2 * Math.sin(rad), cy - r2 * Math.cos(rad));
      ctx.strokeStyle = d % 30 === 0 ? 'rgba(233,216,166,0.9)' : 'rgba(180,195,220,0.5)';
      ctx.lineWidth = d % 30 === 0 ? 3 : 1.5;
      ctx.stroke();
    }

    // 靶心十字
    ctx.strokeStyle = '#e9d8a6';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(cx - 46, cy);
    ctx.lineTo(cx + 46, cy);
    ctx.moveTo(cx, cy - 46);
    ctx.lineTo(cx, cy + 46);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(cx, cy, 16, 0, Math.PI * 2);
    ctx.stroke();

    // 读数
    const sit = SF.fromHeading(heading).sit;
    const face = SF.opposite(sit);
    const fj = FENJIN.resolve(heading);
    ctx.fillStyle = 'rgba(10,13,20,0.6)';
    ctx.fillRect(0, H - 300, W, 300);
    ctx.textAlign = 'left';
    ctx.fillStyle = '#e9d8a6';
    ctx.font = 'bold 52px sans-serif';
    ctx.fillText(`${heading.toFixed(1)}°  ${sit}山${face}向`, 56, H - 210);
    ctx.fillStyle = '#cfd8ea';
    ctx.font = '30px sans-serif';
    ctx.fillText(`分金 ${fj.jiazi} · ${fj.grade} · ${fj.nayin}`, 56, H - 150);
    ctx.fillStyle = '#8f9bb3';
    ctx.font = '26px sans-serif';
    const now = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    ctx.fillText(`演象时空罗盘 · ${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}`, 56, H - 96);
    if (this.offsetDeg) {
      ctx.fillText(`已校北 ${this.offsetDeg.toFixed(1)}°`, 56, H - 52);
    }
  },

  saveSnap() {
    if (!this.data.snapPath) return;
    wx.saveImageToPhotosAlbum({
      filePath: this.data.snapPath,
      success: () => wx.showToast({ title: '已存入相册', icon: 'success' }),
      fail: () => wx.showToast({ title: '保存失败，请允许相册权限', icon: 'none' })
    });
  },

  closeSnap() {
    this.setData({ snapPath: '' });
  },

  back() { wx.navigateBack({ delta: 1 }); },

  onShareAppMessage() {
    return { title: '演象时空罗盘 · 实景叠盘', path: '/pages/ar/index' };
  },

  /** 朋友圈分享：与好友分享区分，朋友圈侧只带标题与页面路径 */
  onShareTimeline() {
    return { title: '实景叠盘 · 相机取景与靶心测角' };
  },
});
