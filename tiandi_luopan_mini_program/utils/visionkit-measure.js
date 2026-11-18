/**
 * visionkit-measure.js
 * 微信小程序 VisionKit 实景测距封装（对标 iOS ARKit 的平面检测 + 射线测距）。
 *
 * 能力边界（依据微信官方文档）：
 *   - v1：广机型，水平面放置，不提供真实世界距离；
 *   - v2：提供真实物理距离 + 平面识别 + SLAM；iOS 基础库 2.22+，
 *        安卓 2.25.1+ 仅支持 v2 水平面（无竖直平面）。
 *   - VKSession 需要 WebGL 上下文，且页面单例、与 camera 组件生命周期强相关。
 *
 * 因此本模块采用「探测 → 可用则测距 → 不可用自动降级」策略：
 * 不支持的机型/基础库直接 isSupported()=false，AR 页沿用靶心测角，不阻塞主流程。
 */

function compareVersion(a, b) {
  const pa = String(a || '0').split('.').map((n) => parseInt(n, 10) || 0);
  const pb = String(b || '0').split('.').map((n) => parseInt(n, 10) || 0);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] || 0) - (pb[i] || 0);
    if (d !== 0) return d;
  }
  return 0;
}

/** 运行时探测：返回 { supported, version, reason, platform } */
function detect() {
  if (typeof wx === 'undefined' || typeof wx.createVKSession !== 'function') {
    return { supported: false, version: null, reason: '基础库不支持 wx.createVKSession', platform: 'unknown' };
  }
  let sdk = '0';
  let platform = 'unknown';
  try {
    const info = wx.getSystemInfoSync ? wx.getSystemInfoSync() : {};
    sdk = info.SDKVersion || '0';
    platform = info.platform || 'unknown';
  } catch (e) {}
  const isAndroid = platform === 'android' || platform === 'ohos';
  // 官方口径：iOS v2 需基础库 2.22+；安卓 v2 需 2.25.1+，且不支持竖直平面。
  const minV2 = isAndroid ? '2.25.1' : '2.22.0';
  let version = null;
  let reason = '';
  if (compareVersion(sdk, minV2) >= 0) {
    version = 'v2';
    reason = isAndroid ? 'v2 水平面测距（安卓不支持竖直平面）' : 'v2 平面识别 + 真实测距';
  } else if (compareVersion(sdk, '2.20.0') >= 0) {
    version = 'v1';
    reason = 'v1 无真实世界距离，降级为靶心测角';
  } else {
    reason = '基础库版本过低';
  }
  return {
    supported: version === 'v2',
    version,
    reason,
    platform,
    sdk,
    verticalPlane: !isAndroid
  };
}

/**
 * 创建测距会话。gl 必须由调用方从 WebGL canvas 取得（VisionKit 依赖 WebGL）。
 * 返回 null 表示当前设备不可用，调用方应走降级路径。
 */
function createMeasureSession(gl, options) {
  const info = detect();
  if (!info.supported || !gl) return null;
  const opts = options || {};
  let session;
  try {
    session = wx.createVKSession({
      track: { plane: { mode: opts.planeMode || 3 } },
      version: 'v2',
      gl
    });
  } catch (e) {
    return null;
  }

  let anchors = [];
  let startMark = null;
  let endMark = null;

  session.on('updateAnchors', (anchorsData) => {
    anchors = anchorsData && anchorsData.anchors ? anchorsData.anchors : [];
  });

  return {
    info,
    session,
    start(callback) {
      try { session.start(callback); } catch (e) { if (typeof callback === 'function') callback(e); }
    },
    stop() { try { session.stop(); } catch (e) {} },
    destroy() { try { session.destroy(); } catch (e) {} },

    /** 取最近一个平面锚点；iOS v2 世界坐标为米，可据此读实际尺寸 */
    nearestPlane() {
      if (!anchors.length) return null;
      const planes = anchors.filter((a) => a.plane || a.type === 'plane');
      if (!planes.length) return null;
      const p = planes[0];
      const pos = p.position || (p.transform && p.transform.position) || { x: 0, y: 0, z: 0 };
      return {
        position: { x: pos.x, y: pos.y, z: pos.z },
        width: Number(p.width || p.planeWidth || 0),
        height: Number(p.height || p.planeHeight || 0)
      };
    },

    markStart() { startMark = this.nearestPlane(); return startMark; },
    markEnd() { endMark = this.nearestPlane(); return endMark; },

    /** 两次落点的真实距离（米）；任一落点缺失返回 null */
    measuredDistance() {
      if (!startMark || !endMark) return null;
      const a = startMark.position;
      const b = endMark.position;
      const dx = a.x - b.x;
      const dy = a.y - b.y;
      const dz = a.z - b.z;
      return Math.sqrt(dx * dx + dy * dy + dz * dz);
    },

    get anchors() { return anchors; }
  };
}

module.exports = { detect, createMeasureSession, compareVersion };
