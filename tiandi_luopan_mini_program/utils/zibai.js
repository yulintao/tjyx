/**
 * zibai.js
 * 紫白九星：年紫白 / 月紫白（节气月界）、九宫飞布、太岁岁破三煞、五黄二黑定位
 * 对齐 iOS Models/PurpleWhiteEngine.swift。
 */

const { flyNineStars } = require('./xuankong');
const { termJD } = require('./solar-terms');
const { PALACE_INFO } = require('./xuankong');

const ZHI = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];

// 太岁 / 岁破 / 三煞 落宫（按年支索引 0=子）
const TAI_SUI_CONFIG = [
  { ts: 1, sp: 9, ss: 9, ssText: '正南（巳午未方）' }, // 子
  { ts: 8, sp: 2, ss: 3, ssText: '正东（寅卯辰方）' }, // 丑
  { ts: 8, sp: 2, ss: 1, ssText: '正北（亥子丑方）' }, // 寅
  { ts: 3, sp: 7, ss: 7, ssText: '正西（申酉戌方）' }, // 卯
  { ts: 4, sp: 6, ss: 9, ssText: '正南（巳午未方）' }, // 辰
  { ts: 4, sp: 6, ss: 3, ssText: '正东（寅卯辰方）' }, // 巳
  { ts: 9, sp: 1, ss: 1, ssText: '正北（亥子丑方）' }, // 午
  { ts: 2, sp: 8, ss: 7, ssText: '正西（申酉戌方）' }, // 未
  { ts: 2, sp: 8, ss: 9, ssText: '正南（巳午未方）' }, // 申
  { ts: 7, sp: 3, ss: 3, ssText: '正东（寅卯辰方）' }, // 酉
  { ts: 6, sp: 4, ss: 1, ssText: '正北（亥子丑方）' }, // 戌
  { ts: 6, sp: 4, ss: 7, ssText: '正西（申酉戌方）' } // 亥
];

const STAR_INFO = {
  1: { name: '一白贪狼', nature: '吉', type: '官贵·桃花·文秀', elem: '水' },
  2: { name: '二黑巨门', nature: '凶', type: '病符·寡宿', elem: '土' },
  3: { name: '三碧禄存', nature: '凶', type: '是非·官讼', elem: '木' },
  4: { name: '四绿文曲', nature: '吉', type: '文昌·科名', elem: '木' },
  5: { name: '五黄廉贞', nature: '大凶', type: '关煞·灾祸', elem: '土' },
  6: { name: '六白武曲', nature: '吉', type: '权柄·偏财', elem: '金' },
  7: { name: '七赤破军', nature: '凶', type: '破耗·口舌', elem: '金' },
  8: { name: '八白左辅', nature: '吉', type: '正财·田宅', elem: '土' },
  9: { name: '九紫右弼', nature: '大吉', type: '喜庆·姻缘', elem: '火' }
};

/** 年紫白入中星 */
function yearStar(year) {
  let num = (11 - (year % 9)) % 9;
  if (num <= 0) num += 9;
  return num;
}

/** 月紫白入中星：年支定正月起星，逐月逆退 */
function monthStar(year, solarMonth) {
  const branchIndex = ((year - 4) % 12 + 12) % 12;
  let base = 2;
  if ([0, 3, 6, 9].indexOf(branchIndex) >= 0) base = 8; // 子午卯酉年
  else if ([1, 4, 7, 10].indexOf(branchIndex) >= 0) base = 5; // 辰戌丑未年
  let mStar = (base - (solarMonth - 1)) % 9;
  if (mStar <= 0) mStar += 9;
  return mStar;
}

/** 当前节气索引（0=小寒 … 23=冬至），用于节气月界 */
function solarTermIndex(date) {
  const { currentSolarTerm, jdToBeijingDate } = require('./solar-terms');
  const t = currentSolarTerm();
  return t ? t.index : 0;
}

/** 节气月：寅月=1 … 丑月=12 */
function solarMonthFromTerm(index) {
  if (index < 2) return 12;
  return Math.min(11, 1 + Math.floor((index - 2) / 2));
}

function isBeforeLiChun(date) {
  const y = date.getFullYear();
  const jd = termJD(2, y); // 立春
  const ms = (jd - 2440587.5) * 86400000 + 8 * 3600000;
  return date.getTime() < ms;
}

function taiSuiOfYear(year) {
  const zhiIndex = ((year - 4) % 12 + 12) % 12;
  const cfg = TAI_SUI_CONFIG[zhiIndex];
  return {
    year,
    zhi: ZHI[zhiIndex],
    taiSui: { zhi: ZHI[zhiIndex], palace: cfg.ts, dir: PALACE_INFO[cfg.ts].dir },
    suiPo: { zhi: ZHI[(zhiIndex + 6) % 12], palace: cfg.sp, dir: PALACE_INFO[cfg.sp].dir },
    sanSha: { palace: cfg.ss, dir: PALACE_INFO[cfg.ss].dir, text: cfg.ssText }
  };
}

// 逐宫断语与化解：九星各自的「做法 → 影响」（对齐 iOS PurpleWhiteEngine 的逐宫化解口径）
const ZIBAI_LORE = {
  1: {
    title: '一白贪狼（官贵·桃花）',
    action: '宜此方见明水、设书房或窗；用黑蓝、金属器物养水气。',
    effect: '主聪慧、名利、人缘；水气过旺则漂泊不定、易犯肾耳之疾。'
  },
  2: {
    title: '二黑巨门（病符）',
    action: '挂铜葫芦或六帝钱泄土；此方忌堆放杂物、忌长期阴暗。',
    effect: '主脾胃、妇科与慢性病；动土则病气立发，老人房尤忌设此。'
  },
  3: {
    title: '三碧禄存（是非）',
    action: '用红、紫（火）通关泄木；避金属尖角、刀剑摆件。',
    effect: '主口舌官非、兄弟不和、足伤；木旺则争讼不休。'
  },
  4: {
    title: '四绿文曲（文昌）',
    action: '摆富贵竹、文昌塔，保持明亮整洁；忌枯枝、镜面反照。',
    effect: '主科名、学业、文书；木气受克则思虑漂泊、考试失利。'
  },
  5: {
    title: '五黄廉贞（关煞）',
    action: '以六帝钱、铜铃、金器化土；严禁此方动土、钻墙、安门。',
    effect: '主重病、横祸、损丁破财；动土则煞气立应，孕期与病中尤忌。'
  },
  6: {
    title: '六白武曲（权柄）',
    action: '宜白、金色，见水泄金；忌红色催旺、忌金属堆积。',
    effect: '主权威、偏财、武贵；金过则刚断寡合、易招肺疾与金属伤。'
  },
  7: {
    title: '七赤破军（破耗）',
    action: '设安忍水或用黑蓝器物化金；忌刀剑、金属尖角、忌设门路。',
    effect: '主口舌、盗损、破耗；向首逢七赤尤忌开口动土。'
  },
  8: {
    title: '八白左辅（财星）',
    action: '宜白、米黄色，聚气不空旷；可置瓷器、陶罐稳固土气。',
    effect: '主田宅进财、人丁兴旺；此方空虚则财来财去。'
  },
  9: {
    title: '九紫右弼（喜庆）',
    action: '用红色、灯光催旺；忌水直冲、忌此处阴暗潮湿。',
    effect: '主喜庆、姻缘、名声；火过则炎症、血症，需防火灾。'
  }
};

// 组合加临（流年 × 流月）
function comboNote(yearStarNum, monthStarNum) {
  const pair = [yearStarNum, monthStarNum].sort((a, b) => a - b).join('');
  if (pair === '25') return { level: 'xiong', text: '二五交加：病符逢五黄，主重病横祸，严禁动土安门，宜六帝钱化泄。' };
  if (pair === '59') return { level: 'xiong', text: '五九同宫：火生土，五黄得势，主血症、火灾，忌红色催旺。' };
  if (pair === '55') return { level: 'xiong', text: '五黄重叠：关煞重重，此方不可动土、不可作卧室。' };
  if (pair === '14') return { level: 'ji', text: '一四同宫：文昌得润，主科名考试、文书顺利。' };
  if (pair === '89') return { level: 'ji', text: '八九相生：火生土，主田宅骤发、进财添丁。' };
  if (pair === '16') return { level: 'ji', text: '一六共宗：金水相生，主功名武贵。' };
  if (pair === '68') return { level: 'ji', text: '六八相生：土生金，主财富权柄并进。' };
  if (pair === '27') return { level: 'xiong', text: '二七同宫：土生金而带破，主口舌破财、咽喉之疾。' };
  return null;
}

function remedyText(star, monthStarNum) {
  const lore = ZIBAI_LORE[star];
  if (!lore) return '';
  const note = comboNote(star, monthStarNum);
  return {
    title: lore.title,
    text: `做法：${lore.action} 影响：${lore.effect}`,
    combo: note ? note.text : '',
    comboLevel: note ? note.level : 'ping'
  };
}

/**
 * 紫白全盘
 * @param {Date} [date]
 * @param {object} [opts] { sitPalace, facePalace } 由坐向换算而来
 */
function calculateChart(date, opts) {
  const d = date || new Date();
  const rawYear = d.getFullYear();
  const effectiveYear = isBeforeLiChun(d) ? rawYear - 1 : rawYear;
  const termIdx = solarTermIndex(d);
  const sm = solarMonthFromTerm(termIdx);

  const yCenter = yearStar(effectiveYear);
  const mCenter = monthStar(effectiveYear, sm);
  const yearStars = flyNineStars(yCenter, true);
  const monthStars = flyNineStars(mCenter, true);

  const sui = taiSuiOfYear(effectiveYear);

  const cells = [];
  [4, 9, 2, 3, 5, 7, 8, 1, 6].forEach((pid) => {
    const info = PALACE_INFO[pid];
    const ys = yearStars[pid];
    const ms = monthStars[pid];
    const yr = remedyText(ys, ms);
    const mr = remedyText(ms, ys);
    cells.push({
      palace: pid,
      name: info.name,
      dir: info.dir,
      elem: info.elem,
      year: ys,
      month: ms,
      yearStarInfo: STAR_INFO[ys],
      monthStarInfo: STAR_INFO[ms],
      isFive: ys === 5 || ms === 5,
      isTwo: ys === 2 || ms === 2,
      yearRemedy: yr.text,
      yearTitle: yr.title,
      yearCombo: yr.combo,
      yearComboLevel: yr.comboLevel,
      monthRemedy: mr.text,
      monthTitle: mr.title
    });
  });

  let fivePalace = 5;
  let twoPalace = 2;
  Object.keys(yearStars).forEach((p) => {
    if (yearStars[p] === 5) fivePalace = parseInt(p, 10);
    if (yearStars[p] === 2) twoPalace = parseInt(p, 10);
  });

  const warnings = [
    `太岁所临：${sui.taiSui.zhi}方（${sui.taiSui.dir}）· 宜静不宜动，忌动土起造`,
    `岁破对冲：${sui.suiPo.zhi}方（${sui.suiPo.dir}）`,
    `坐向三煞：${sui.sanSha.text}`,
    `流年五黄：${PALACE_INFO[fivePalace].name}（极凶，严禁动土钻墙）`,
    `流年二黑：${PALACE_INFO[twoPalace].name}（主脾胃疾厄）`
  ];

  const hits = [];
  if (opts && opts.facePalace) {
    if (opts.facePalace === fivePalace) hits.push('向首逢流年五黄大煞：门前忌破土修路，宜金属铜器化泄。');
    if (opts.sitPalace === fivePalace) hits.push('坐山落流年五黄方：主健康虚损、宅运退气。');
    if (opts.facePalace === twoPalace) hits.push('向首逢二黑病符：主肠胃隐疾，门槛下宜垫铜板。');
    if (opts.facePalace === sui.suiPo.palace) hits.push('向首正对岁破凶位，宜避。');
    if (opts.sitPalace === sui.taiSui.palace) hits.push('坐山落太岁重地，忌后方动土。');
  }

  return {
    year: effectiveYear,
    rawYear,
    beforeLiChun: effectiveYear !== rawYear,
    solarMonth: sm,
    solarTermIndex: termIdx,
    yearCenter: yCenter,
    monthCenter: mCenter,
    yearStars,
    monthStars,
    cells,
    suiSui: sui,
    fivePalace,
    twoPalace,
    warnings,
    hits
  };
}

module.exports = {
  ZHI,
  STAR_INFO,
  ZIBAI_LORE,
  TAI_SUI_CONFIG,
  yearStar,
  monthStar,
  solarTermIndex,
  solarMonthFromTerm,
  isBeforeLiChun,
  taiSuiOfYear,
  remedyText,
  comboNote,
  calculateChart
};
