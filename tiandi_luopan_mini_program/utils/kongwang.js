/**
 * kongwang.js
 * 空亡 / 兼向判级 — 1:1 移植自 iOS Models/Mountain24.swift 的
 * CompassHeadingState.kongWangLevel（判级口径与 KongWangDetailSheet 一致）。
 *
 * iOS 口径（距山中心 delta，山中心每 15°，山边界 = center ± 7.5°）：
 *   大空亡(出卦)  delta ≥ 6.5° 且距出卦线(22.5° + 45°·k) ≤ 0.7°
 *   小空亡(差错)  delta ≥ 6.5°（但不贴出卦线）
 *   兼向          delta ∈ [1.5°, 6.5°)
 *   正针纯清      delta < 1.5°
 */

const TYPES = {
  pure: { key: 'pure', badgeClass: 'pure', text: '正针纯清' },
  jian: { key: 'jian', badgeClass: 'jian', text: '兼向（替卦）' },
  small_kw: { key: 'small_kw', badgeClass: 'small_kw', text: '差错小空亡' },
  big_kw: { key: 'big_kw', badgeClass: 'big_kw', text: '出卦大空亡' }
};

function normalize(deg) {
  return ((Number(deg) || 0) % 360 + 360) % 360;
}

/** 距最近山中心的角度（0 ~ 7.5），山中心为 15°·k（子=0°） */
function deltaToCenter(angle) {
  const a = normalize(angle);
  const center = Math.round(a / 15) * 15 % 360;
  let d = Math.abs(a - center);
  if (d > 180) d = 360 - d;
  return d;
}

/** 距最近出卦线（22.5° + 45°·k，共 8 条）的角度 */
function gapToChuGua(angle) {
  const a = normalize(angle);
  let min = 180;
  for (let k = 0; k < 8; k++) {
    const line = 22.5 + 45 * k;
    let d = Math.abs(a - line);
    if (d > 180) d = 360 - d;
    if (d < min) min = d;
  }
  return min;
}

/**
 * 判级主函数
 * @param {number} facingAngle 向首方位角（0°=正北，顺时针）
 * @returns {{type,badgeClass,text,delta,gapChuGua}}
 */
function classify(facingAngle) {
  const delta = deltaToCenter(facingAngle);
  let type;
  if (delta >= 6.5) {
    type = gapToChuGua(facingAngle) <= 0.7 ? 'big_kw' : 'small_kw';
  } else if (delta >= 1.5) {
    type = 'jian';
  } else {
    type = 'pure';
  }
  const t = TYPES[type];
  return {
    type,
    badgeClass: t.badgeClass,
    text: t.text,
    delta,
    gapChuGua: gapToChuGua(facingAngle)
  };
}

const MOUNTAINS_24 = ['子', '癸', '丑', '艮', '寅', '甲', '卯', '乙', '辰', '巽', '巳', '丙', '午', '丁', '未', '坤', '申', '庚', '酉', '辛', '戌', '乾', '亥', '壬'];

/** 最近山中心与山名（山中心每 15°，子=0°） */
function mountainAt(angle) {
  const a = normalize(angle);
  const idx = Math.round(a / 15) % 24;
  return { mountain: MOUNTAINS_24[idx], index: idx, center: idx * 15 % 360 };
}

/**
 * 逐度解释：判级 + 人话解释 + 可执行调整建议
 * 平台无关、纯算法，供分金页/罗盘弹层共用。
 */
function reading(angle) {
  const a = normalize(angle);
  const c = classify(a);
  const m = mountainAt(a);
  const off = (() => {
    let d = a - m.center;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  })();
  const abs = Math.abs(off);

  let explain;
  let advice;
  if (c.type === 'pure') {
    explain = `${m.mountain}山正针，偏差仅 ${abs.toFixed(1)}°，气纯不杂。`;
    advice = '可直接立向。';
  } else if (c.type === 'jian') {
    const toward = MOUNTAINS_24[off > 0 ? (m.index + 1) % 24 : (m.index + 23) % 24];
    explain = `${m.mountain}山兼${toward}，偏向 ${abs.toFixed(1)}°，属兼向，玄空需起替卦。`;
    advice = `按替卦立向；不愿替卦则回正至 ${m.center}°。`;
  } else if (c.type === 'small_kw') {
    explain = `${m.mountain}山与邻山交界，偏差 ${abs.toFixed(1)}°，气杂而不聚，为差错小空亡。`;
    advice = `避开山界，回到 ${m.center}° 附近（±1.5° 内），或改取邻山正针。`;
  } else {
    explain = `贴近出卦线（距 ${c.gapChuGua.toFixed(1)}°），偏差 ${abs.toFixed(1)}°，为出卦大空亡。`;
    advice = `必须离开出卦线，取 ${m.center}° 正针；此度不可立向。`;
  }

  return {
    angle: a,
    type: c.type,
    badgeClass: c.badgeClass,
    text: c.text,
    delta: Math.round(c.delta * 10) / 10,
    gapChuGua: Math.round(c.gapChuGua * 10) / 10,
    mountain: m.mountain,
    center: m.center,
    offset: Math.round(abs * 10) / 10,
    adjustTo: c.type === 'pure' ? a : m.center,
    explain,
    advice
  };
}

module.exports = { TYPES, normalize, deltaToCenter, gapToChuGua, classify, mountainAt, reading };
