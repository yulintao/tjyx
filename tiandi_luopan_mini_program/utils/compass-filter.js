/**
 * compass-filter.js
 * 罗盘传感器融合滤波，1:1 移植自 iOS CompassMotionManager.swift：
 *   - shortestAngleDelta：最短角差（跨 0/360 不跳变）
 *   - adaptiveAlpha：分段自适应响应（>3° 0.95 / >1° 0.75 / >0.3° 0.50 / 其余 0.35）
 *   - HeadingSmoothFilter：真北针与磁北针各自独立的连续角 + 0.05s 发布门限
 *   - isLevel：俯仰/横滚合角 < 2° 判定水平（iOS isLevel）
 *   - magneticDistortion：磁通量强度与本地基准的偏离判定（iOS didUpdateMagneticField）
 *
 * 小程序 wx.onCompassChange 不开放原始磁通量，magneticDistortion 走可选的 strengthUT 入参；
 * 无该入参时返回 false，由页面既有的「静止+跳变」等效判据兜底。
 */

/** iOS CompassMotionManager.shortestAngleDelta(from:to:) */
function shortestAngleDelta(from, to) {
  let delta = Number(to) - Number(from);
  while (delta > 180) delta -= 360;
  while (delta < -180) delta += 360;
  return delta;
}

/** iOS updateContinuousHeading 的 alpha 分段 */
function adaptiveAlpha(absDelta) {
  const d = Math.abs(absDelta);
  if (d > 3.0) return 0.95;
  if (d > 1.0) return 0.75;
  if (d > 0.3) return 0.50;
  return 0.35;
}

function normalize(deg) {
  return ((Number(deg) % 360) + 360) % 360;
}

/** 单针连续平滑器（真北 / 磁北各一个实例，互不干扰） */
function createNeedle(nowFn) {
  const now = typeof nowFn === 'function' ? nowFn : () => Date.now() / 1000;
  let filtered = null;
  let publishedAt = -Infinity;
  return {
    get value() { return filtered; },
    /** iOS updateContinuousHeading：每样本更新内部值，按 0.05s 门限对外发布 */
    push(newHeading) {
      if (filtered === null) {
        filtered = Number(newHeading);
        publishedAt = now();
        return { value: normalize(filtered), published: true };
      }
      const delta = shortestAngleDelta(filtered, newHeading);
      filtered += delta * adaptiveAlpha(delta);
      const t = now();
      if (t - publishedAt < 0.05) return { value: normalize(filtered), published: false };
      publishedAt = t;
      return { value: normalize(filtered), published: true };
    },
    reset() { filtered = null; publishedAt = -Infinity; }
  };
}

/** iOS CompassHeadingState.isLevel：俯仰/横滚合角 < 2° */
function isLevel(pitch, roll) {
  const p = Number(pitch) || 0;
  const r = Number(roll) || 0;
  return Math.sqrt(p * p + r * r) < 2.0;
}

/** iOS didUpdateMagneticField：强度偏离本地基准视为畸变 */
function magneticDistortion(strengthUT, baselineUT, thresholdUT) {
  if (!isFinite(strengthUT) || !isFinite(baselineUT)) return false;
  const th = isFinite(thresholdUT) ? thresholdUT : 12;
  return Math.abs(strengthUT - baselineUT) > th;
}

/** iOS CompassMotionManager.physicalHeading(at:)：3s 时效物理朝向，手选坐山不得替代 */
function physicalHeading(liveSensorHeading, liveHeadingDate, at) {
  const h = Number(liveSensorHeading);
  if (!isFinite(h) || !liveHeadingDate) return null;
  const now = at === undefined ? Date.now() : new Date(at).getTime();
  const t = new Date(liveHeadingDate).getTime();
  if (Math.abs(now - t) > 3000) return null;
  return normalize(h);
}

/** iOS CompassMotionManager.physicalCameraElevation(front:at:)：asin(重力Z) 相机仰角 */
function physicalCameraElevation(cameraGravityZ, cameraAttitudeDate, front, at) {
  const gz = Number(cameraGravityZ);
  if (!isFinite(gz) || !cameraAttitudeDate) return null;
  const now = at === undefined ? Date.now() : new Date(at).getTime();
  const t = new Date(cameraAttitudeDate).getTime();
  if (Math.abs(now - t) > 3000) return null;
  const v = Math.max(-1, Math.min(1, front ? -gz : gz));
  return Math.asin(v) * 180 / Math.PI;
}

module.exports = {
  shortestAngleDelta,
  adaptiveAlpha,
  createNeedle,
  isLevel,
  magneticDistortion,
  physicalHeading,
  physicalCameraElevation,
  normalize
};
