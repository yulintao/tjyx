/**
 * heading-state.js
 * 统一罗盘朝向状态解析，1:1 组合自 iOS Mountain24Data.resolveHeadingState
 * 与 CompassHeadingState（kongWangLevel / isLevel / fenJinDesc）。
 * 输入一次 heading（+可选 pitch/roll/trueHeading），输出完整状态对象，
 * 供罗盘 / AR / 盘解共用，避免各处重复拼装碎片。
 */

const SF = require('./sitface');
const KW = require('./kongwang');
const CF = require('./compass-filter');

/** 距最近山中心的角度与最近山（山中心 15°·k，子=0°） */
function mountainFor(angle) {
  const a = CF.normalize(angle);
  const idx = Math.round(a / 15) % 24;
  const name = SF.MOUNTAINS_24[idx];
  let diff = a - (idx * 15);
  if (diff > 180) diff -= 360;
  if (diff < -180) diff += 360;
  return { idx, name, center: idx * 15, diff, face: name, sit: SF.opposite(name) };
}

/**
 * iOS Mountain24Data.resolveHeadingState(heading:pitch:roll:trueHeading:)
 * @returns {heading,trueHeading,sittingAngle,facingAngle,facingMountain,sittingMountain,
 *           isJianXiang,jianXiangDegree,fenJinDesc,pitch,roll,isLevel,kongWangLevel,kongWangText}
 */
function resolveHeadingState(heading, options) {
  const o = options || {};
  const norm = CF.normalize(heading);
  const facingAngle = norm;
  const sittingAngle = (norm + 180) % 360;
  const facingM = mountainFor(facingAngle);
  const sittingM = mountainFor(sittingAngle);
  const jianDeg = Math.abs(facingM.diff);
  // iOS resolveHeadingState 兼向阈值 >3°（下卦正向）；空亡等级另走 kongWangLevel 的 1.5/6.5 口径
  const isJian = jianDeg > 3.0;
  const neighborAngle = facingM.diff > 0 ? facingM.center + 15 : facingM.center - 15;
  const neighborM = mountainFor(neighborAngle);
  const degStr = jianDeg.toFixed(1);
  const fenJinDesc = isJian
    ? `坐${sittingM.name}向${facingM.name} 兼${neighborM.name} (偏${degStr}°)`
    : `坐${sittingM.name}向${facingM.name} 正针下卦`;
  const pitch = Number(o.pitch) || 0;
  const roll = Number(o.roll) || 0;
  const kw = KW.classify(facingAngle);
  const trueHeading = o.trueHeading === undefined || o.trueHeading === null
    ? norm : CF.normalize(o.trueHeading);

  return {
    heading: norm,
    trueHeading,
    sittingAngle,
    facingAngle,
    facingMountain: facingM.name,
    sittingMountain: sittingM.name,
    isJianXiang: isJian,
    jianXiangDegree: jianDeg,
    fenJinDesc,
    pitch,
    roll,
    isLevel: CF.isLevel(pitch, roll),
    kongWangLevel: kw.type,
    kongWangText: kw.text
  };
}

module.exports = { mountainFor, resolveHeadingState };
