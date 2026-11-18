/**
 * mountain-ribbon.js
 * AR 水平罗盘刻度带：把二十四山按「当前朝向居中」展开到一条横向带上。
 * 纯函数，便于单测；页面只负责把结果塞进 cover-view。
 */

const MOUNTAIN_24 = ['子', '癸', '丑', '艮', '寅', '甲', '卯', '乙', '辰', '巽', '巳', '丙', '午', '丁', '未', '坤', '申', '庚', '酉', '辛', '戌', '乾', '亥', '壬'];
const HALF_SPAN = 60; // 左右各展开 60°，共 120°
const STEP = 15;

function norm(deg) {
  return ((deg % 360) + 360) % 360;
}

/** 方位角 → 二十四山名 */
function mountainAt(angle) {
  const idx = Math.round(norm(angle) / STEP) % 24;
  return MOUNTAIN_24[idx];
}

/**
 * 生成刻度带
 * @param {number} heading 当前朝向（0 = 正北，顺时针）
 * @returns {Array<{key:string,label:string,left:number,active:boolean,tick:boolean}>}
 */
function ribbonOf(heading) {
  const h = norm(Number(heading) || 0);
  const items = [];
  const kMax = HALF_SPAN / STEP;

  for (let k = -kMax; k <= kMax; k++) {
    const angle = norm(h + k * STEP);
    const left = 50 + (k / kMax) * 50;
    items.push({
      key: `m${k}`,
      label: mountainAt(angle),
      left: Math.max(0, Math.min(100, left)),
      active: k === 0,
      tick: false,
      angle: Math.round(angle * 10) / 10
    });
    // 相邻两山之间的中点细刻度
    if (k < kMax) {
      const mid = 50 + ((k + 0.5) / kMax) * 50;
      items.push({
        key: `t${k}`,
        label: '',
        left: Math.max(0, Math.min(100, mid)),
        active: false,
        tick: true,
        angle: Math.round(norm(h + (k + 0.5) * STEP) * 10) / 10
      });
    }
  }

  // 超出画面的项丢掉，减少 cover-view 数量
  return items.filter((i) => i.left >= -2 && i.left <= 102);
}

module.exports = { MOUNTAIN_24, HALF_SPAN, mountainAt, ribbonOf };
