/**
 * hexagram.js
 * 六十四卦：卦名矩阵、上下卦、二进制、角度定位、抽爻换象、变卦 / 互卦 / 错卦 / 综卦
 * 对应 iOS Models/Hexagram64.swift 的 64 卦 5.625° 分度与 384 爻抽爻模型。
 */

const TRIGRAMS = [
  { name: '乾', symbol: '☰', bin: '111', nature: '天', elem: '金', num: 1 },
  { name: '兑', symbol: '☱', bin: '110', nature: '泽', elem: '金', num: 2 },
  { name: '离', symbol: '☲', bin: '101', nature: '火', elem: '火', num: 3 },
  { name: '震', symbol: '☳', bin: '100', nature: '雷', elem: '木', num: 4 },
  { name: '巽', symbol: '☴', bin: '011', nature: '风', elem: '木', num: 5 },
  { name: '坎', symbol: '☵', bin: '010', nature: '水', elem: '水', num: 6 },
  { name: '艮', symbol: '☶', bin: '001', nature: '山', elem: '土', num: 7 },
  { name: '坤', symbol: '☷', bin: '000', nature: '地', elem: '土', num: 8 }
];

// 64 卦名矩阵：[上卦][下卦]
const NAMES = [
  ['乾为天', '天泽履', '天火同人', '天雷无妄', '天风姤', '天水讼', '天山遁', '天地否'],
  ['泽天夬', '兑为泽', '泽火革', '泽雷随', '泽风大过', '泽水困', '泽山咸', '泽地萃'],
  ['火天大有', '火泽睽', '离为火', '火雷噬嗑', '火风鼎', '火水未济', '火山旅', '火地晋'],
  ['雷天大壮', '雷泽归妹', '雷火丰', '震为雷', '雷风恒', '雷水解', '雷山小过', '雷地豫'],
  ['风天小畜', '风泽中孚', '风火家人', '风雷益', '巽为风', '风水涣', '风山渐', '风地观'],
  ['水天需', '水泽节', '水火既济', '水雷屯', '水风井', '坎为水', '水山蹇', '水地比'],
  ['山天大畜', '山泽损', '山火贲', '山雷颐', '山风蛊', '山水蒙', '艮为山', '山地剥'],
  ['地天泰', '地泽临', '地火明夷', '地雷复', '地风升', '地水师', '地山谦', '坤为地']
];

// 爻位名称（自下而上）
const YAO_NAMES = ['初爻', '二爻', '三爻', '四爻', '五爻', '上爻'];
const YAO_KIND = { 1: '阳爻', 0: '阴爻' };

// 卦气五行生成数：一水二火三木四金五土
const ELEM_NUMBER = { 水: 1, 火: 2, 木: 3, 金: 4, 土: 5 };

// 分金等级 → 卦的吉凶分级
const LUCK_BY_GRADE = { jewel: '大吉', pit: '平', lonely: '慎用', void: '慎用' };
const LUCK_RANK = { 大吉: 4, 中吉: 3, 平: 2, 慎用: 1 };

/** 单卦的卦气生成数、吉凶分级、居中分金描述（与分金页同源，都用 120 分金表） */
function attributesOf(center, upperElem) {
  const FJ = require('./fenjin');
  const fj = FJ.degreeReading(center);
  const elemNumber = ELEM_NUMBER[upperElem] || 5;
  const elemName = Object.keys(ELEM_NUMBER).filter((k) => ELEM_NUMBER[k] === elemNumber)[0] || '土';

  let luckDegree = LUCK_BY_GRADE[fj.gradeKey] || '平';
  // 珠宝分金但落分金前段 / 后段（不在中段）：纳气稍偏，降为中吉
  if (fj.gradeKey === 'jewel' && fj.cellPos && fj.cellPos !== '分金中段') luckDegree = '中吉';

  // 卦区与二十四山分区不同源，故此处只述分金，不套用「兼向」判语
  const detail = [`居中分金 ${fj.jiazi}（${fj.nayin}）`, fj.grade, fj.cellPos].filter(Boolean).join(' · ');

  return {
    elementNumber: elemNumber,
    elementName: elemName,
    luckDegree,
    luckRank: LUCK_RANK[luckDegree] || 2,
    fenJinDetail: detail,
    fenJinGrade: fj.grade,
    fenJinJiazi: fj.jiazi,
    fenJinNayin: fj.nayin
  };
}

function build() {
  const out = [];
  let id = 0;
  for (let u = 0; u < 8; u++) {
    for (let l = 0; l < 8; l++) {
      const upper = TRIGRAMS[u];
      const lower = TRIGRAMS[l];
      // 二进制自下而上：下卦 3 位 + 上卦 3 位
      const binary = lower.bin + upper.bin;
      const angleCenter = id * 5.625 + 2.8125;
      out.push({
        id,
        name: NAMES[u][l],
        upper: upper.name,
        lower: lower.name,
        upperNature: upper.nature,
        lowerNature: lower.nature,
        upperElem: upper.elem,
        lowerElem: lower.elem,
        binary,
        angleCenter,
        angleStart: id * 5.625,
        angleEnd: (id + 1) * 5.625,
        ...attributesOf(angleCenter, upper.elem)
      });
      id++;
    }
  }
  return out;
}

const HEXAGRAMS = build();

/** 依角度取卦（0=正北，顺时针） */
function resolve(angleA) {
  const a = ((angleA % 360) + 360) % 360;
  const idx = Math.floor(a / 5.625) % 64;
  const offset = a - idx * 5.625;
  const yao = Math.min(6, Math.floor(offset / 0.9375) + 1);
  return { ...HEXAGRAMS[idx], yao, yaoName: YAO_NAMES[yao - 1], yaoKind: YAO_KIND[HEXAGRAMS[idx].binary[yao - 1]] };
}

/** 依二进制取卦 */
function byBinary(binary) {
  const found = HEXAGRAMS.find((h) => h.binary === binary);
  return found || null;
}

/** 变卦：翻转指定爻（1–6，自下而上） */
function changeYao(binary, yao) {
  const arr = binary.split('');
  const pos = yao - 1;
  arr[pos] = arr[pos] === '1' ? '0' : '1';
  return byBinary(arr.join(''));
}

/** 互卦：二三四爻为下卦，三四五爻为上卦 */
function mutual(binary) {
  const lower = binary.slice(1, 4);
  const upper = binary.slice(2, 5);
  return byBinary(lower + upper);
}

/** 错卦：六爻全变 */
function inverse(binary) {
  return byBinary(binary.split('').map((b) => (b === '1' ? '0' : '1')).join(''));
}

/** 综卦：六爻倒置 */
function reverse(binary) {
  return byBinary(binary.split('').reverse().join(''));
}

/** 抽爻换象全解 */
function divine(angleA) {
  const base = resolve(angleA);
  const changed = changeYao(base.binary, base.yao);
  const mut = mutual(base.binary);
  const inv = inverse(base.binary);
  const rev = reverse(base.binary);
  return {
    base,
    changed,
    mutual: mut,
    inverse: inv,
    reverse: rev,
    text: `坐向 ${angleA.toFixed(1)}° 落 ${base.name}（${base.upper}上${base.lower}下），抽得${base.yaoName}${base.yaoKind}动，变卦为 ${changed ? changed.name : '—'}。`
  };
}

module.exports = {
  TRIGRAMS,
  NAMES,
  HEXAGRAMS,
  YAO_NAMES,
  ELEM_NUMBER,
  LUCK_BY_GRADE,
  LUCK_RANK,
  attributesOf,
  resolve,
  byBinary,
  changeYao,
  mutual,
  inverse,
  reverse,
  divine
};
