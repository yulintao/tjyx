/**
 * fenjin.js
 * 一百二十分金：二十四山 × 5 分金 = 120 位，含六十甲子、纳音、珠宝/火坑/孤虚/虚度分级与断语
 * 对齐 iOS Models/Fenjin120Data.swift 的分级口径（丙丁庚辛珠宝、戊己龟甲火坑、甲乙孤度、壬癸虚度）。
 */

const MOUNTAINS_24 = ['子', '癸', '丑', '艮', '寅', '甲', '卯', '乙', '辰', '巽', '巳', '丙', '午', '丁', '未', '坤', '申', '庚', '酉', '辛', '戌', '乾', '亥', '壬'];

// 六十甲子（阳干配阳支，阴干配阴支）
const STEMS = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
const BRANCHES = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];
const JIAZI_60 = (() => {
  const out = [];
  for (let i = 0; i < 60; i++) out.push(STEMS[i % 10] + BRANCHES[i % 12]);
  return out;
})();

// 六十甲子纳音（每两柱一组）
const NAYIN_PAIRS = [
  ['甲子', '乙丑', '海中金'], ['丙寅', '丁卯', '炉中火'], ['戊辰', '己巳', '大林木'],
  ['庚午', '辛未', '路旁土'], ['壬申', '癸酉', '剑锋金'], ['甲戌', '乙亥', '山头火'],
  ['丙子', '丁丑', '涧下水'], ['戊寅', '己卯', '城头土'], ['庚辰', '辛巳', '白蜡金'],
  ['壬午', '癸未', '杨柳木'], ['甲申', '乙酉', '泉中水'], ['丙戌', '丁亥', '屋上土'],
  ['戊子', '己丑', '霹雳火'], ['庚寅', '辛卯', '松柏木'], ['壬辰', '癸巳', '长流水'],
  ['甲午', '乙未', '砂中金'], ['丙申', '丁酉', '山下火'], ['戊戌', '己亥', '平地木'],
  ['庚子', '辛丑', '壁上土'], ['壬寅', '癸卯', '金箔金'], ['甲辰', '乙巳', '覆灯火'],
  ['丙午', '丁未', '天河水'], ['戊申', '己酉', '大驿土'], ['庚戌', '辛亥', '钗钏金'],
  ['壬子', '癸丑', '桑柘木'], ['甲寅', '乙卯', '大溪水'], ['丙辰', '丁巳', '沙中土'],
  ['戊午', '己未', '天上火'], ['庚申', '辛酉', '石榴木'], ['壬戌', '癸亥', '大海水']
];
const NAYIN = {};
NAYIN_PAIRS.forEach(([a, b, name]) => { NAYIN[a] = name; NAYIN[b] = name; });

const GRADE = {
  jewel: { key: 'jewel', name: '旺相珠宝', short: '珠宝', usable: true, desc: '丙丁庚辛为旺相之气，可用之度，主丁财两旺、事业顺遂。' },
  pit: { key: 'pit', name: '龟甲火坑', short: '火坑', usable: false, desc: '戊己属龟甲空亡，葬之主家道退败、疾病连绵，忌用。' },
  lonely: { key: 'lonely', name: '孤虚差错', short: '孤度', usable: false, desc: '甲属孤、乙属虚，主孤寡冷退，不宜立向。' },
  void: { key: 'void', name: '虚度空亡', short: '虚度', usable: false, desc: '壬癸属虚度，气不聚，主财散人离，忌用。' }
};

function gradeOf(stem) {
  if (stem === '丙' || stem === '丁' || stem === '庚' || stem === '辛') return GRADE.jewel;
  if (stem === '戊' || stem === '己') return GRADE.pit;
  if (stem === '甲' || stem === '乙') return GRADE.lonely;
  return GRADE.void;
}

/** 生成为 120 条分金表，索引 0 起于 352.5°（壬山末位） */
function buildTable() {
  const rows = [];
  for (let i = 0; i < 120; i++) {
    const start = (352.5 + i * 3) % 360;
    const end = (start + 3) % 360;
    const center = (start + 1.5) % 360;
    const jiazi = JIAZI_60[i % 60];
    const stem = jiazi[0];
    const grade = gradeOf(stem);
    // 该分金所属二十四山：以中心角定位
    const mountainIdx = Math.floor(((center + 7.5) % 360) / 15);
    const mountain = MOUNTAINS_24[mountainIdx];
    const nayin = NAYIN[jiazi] || '';
    rows.push({
      index: i,
      mountain,
      jiazi,
      nayin,
      stem,
      start,
      end,
      center,
      gradeKey: grade.key,
      grade: grade.name,
      usable: grade.usable,
      lore: `${mountain}山 ${jiazi}分金（${nayin}）：${grade.desc}`
    });
  }
  return rows;
}

const TABLE = buildTable();

/** 依罗盘角度取分金（0=正北） */
function resolve(angle) {
  const rel = ((angle - 352.5) % 360 + 360) % 360;
  const idx = Math.floor(rel / 3) % 120;
  return TABLE[idx];
}

/** 取某坐山下的 5 位分金 */
function forMountain(mountain) {
  return TABLE.filter((r) => r.mountain === mountain);
}

/** 吉度汇总：按二十四山列出可用分金 */
function auspiciousByMountain() {
  const out = [];
  MOUNTAINS_24.forEach((m) => {
    const rows = TABLE.filter((r) => r.mountain === m && r.usable);
    out.push({
      mountain: m,
      count: rows.length,
      names: rows.map((r) => `${r.jiazi}（${r.start.toFixed(1)}°–${r.end.toFixed(1)}°）`)
    });
  });
  return out;
}

/* ---------- 逐度细断（360° 每度）与兼向判定 ---------- */

function norm(deg) {
  return ((Number(deg) || 0) % 360 + 360) % 360;
}

/** 该度数最近的二十四山（山中心每 15°，子=0°） */
function mountainOf(deg) {
  const idx = Math.round(norm(deg) / 15) % 24;
  return { mountain: MOUNTAINS_24[idx], index: idx, center: idx * 15 % 360 };
}

/** 相对山中心的有符号偏移，顺时针为正，范围 −7.5 ~ 7.5 */
function offsetToCenter(deg) {
  const m = mountainOf(deg);
  let off = norm(deg) - m.center;
  if (off > 180) off -= 360;
  if (off < -180) off += 360;
  return off;
}

/**
 * 兼向判定（与 kongwang.classify 同口径）：
 *   |off| < 1.5° 正针；1.5° ≤ |off| < 6.5° 兼向；≥ 6.5° 贴边界（出卦/差错）
 */
function jianXiang(deg) {
  const m = mountainOf(deg);
  const off = offsetToCenter(deg);
  const abs = Math.abs(off);
  if (abs < 1.5) {
    return { type: 'pure', text: `${m.mountain}山正针`, toward: null, offset: abs, mountain: m.mountain };
  }
  if (abs >= 6.5) {
    return { type: 'boundary', text: `${m.mountain}山贴边界（出卦）`, toward: null, offset: abs, mountain: m.mountain };
  }
  const towardIdx = off > 0 ? (m.index + 1) % 24 : (m.index + 23) % 24;
  const toward = MOUNTAINS_24[towardIdx];
  return { type: 'jian', text: `${m.mountain}山兼${toward}`, toward, offset: abs, mountain: m.mountain };
}

/**
 * 逐度细断：把某 1° 拆成「所属分金 + 分金内位置 + 兼向 + 是否可用 + 怎么调」
 * @param {number} deg 罗盘度数（0=正北，顺时针）
 */
function degreeReading(deg) {
  const d = norm(deg);
  const row = resolve(d);
  const jian = jianXiang(d);
  const rel = ((d - 352.5) % 360 + 360) % 360;
  const inCell = rel - Math.floor(rel / 3) * 3; // 0~3，分金内位置
  const cellPos = inCell < 0.9 ? '分金前段' : (inCell > 2.1 ? '分金后段' : '分金中段');
  const usable = row.usable && jian.type !== 'boundary';
  let verdict;
  if (!row.usable) {
    verdict = `${row.grade}，此度不宜立向`;
  } else if (jian.type === 'boundary') {
    verdict = '虽落珠宝分金，但已贴山界出卦，仍不可用';
  } else if (jian.type === 'jian') {
    verdict = `${row.grade}可用，但为${jian.text}，玄空须起替卦`;
  } else if (inCell < 0.4 || inCell > 2.6) {
    verdict = `${row.grade}可用，接近分金交界，宜再微调一线`;
  } else {
    verdict = `${row.grade}可用，${cellPos}最纯`;
  }
  const near = nearestAuspicious(d);
  return {
    deg: d,
    mountain: row.mountain,
    jiazi: row.jiazi,
    nayin: row.nayin,
    grade: row.grade,
    gradeKey: row.gradeKey,
    usable,
    inCell: Math.round(inCell * 10) / 10,
    cellPos,
    jian,
    verdict,
    nearest: near,
    advice: usable
      ? (jian.type === 'jian' ? `立向按替卦处理；若不愿替卦，回正至 ${mountainOf(d).center}°` : '可直接取用')
      : `建议调整到 ${near ? near.deg + '°（' + near.jiazi + '·' + near.nayin + '）' : '邻山吉度'}`
  };
}

/** 就近找可用吉度：以 0.5° 步长在 ±8° 内搜索（只要珠宝分金且未贴边界） */
function nearestAuspicious(deg) {
  const base = norm(deg);
  for (let step = 0; step <= 16; step++) {
    const candidates = step === 0 ? [0] : [step * 0.5, -step * 0.5];
    for (let i = 0; i < candidates.length; i++) {
      const d = norm(base + candidates[i]);
      const row = resolve(d);
      if (row.usable && Math.abs(offsetToCenter(d)) < 6.5) {
        return {
          deg: Math.round(d * 10) / 10,
          delta: Math.round(candidates[i] * 10) / 10,
          jiazi: row.jiazi,
          nayin: row.nayin,
          mountain: row.mountain
        };
      }
    }
  }
  return null;
}

module.exports = {
  JIAZI_60,
  NAYIN,
  GRADE,
  TABLE,
  MOUNTAINS_24,
  resolve,
  forMountain,
  auspiciousByMountain,
  mountainOf,
  offsetToCenter,
  jianXiang,
  degreeReading,
  nearestAuspicious
};
