/**
 * haptic.js
 * 触觉反馈，对齐 iOS CompassMotionManager 的 UIImpactFeedbackGenerator：
 *   tick  — 过山/罗盘刻度（light）
 *   level — 进入水平（medium）
 * 小程序无强反馈粒度，用 wx.vibrateShort 实现；受「触觉反馈」设置开关控制。
 */

const store = require('./store');

function enabled() {
  try {
    const s = store.getSettings() || {};
    return s.haptic !== false; // 默认开
  } catch (e) { return true; }
}

function fire(type) {
  if (!enabled()) return;
  try {
    wx.vibrateShort({ type: type === 'level' ? 'medium' : 'light' });
  } catch (e) {}
}

module.exports = { enabled, fire };
