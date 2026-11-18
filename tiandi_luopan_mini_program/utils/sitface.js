/**
 * sitface.js
 * 坐向工具：二十四山、对宫向首、坐山所属卦、朝向角换算
 */

const MOUNTAINS_24 = ['子', '癸', '丑', '艮', '寅', '甲', '卯', '乙', '辰', '巽', '巳', '丙', '午', '丁', '未', '坤', '申', '庚', '酉', '辛', '戌', '乾', '亥', '壬'];

const PALACE_OF_MOUNTAIN = {
  子: 1, 癸: 1, 壬: 1,
  丑: 8, 艮: 8, 寅: 8,
  甲: 3, 卯: 3, 乙: 3,
  辰: 4, 巽: 4, 巳: 4,
  丙: 9, 午: 9, 丁: 9,
  未: 2, 坤: 2, 申: 2,
  庚: 7, 酉: 7, 辛: 7,
  戌: 6, 乾: 6, 亥: 6
};

const GUA_OF_PALACE = { 1: '坎', 2: '坤', 3: '震', 4: '巽', 6: '乾', 7: '兑', 8: '艮', 9: '离' };

function palaceNum(sitMountain) {
  return PALACE_OF_MOUNTAIN[sitMountain] || 1;
}

function houseGuaName(sitMountain) {
  return GUA_OF_PALACE[palaceNum(sitMountain)] || '坎';
}

function opposite(mountain) {
  const idx = MOUNTAINS_24.indexOf(mountain);
  if (idx < 0) return '午';
  return MOUNTAINS_24[(idx + 12) % 24];
}

/** 二十四山中心角（0=正北） */
function azimuthOf(mountain) {
  const idx = MOUNTAINS_24.indexOf(mountain);
  return idx < 0 ? 0 : (idx * 15) % 360;
}

/** 从罗盘朝角取坐向 */
function fromHeading(heading) {
  const { getSitAndFaceDiagnosis } = require('./fengshui');
  const d = getSitAndFaceDiagnosis(heading);
  return { sit: d.sitMt, face: d.faceMt, statusText: d.statusText, statusType: d.statusType, dev: d.dev };
}

/**
 * 坐向精细诊断（1:1 对齐 iOS Mountain24.kongWangLevel）
 * 距山中心 <1.5° 正针纯清；1.5°–6.5° 兼向；≥6.5° 为小空亡，
 * 其中距出卦线(22.5°+45k)≤0.7° 为出卦大空亡。
 */
function diagnoseHeading(heading) {
  const h = ((Number(heading) % 360) + 360) % 360;
  const find = (deg) => {
    const norm = (deg + 7.5) % 360;
    const idx = Math.floor(norm / 15) % 24;
    const center = (idx * 15) % 360;
    let diff = ((deg - center + 540) % 360) - 180;
    return { idx, mountain: MOUNTAINS_24[idx], center, diff };
  };
  const faceRes = find(h);
  const sitRes = find((h + 180) % 360);
  const absDev = Math.abs(faceRes.diff);
  const neighborIdx = faceRes.diff > 0 ? (faceRes.idx + 1) % 24 : (faceRes.idx - 1 + 24) % 24;
  const neighbor = MOUNTAINS_24[neighborIdx];

  // 统一走 iOS kongWangLevel 判级（1.5°/6.5°/出卦线0.7°）
  const KW = require('./kongwang');
  const kw = KW.classify(h);
  const type = kw.type;
  const needTiGua = type === 'jian';
  let text = '';
  if (type === 'pure') {
    text = absDev < 0.3 ? '正针纯清（正中线）' : `正针纯清（偏${faceRes.diff > 0 ? '右' : '左'}${absDev.toFixed(1)}°）`;
  } else if (type === 'jian') {
    text = `兼向（${faceRes.mountain}兼${neighbor} ${absDev.toFixed(1)}°）· 须起替卦`;
  } else if (type === 'big_kw') {
    text = `出卦大空亡（距出卦缝 ${kw.gapChuGua.toFixed(1)}°），此向不可用，须避开`;
  } else {
    text = `差错小空亡（距山中心 ${absDev.toFixed(1)}°），主气杂，宜微调向首`;
  }

  return {
    heading: h,
    face: faceRes.mountain,
    sit: sitRes.mountain,
    faceIdx: faceRes.idx,
    sitIdx: sitRes.idx,
    neighbor,
    dev: faceRes.diff,
    absDev,
    type,
    text,
    needTiGua,
    patternText: `坐${sitRes.mountain}向${faceRes.mountain}${type === 'pure' ? ' · 正针' : type === 'jian' ? ` 兼 ${neighbor}` : ' · 空亡'}`
  };
}

module.exports = {
  MOUNTAINS_24,
  PALACE_OF_MOUNTAIN,
  GUA_OF_PALACE,
  palaceNum,
  houseGuaName,
  opposite,
  azimuthOf,
  fromHeading,
  diagnoseHeading
};
