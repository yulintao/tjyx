/**
 * qimen.js
 * 时家奇门（转盘 · 拆补法）：节气定局、三元、地盘三奇六仪、值符值使、天盘九星、八门、八神
 * 依据《奇门遁甲》通用排法，对应 iOS Models/QimenEngine.swift 的盘面结构。
 */

const { calculateFourPillars, TIAN_GAN, DI_ZHI } = require('./astronomy');
const { ruleReference } = require('./traditional-evidence');
const { termJD, currentSolarTerm, jdToBeijingDate } = require('./solar-terms');

// 二十四节气 → 上/中/下元 局数
const JU_TABLE = {
  冬至: [1, 7, 4], 小寒: [2, 8, 5], 大寒: [3, 9, 6],
  立春: [8, 5, 2], 雨水: [9, 6, 3], 惊蛰: [1, 7, 4],
  春分: [3, 9, 6], 清明: [4, 1, 7], 谷雨: [5, 2, 8],
  立夏: [4, 1, 7], 小满: [5, 2, 8], 芒种: [6, 3, 9],
  夏至: [9, 3, 6], 小暑: [8, 2, 5], 大暑: [7, 1, 4],
  立秋: [2, 5, 8], 处暑: [1, 4, 7], 白露: [9, 3, 6],
  秋分: [7, 1, 4], 寒露: [6, 9, 3], 霜降: [5, 8, 2],
  立冬: [6, 9, 3], 小雪: [5, 8, 2], 大雪: [4, 7, 1]
};

const YANG_TERMS = ['冬至', '小寒', '大寒', '立春', '雨水', '惊蛰', '春分', '清明', '谷雨', '立夏', '小满', '芒种'];

const RING = [1, 8, 3, 4, 9, 2, 7, 6]; // 后天八卦顺时针：坎→艮→震→巽→离→坤→兑→乾

const PALACE_NAME = { 1: '坎一宫', 2: '坤二宫', 3: '震三宫', 4: '巽四宫', 5: '中五宫', 6: '乾六宫', 7: '兑七宫', 8: '艮八宫', 9: '离九宫' };
const PALACE_DIR = { 1: '正北', 2: '西南', 3: '正东', 4: '东南', 5: '中央', 6: '西北', 7: '正西', 8: '东北', 9: '正南' };

const STAR_BY_PALACE = { 1: '天蓬', 2: '天芮', 3: '天冲', 4: '天辅', 5: '天禽', 6: '天心', 7: '天柱', 8: '天任', 9: '天英' };
const GATE_BY_PALACE = { 1: '休门', 2: '死门', 3: '伤门', 4: '杜门', 5: '死门', 6: '开门', 7: '惊门', 8: '生门', 9: '景门' };

const STEM_ORDER = ['戊', '己', '庚', '辛', '壬', '癸', '丁', '丙', '乙'];
const XUN_SHOU = [
  { xun: '甲子', yi: '戊' },
  { xun: '甲戌', yi: '己' },
  { xun: '甲申', yi: '庚' },
  { xun: '甲午', yi: '辛' },
  { xun: '甲辰', yi: '壬' },
  { xun: '甲寅', yi: '癸' }
];

const STAR_LUCK = { 天蓬: '水·凶（盗贼、水厄）', 天芮: '土·凶（病符）', 天冲: '木·吉（勇进）', 天辅: '木·吉（文昌）', 天禽: '土·中（寄坤）', 天心: '金·吉（谋略、医药）', 天柱: '金·凶（口舌、破坏）', 天任: '土·吉（田产、稳重）', 天英: '火·中（文彩、急躁）' };
const GATE_LUCK = { 休门: '吉·休养、贵人多助', 生门: '大吉·生财、置业', 伤门: '凶·伤损、争斗', 杜门: '中·闭塞、隐匿', 景门: '中·文书、口舌', 死门: '凶·死亡、丧事', 惊门: '凶·惊恐、官非', 开门: '大吉·开张、仕途' };
const GOD_ORDER = ['值符', '腾蛇', '太阴', '六合', '白虎', '玄武', '九地', '九天'];
// 中宫不入八神，iOS QimenEngine.swift:543-553 以「元极」标识中宫神位。
const CENTER_GOD = '元极';
// 与 iOS QimenEngine.classicalSourceNote 一致：只标注传承规则出处，
// 不把排法规则冒充古籍原文引述（iOS `ref_scope_note` 口径）。
const CLASSICAL_SOURCE = ruleReference('奇门遁甲·时家转盘排法（拆补法）传世规则');

function dayJiaziIndex(pillars) {
  const gan = pillars.dayPillar[0];
  const zhi = pillars.dayPillar[1];
  const g = TIAN_GAN.indexOf(gan);
  const z = DI_ZHI.indexOf(zhi);
  let idx = 0;
  for (let i = 0; i < 60; i++) {
    if (i % 10 === g && i % 12 === z) { idx = i; break; }
  }
  return idx;
}

function hourJiaziIndex(pillars) {
  const gan = pillars.hourPillar[0];
  const zhi = pillars.hourPillar[1];
  const g = TIAN_GAN.indexOf(gan);
  const z = DI_ZHI.indexOf(zhi);
  let idx = 0;
  for (let i = 0; i < 60; i++) {
    if (i % 10 === g && i % 12 === z) { idx = i; break; }
  }
  return idx;
}

/** 当前节气与上中下元 */
function termAndYuan(date) {
  const now = date || new Date();
  const y = now.getFullYear();
  let termName = '冬至';
  let termIdx = 0;
  let termDate = null;
  for (let i = 0; i < 24; i++) {
    const { month, day } = jdToBeijingDate(termJD(i, y));
    const t = new Date(y, month - 1, day);
    if (t <= now) {
      termIdx = i;
      termName = ['小寒', '大寒', '立春', '雨水', '惊蛰', '春分', '清明', '谷雨', '立夏', '小满', '芒种', '夏至', '小暑', '大暑', '立秋', '处暑', '白露', '秋分', '寒露', '霜降', '立冬', '小雪', '大雪', '冬至'][i];
      termDate = t;
    }
  }
  const pillars = calculateFourPillars(now, 120);
  const dIdx = dayJiaziIndex(pillars);
  const block = Math.floor(dIdx / 5);
  const yuanIdx = block % 3; // 0 上元 1 中元 2 下元
  return { termName, termIdx, termDate, yuanIdx, yuanText: ['上元', '中元', '下元'][yuanIdx] };
}

/**
 * 排盘
 * @param {Date} date
 */
function calculateChart(date) {
  const d = date || new Date();
  const t = termAndYuan(d);
  const yang = YANG_TERMS.indexOf(t.termName) >= 0;
  const ju = JU_TABLE[t.termName][t.yuanIdx];
  const juText = `${yang ? '阳遁' : '阴遁'}${'一二三四五六七八九'[ju - 1]}局`;

  // 月令旺衰：节气管月建，门 / 星按五行与月令比旺相休囚死
  const monthZhi = MONTH_BRANCH_BY_TERM[t.termName] || '子';
  const monthElem = MONTH_ELEM[monthZhi] || '土';

  // 地盘三奇六仪：阳遁顺布、阴遁逆布，戊起局数宫
  const diPan = {};
  for (let i = 0; i < 9; i++) {
    const palace = yang ? ((ju - 1 + i) % 9) + 1 : ((ju - 1 - i + 9) % 9) + 1;
    diPan[palace] = STEM_ORDER[i];
  }

  const pillars = calculateFourPillars(d, 120);
  const hIdx = hourJiaziIndex(pillars);
  const xun = XUN_SHOU[Math.floor(hIdx / 10)];
  const xunPos = XUN_SHOU.map((x) => x.yi).indexOf(xun.yi);
  // 旬首六仪所在地盘宫
  let xunPalace = 5;
  Object.keys(diPan).forEach((p) => { if (diPan[p] === xun.yi) xunPalace = parseInt(p, 10); });

  const hourGan = pillars.hourPillar[0];
  // 时干地盘宫（甲时用旬首宫）
  let hourGanPalace = xunPalace;
  Object.keys(diPan).forEach((p) => { if (diPan[p] === hourGan) hourGanPalace = parseInt(p, 10); });

  const zhiFuStar = STAR_BY_PALACE[xunPalace] || '天禽';
  const zhiShiGate = GATE_BY_PALACE[xunPalace] || '死门';

  // 天盘九星：值符加时干宫，其余顺布
  const starOrigin = RING.indexOf(normalizeRingPalace(xunPalace));
  const starTarget = RING.indexOf(normalizeRingPalace(hourGanPalace));
  const starShift = (starTarget - starOrigin + 8) % 8;

  const tianStars = {};
  RING.forEach((p, i) => {
    const srcIdx = (i - starShift + 8) % 8;
    tianStars[p] = STAR_BY_PALACE[RING[srcIdx]];
  });
  tianStars[5] = '天禽';

  // 八门：值使随时宫，阳遁顺行、阴遁逆行
  const gateOrigin = RING.indexOf(normalizeRingPalace(xunPalace));
  const step = hIdx % 10;
  const gateShift = yang ? step : -step;
  const gates = {};
  RING.forEach((p, i) => {
    const srcIdx = ((i - gateShift) % 8 + 8) % 8;
    gates[p] = GATE_BY_PALACE[RING[srcIdx]];
  });

  // 八神：值符宫起，阳顺阴逆
  const zhiFuPalace = normalizeRingPalace(hourGanPalace);
  const godStart = RING.indexOf(zhiFuPalace);
  const gods = {};
  RING.forEach((p, i) => {
    const k = yang ? (i - godStart + 8) % 8 : (godStart - i + 8) % 8;
    gods[p] = GOD_ORDER[k];
  });

  const cells = [];
  [4, 9, 2, 3, 5, 7, 8, 1, 6].forEach((pid) => {
    const star = pid === 5 ? '天禽' : tianStars[pid];
    const gateName = pid === 5 ? '' : gates[pid];
    const gateState = gateName ? vitalityOf(gateName, true, monthElem) : { name: '', elem: '', state: '无', score: 0, text: '中宫无门' };
    const starState = vitalityOf(star, false, monthElem);
    cells.push({
      palace: pid,
      name: PALACE_NAME[pid],
      dir: PALACE_DIR[pid],
      di: diPan[pid],
      star,
      starLuck: STAR_LUCK[star],
      gate: pid === 5 ? '—' : gates[pid],
      gateLuck: pid === 5 ? '中宫无门' : GATE_LUCK[gates[pid]],
      god: pid === 5 ? CENTER_GOD : gods[pid],
      isZhiFu: pid === normalizeRingPalace(hourGanPalace),
      isZhiShi: pid === RING[(gateOrigin + gateShift + 8 * 10) % 8],
      isCenter: pid === 5,
      gateState,
      starState,
      vitality: {
        score: gateState.score + starState.score,
        text: `${gateState.text}；${starState.text}`
      }
    });
  });

  // 用神简断：以「开门 / 生门 / 休门」所在方位为吉方
  const goodDirs = cells
    .filter((c) => ['开门', '生门', '休门'].indexOf(c.gate) >= 0)
    .map((c) => `${c.dir}（${c.gate}）`);

  return {
    dateText: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`,
    term: t.termName,
    yuan: t.yuanText,
    ju,
    juText,
    dun: yang ? '阳遁' : '阴遁',
    pillars,
    xun,
    zhiFu: { star: zhiFuStar, palace: PALACE_NAME[xunPalace], dir: PALACE_DIR[xunPalace] },
    zhiShi: { gate: zhiShiGate, palace: PALACE_NAME[xunPalace], dir: PALACE_DIR[xunPalace] },
    cells,
    goodDirs,
    monthZhi,
    monthElem,
    monthText: `月建${monthZhi}（${monthElem}当令）`,
    classicalSource: CLASSICAL_SOURCE,
    summary: `${t.termName}${t.yuanText} · ${juText} · 值符${zhiFuStar}临${PALACE_DIR[xunPalace]}，值使${zhiShiGate}。吉方：${goodDirs.join('、') || '以用神落宫另断'}。`
  };
}

/* ---------- 旺衰：月令五行 × 门 / 星五行 ---------- */

// 节气 → 月建（立春起寅）
const MONTH_BRANCH_BY_TERM = {
  立春: '寅', 雨水: '寅', 惊蛰: '卯', 春分: '卯', 清明: '辰', 谷雨: '辰',
  立夏: '巳', 小满: '巳', 芒种: '午', 夏至: '午', 小暑: '未', 大暑: '未',
  立秋: '申', 处暑: '申', 白露: '酉', 秋分: '酉', 寒露: '戌', 霜降: '戌',
  立冬: '亥', 小雪: '亥', 大雪: '子', 冬至: '子', 小寒: '丑', 大寒: '丑'
};

const MONTH_ELEM = {
  寅: '木', 卯: '木', 辰: '土', 巳: '火', 午: '火', 未: '土',
  申: '金', 酉: '金', 戌: '土', 亥: '水', 子: '水', 丑: '土'
};

const GATE_ELEM = { 休门: '水', 生门: '土', 伤门: '木', 杜门: '木', 景门: '火', 死门: '土', 惊门: '金', 开门: '金' };
const STAR_ELEM = { 天蓬: '水', 天芮: '土', 天冲: '木', 天辅: '木', 天禽: '土', 天心: '金', 天柱: '金', 天任: '土', 天英: '火' };

const SHENG = { 木: '火', 火: '土', 土: '金', 金: '水', 水: '木' }; // 我生
const KE = { 木: '土', 土: '水', 水: '火', 火: '金', 金: '木' };     // 我克

/**
 * 五行旺相休囚死（相对月令）
 * 当令旺、令生者相、生令者休、克令者囚、令克者死
 */
function relation(elem, monthElem) {
  if (!elem) return { state: '无', score: 0, text: '无五行可判' };
  if (elem === monthElem) return { state: '旺', score: 2, text: `${elem}当令而旺` };
  if (SHENG[monthElem] === elem) return { state: '相', score: 1, text: `得${monthElem}生扶而相` };
  if (SHENG[elem] === monthElem) return { state: '休', score: 0, text: `生${monthElem}而气泄，休` };
  if (KE[elem] === monthElem) return { state: '囚', score: -1, text: `克${monthElem}而受制，囚` };
  return { state: '死', score: -2, text: `被${monthElem}所克，死` };
}

/** 某门 / 某星在当月令下的旺衰 */
function vitalityOf(name, isGate, monthElem) {
  const elem = isGate ? GATE_ELEM[name] : STAR_ELEM[name];
  return Object.assign({ name, elem: elem || '' }, relation(elem || '', monthElem));
}

function normalizeRingPalace(p) {
  return p === 5 ? 2 : p; // 中五寄坤二
}

// 八门断语（对齐 iOS QimenEngine 的八门吉凶短句）
const GATE_LINE = {
  开: '经商开业动身，百事通亨',
  休: '求名休闲大吉，水清木秀',
  生: '求财置业大吉，土旺金生',
  伤: '讨债索敌宜，出行防伤灾',
  杜: '潜伏隐匿避灾，闭藏门户',
  景: '文书考试宴请吉，火炎防急',
  死: '吊丧刑戮宜，出行造葬大凶',
  惊: '官非惊恐口舌，捕盗宜'
};

/** 八门吉凶短语（传入「开门」这类全名） */
function gateLineOf(gateName) {
  const key = String(gateName || '').replace('门', '');
  return GATE_LINE[key] || '';
}

const SCENARIOS = [
  { key: 'wealth', name: '求财', gate: '生门', star: '天任', god: '九地', stem: '戊', advice: '生门主财帛，落旺相之宫且临九地则财稳；忌落空亡、五黄方。' },
  { key: 'career', name: '事业求职', gate: '开门', star: '天心', god: '值符', stem: '庚', advice: '开门主官途，得值符同宫最吉；忌临玄武、惊门。' },
  { key: 'marriage', name: '婚姻感情', gate: '休门', star: '天英', god: '六合', stem: '乙', advice: '休门六合主婚姻和合；乙为女、庚为男，二宫相生则成。' },
  { key: 'health', name: '疾病求医', gate: '死门', star: '天芮', god: '白虎', stem: '己', advice: '天芮为病符，看其落宫定病位；求医取天心、开门所临之方。' },
  { key: 'exam', name: '考试文书', gate: '景门', star: '天辅', god: '太阴', stem: '丁', advice: '景门天辅主文章；落离、巽宫得地，忌落坎宫受克。' },
  { key: 'travel', name: '出行迁移', gate: '开门', star: '天冲', god: '九天', stem: '丙', advice: '开门临九天宜远行；忌落惊门、白虎方。' },
  { key: 'lawsuit', name: '官司诉讼', gate: '惊门', star: '天柱', god: '白虎', stem: '辛', advice: '惊门主讼，临白虎则凶；宜取开门、值符方斡旋。' },
  { key: 'negotiate', name: '谈判合作', gate: '杜门', star: '天辅', god: '六合', stem: '壬', advice: '六合主和合，杜门主隐匿；二宫相生则谈成。' }
];

/**
 * 场景用神评估
 * @param {object} chart calculateChart 结果
 * @param {string} key 场景 key
 */
function evaluateScenario(chart, key) {
  const sc = SCENARIOS.find((s) => s.key === key) || SCENARIOS[0];
  const cells = chart.cells.filter((c) => !c.isCenter);
  const byGate = cells.find((c) => c.gate === sc.gate);
  const byStar = cells.find((c) => c.star === sc.star);
  const byGod = cells.find((c) => c.god === sc.god);
  const byStem = chart.cells.find((c) => c.di === sc.stem);

  const target = byGate || byStar || byGod || byStem || cells[0];
  const gateGood = ['开门', '生门', '休门'].indexOf(target.gate) >= 0;
  const gateBad = ['死门', '惊门', '伤门'].indexOf(target.gate) >= 0;
  const starGood = ['天心', '天任', '天辅', '天冲'].indexOf(target.star) >= 0;
  const starBad = ['天蓬', '天芮', '天柱'].indexOf(target.star) >= 0;
  const godGood = ['值符', '六合', '九天', '九地', '太阴'].indexOf(target.god) >= 0;
  const godBad = ['白虎', '玄武', '腾蛇'].indexOf(target.god) >= 0;
  const gateLine = gateLineOf(target.gate);

  let score = 0;
  if (gateGood) score += 2;
  if (gateBad) score -= 2;
  if (starGood) score += 1;
  if (starBad) score -= 1;
  if (godGood) score += 1;
  if (godBad) score -= 1;

  // 旺衰：门星得令加分、失令减分（月令判旺相休囚死）
  const vit = (target.vitality && target.vitality.score) || 0;
  if (vit > 0) score += 1;
  else if (vit < 0) score -= 1;

  let level = 'ping';
  if (score >= 2) level = 'ji';
  else if (score <= -2) level = 'xiong';

  // 全盘取最吉之宫（门吉 + 星吉 + 神吉）
  const rank = (c) => {
    const g = ['开门', '生门', '休门'].indexOf(c.gate) >= 0 ? 3 : (['死门', '惊门', '伤门'].indexOf(c.gate) >= 0 ? -3 : 0);
    const s = ['天心', '天任', '天辅', '天冲'].indexOf(c.star) >= 0 ? 2 : (['天蓬', '天芮', '天柱'].indexOf(c.star) >= 0 ? -2 : 0);
    const o = ['值符', '六合', '九天', '九地', '太阴'].indexOf(c.god) >= 0 ? 2 : (['白虎', '玄武', '腾蛇'].indexOf(c.god) >= 0 ? -2 : 0);
    return g + s + o;
  };
  const bestCell = cells.slice().sort((a, b) => rank(b) - rank(a))[0] || target;
  const guide = `【${sc.name}指南】当下最利方位为【${bestCell.name}（${bestCell.dir}）】，得「${bestCell.gate}+${bestCell.star}+${bestCell.god}」加会。出行宜往此方动身；签约/面试宜背靠此方而坐（背孤击虚）以乘奇门吉气。`;

  return {
    key: sc.key,
    name: sc.name,
    palace: target.palace,
    palaceName: target.name,
    dir: target.dir,
    di: target.di,
    star: target.star,
    gate: target.gate,
    god: target.god,
    level,
    score,
    matchedBy: byGate ? '门' : (byStar ? '星' : (byGod ? '神' : '干')),
    gateLine,
    vitality: target.vitality || null,
    monthText: chart.monthText || '',
    best: {
      palace: bestCell.palace,
      name: bestCell.name,
      dir: bestCell.dir,
      gate: bestCell.gate,
      star: bestCell.star,
      god: bestCell.god
    },
    guide,
    text: `${sc.name}用神取${sc.gate}／${sc.star}／${sc.god}，落${target.name}（${target.dir}），得${target.di}干、${target.star}、${target.gate}、${target.god}${gateLine ? '（' + gateLine + '）' : ''}。${target.vitality ? '旺衰：' + target.vitality.text + '。' : ''}${sc.advice}`,
    advice: level === 'ji'
      ? `可往${target.dir}方用事，先动后静，事多顺遂。`
      : (level === 'xiong' ? `${target.dir}方用神受制，宜避其锋，另取开门、生门吉方。` : `用神中和，成事需借吉时与吉方，宜稳中求进。`)
  };
}

/** 年命落宫：出生年干支之天干在地盘的宫位 */
function lifeYearPalace(chart, birthYear) {
  const idx = ((birthYear - 4) % 60 + 60) % 60;
  const gan = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'][idx % 10];
  const cell = chart.cells.find((c) => c.di === gan);
  return cell ? { gan, palace: cell.palace, name: cell.name, dir: cell.dir } : { gan, palace: 5, name: '中五宫', dir: '中央' };
}

const GATE_GOOD = ['开门', '生门', '休门'];
const GATE_BAD = ['死门', '惊门', '伤门'];
const STAR_GOOD = ['天心', '天任', '天辅', '天冲'];
const STAR_BAD = ['天蓬', '天芮', '天柱'];
const GOD_GOOD = ['值符', '六合', '九天', '九地', '太阴'];
const GOD_BAD = ['白虎', '玄武', '腾蛇'];

/**
 * 单宫解读：九宫点选后的一宫断语
 * 判据与 evaluateScenario 一致（门 +2/-2，星 +1/-1，神 +1/-1），不另造新说法
 * @param {object} cell calculateChart 的 cells 元素
 */
function palaceLine(cell) {
  if (!cell) return null;
  if (cell.isCenter) {
    return {
      name: cell.name,
      dir: cell.dir,
      title: '中五宫 · 天禽寄坤',
      level: 'ping',
      score: 0,
      text: `中宫为「${cell.god}」，天禽寄坤二宫，不给八门。此宫不主方位吉凶，只作全盘枢轴，断事时并入坤二宫论。`,
      gateLine: ''
    };
  }

  const gateGood = GATE_GOOD.indexOf(cell.gate) >= 0;
  const gateBad = GATE_BAD.indexOf(cell.gate) >= 0;
  const starGood = STAR_GOOD.indexOf(cell.star) >= 0;
  const starBad = STAR_BAD.indexOf(cell.star) >= 0;
  const godGood = GOD_GOOD.indexOf(cell.god) >= 0;
  const godBad = GOD_BAD.indexOf(cell.god) >= 0;

  let score = 0;
  if (gateGood) score += 2;
  if (gateBad) score -= 2;
  if (starGood) score += 1;
  if (starBad) score -= 1;
  if (godGood) score += 1;
  if (godBad) score -= 1;

  const vit = (cell.vitality && cell.vitality.score) || 0;
  if (vit > 0) score += 1;
  else if (vit < 0) score -= 1;

  const level = score >= 2 ? 'ji' : (score <= -2 ? 'xiong' : 'ping');
  const gateLine = gateLineOf(cell.gate);
  const parts = [
    `${cell.name}（${cell.dir}）`,
    `地盘${cell.di}干`,
    `${cell.star}·${cell.starLuck || ''}`,
    `${cell.gate}·${cell.gateLuck || ''}`,
    `${cell.god}`
  ];
  if (cell.vitality) parts.push(`旺衰·${cell.vitality.text}`);

  const verdict = level === 'ji'
    ? '门星神三吉加会，此方可动身、签约、会客、置办。'
    : (level === 'xiong'
      ? '门星神受制，此方宜静守；必须经过时走快、不长留，另取开、生、休门之方。'
      : '吉凶相抵，可办事但需借吉时；重要事项另取值符或三吉门所在之方。');

  return {
    name: cell.name,
    dir: cell.dir,
    title: `${cell.name} · ${cell.dir}`,
    level,
    score,
    parts: parts.join(' ｜ '),
    gateLine,
    vitality: cell.vitality || null,
    text: `${parts.join('｜')}。${gateLine ? gateLine + '，' : ''}${verdict}`
  };
}

module.exports = {
  JU_TABLE,
  RING,
  PALACE_NAME,
  PALACE_DIR,
  STAR_BY_PALACE,
  GATE_BY_PALACE,
  GATE_LINE,
  gateLineOf,
  GATE_ELEM,
  STAR_ELEM,
  MONTH_ELEM,
  relation,
  vitalityOf,
  SCENARIOS,
  calculateChart,
  termAndYuan,
  evaluateScenario,
  palaceLine,
  lifeYearPalace
};
