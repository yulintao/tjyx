/**
 * zeri.js
 * 择日：建除十二神、日课四柱、太岁三煞冲山、十二时辰吉凶（日破 / 旬空 / 三合六合）、未来吉日
 * 对齐 iOS Models/ZeRiEngine.swift 的建除与日课判定。
 */

const { calculateFourPillars, TIAN_GAN, DI_ZHI } = require('./astronomy');
const { solarTermIndex, solarMonthFromTerm, taiSuiOfYear } = require('./zibai');
const { ruleReference } = require('./traditional-evidence');

const JIAN_CHU = ['建', '除', '满', '平', '定', '执', '破', '危', '成', '收', '开', '闭'];

const JIAN_CHU_INFO = {
  建: { level: 'ping', yi: '出行、上任、见贵、祈福', ji: '动土、开仓、掘井', text: '建日为岁君，宜出行见贵，不宜动土开仓。' },
  除: { level: 'ji', yi: '除旧布新、扫舍、疗病、出行', ji: '嫁娶、开市、远行', text: '除日除旧迎新，宜清理疗病，不宜嫁娶开市。' },
  满: { level: 'ji', yi: '祭祀、祈福、开市、修造', ji: '嫁娶、安葬', text: '满日圆满，宜祭祀祈福，忌嫁娶安葬。' },
  平: { level: 'ping', yi: '修造、平治道途、协商', ji: '开渠、栽种、动土', text: '平日平常，宜修整平地，不宜开渠动土。' },
  定: { level: 'ji', yi: '嫁娶、安床、开市、签约', ji: '诉讼、远行', text: '定日安定，宜嫁娶安床签约，忌诉讼远行。' },
  执: { level: 'ping', yi: '捕捉、纳财、修造、守成', ji: '开市、出行', text: '执日操持，宜纳财守成，不宜开市出行。' },
  破: { level: 'xiong', yi: '破屋坏垣、疗病、拆旧', ji: '嫁娶、开市、出行、安葬', text: '破日大耗，只宜拆旧疗病，诸吉事皆忌。' },
  危: { level: 'xiong', yi: '安床、祭祀、静守', ji: '登高、远行、冒险', text: '危日危险，宜静守安床，忌登高远行。' },
  成: { level: 'ji', yi: '嫁娶、开市、入学、修造、签约', ji: '诉讼、拆屋', text: '成日成就，百事可成，宜嫁娶开市入学。' },
  收: { level: 'ping', yi: '纳财、收账、入仓、收敛', ji: '开市、出行、放债', text: '收日收纳，宜纳财收账，不宜开市放债。' },
  开: { level: 'ji', yi: '开市、出行、求财、入学、开张', ji: '安葬、破土', text: '开日开通，宜开市出行求财，忌安葬破土。' },
  闭: { level: 'xiong', yi: '安葬、筑堤、闭藏、休整', ji: '开市、出行、求医', text: '闭日闭塞，宜闭藏安葬，忌开市出行求医。' }
};

// 十二值神（黄黑道）：青龙、明堂、天刑、朱雀、金匮、天德、白虎、玉堂、天牢、玄武、司命、勾陈
const GOD_NAMES = ['青龙', '明堂', '天刑', '朱雀', '金匮', '天德', '白虎', '玉堂', '天牢', '玄武', '司命', '勾陈'];
const HUANG_DAO_INDEX = [0, 1, 4, 5, 7, 10];

/**
 * 十二值神专项宜忌（对齐 iOS ZeRiEngine.officerSpecificYiSummary）
 * 黄道六神：青龙、明堂、金匮、天德、玉堂、司命；黑道六神：天刑、朱雀、白虎、天牢、玄武、勾陈。
 */
const GOD_OFFICER_INFO = {
  青龙: { huang: true, yi: '修造、嫁娶、开市、出行、见贵', ji: '诉讼、争讼', text: '青龙为黄道首神，主喜庆财帛，百事皆宜，唯不宜兴讼。' },
  明堂: { huang: true, yi: '祭祀、嫁娶、开市、安葬、入学', ji: '动土、破土', text: '明堂主光明贵显，宜礼祀婚娶；土事须避，动土则泄气。' },
  天刑: { huang: false, yi: '修整、剪除、疗病', ji: '嫁娶、开市、出行', text: '天刑主刑伤，只宜修整剪除，婚娶开市皆忌。' },
  朱雀: { huang: false, yi: '祭祀、文书、上书', ji: '嫁娶、开市、出行', text: '朱雀主口舌文书，宜奏对修文，忌婚娶远行，易招是非。' },
  金匮: { huang: true, yi: '嫁娶、开市、纳财、安葬、置产', ji: '破土、拆屋', text: '金匮为财库，主聚财置业，婚娶开市纳财最吉。' },
  天德: { huang: true, yi: '祈福、嫁娶、开市、修造、安葬', ji: '刑罚、争讼', text: '天德贵神，解厄消灾，诸事可作，最宜祈福修造。' },
  白虎: { huang: false, yi: '拆卸、修整、出师', ji: '嫁娶、开市、出行、安葬', text: '白虎主血光凶伤，只宜拆卸旧物，婚娶开市出行皆忌。' },
  玉堂: { huang: true, yi: '嫁娶、开市、入宅、安床、安葬', ji: '拆屋、破土', text: '玉堂为贵神，主文书喜庆，入宅安床婚娶皆吉。' },
  天牢: { huang: false, yi: '安葬、修筑、闭藏', ji: '开市、出行、嫁娶', text: '天牢主拘禁，宜闭藏安葬，开市远行易受困阻。' },
  玄武: { huang: false, yi: '筑堤、防盗、闭藏', ji: '嫁娶、开市、远行', text: '玄武主盗贼暗昧，宜守不宜动，婚娶开市远行皆忌。' },
  司命: { huang: true, yi: '嫁娶、开市、入宅、安床、祈福', ji: '破土、行刑', text: '司命主福禄寿考，家宅婚娶安床祈福皆宜。' },
  勾陈: { huang: false, yi: '安葬、修墓、田产交割', ji: '嫁娶、开市、远行', text: '勾陈主田土羁绊，只宜安葬修墓，婚娶开市易生纠葛。' }
};

// 洛书宫号 → 方位名与罗盘角度（正北坎 0°，顺时针）
const PALACE_GOD = {
  1: { name: '正北坎宫', dir: '正北', angle: 0 },
  8: { name: '东北艮宫', dir: '东北', angle: 45 },
  3: { name: '正东震宫', dir: '正东', angle: 90 },
  4: { name: '东南巽宫', dir: '东南', angle: 135 },
  9: { name: '正南离宫', dir: '正南', angle: 180 },
  2: { name: '西南坤宫', dir: '西南', angle: 225 },
  7: { name: '正西兑宫', dir: '正西', angle: 270 },
  6: { name: '西北乾宫', dir: '西北', angle: 315 }
};

// 十干财神方位：甲艮乙坤丙丁兑，戊己坎宫庚辛震，壬离癸巽是真踪
const WEALTH_PALACE_BY_STEM = { 甲: 8, 乙: 2, 丙: 7, 丁: 7, 戊: 1, 己: 1, 庚: 3, 辛: 3, 壬: 9, 癸: 4 };
// 喜神口诀：甲己在艮乙庚乾，丙辛坤位喜神安，丁壬只在离宫坐，戊癸原来在巽间
const JOY_PALACE_BY_STEM = { 甲: 8, 己: 8, 乙: 6, 庚: 6, 丙: 2, 辛: 2, 丁: 9, 壬: 9, 戊: 4, 癸: 4 };

// 地支六冲（用于判时辰是否冲主人本命）
const LIU_CHONG = { 子: '午', 午: '子', 丑: '未', 未: '丑', 寅: '申', 申: '寅', 卯: '酉', 酉: '卯', 辰: '戌', 戌: '辰', 巳: '亥', 亥: '巳' };

const ZODIAC_BY_BRANCH = { 子: '鼠', 丑: '牛', 寅: '虎', 卯: '兔', 辰: '龙', 巳: '蛇', 午: '马', 未: '羊', 申: '猴', 酉: '鸡', 戌: '狗', 亥: '猪' };

/** 出生年 → 年支（立春从简按公历年，与八宅生肖口径一致） */
function birthBranchOf(year) {
  const y = Number(year);
  if (!y) return '';
  return DI_ZHI[((y - 4) % 12 + 12) % 12];
}

/**
 * 今日财神 / 喜神方位（对齐 iOS ZeRiEngine.dailyCompassDirections）
 * @param {Date} date
 */
function dailyCompassDirections(date) {
  const d = date || new Date();
  const pillars = calculateFourPillars(d, 120);
  const stem = pillars.dayPillar[0];
  const wealthPalace = WEALTH_PALACE_BY_STEM[stem] || 8;
  const joyPalace = JOY_PALACE_BY_STEM[stem] || 9;
  const w = PALACE_GOD[wealthPalace];
  const j = PALACE_GOD[joyPalace];
  return {
    date: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`,
    dayStem: stem,
    dayPillar: pillars.dayPillar,
    wealth: { palace: wealthPalace, name: w.name, dir: w.dir, angle: w.angle },
    joy: { palace: joyPalace, name: j.name, dir: j.dir, angle: j.angle },
    samePalace: wealthPalace === joyPalace,
    text: wealthPalace === joyPalace
      ? `今日${stem}日，财神与喜神同落${w.dir}（${w.name}），此方最宜纳财、见贵、出行。`
      : `今日${stem}日，财神在${w.dir}（${w.name}），喜神在${j.dir}（${j.name}）；求财朝财神方，婚喜会客朝喜神方。`
  };
}

/** 值神专项宜忌（对齐 iOS officerSpecificYiSummary） */
function officerSummary(godName) {
  const info = GOD_OFFICER_INFO[godName];
  if (!info) return '';
  return `${godName}值日（${info.huang ? '黄道' : '黑道'}）：宜${info.yi}；忌${info.ji}。${info.text}`;
}

// 事项择日：各事项宜用建除 + 忌神煞
const ACTIVITIES = [
  { key: 'dongtu', name: '动土修造', good: ['建', '满', '定', '成', '开'], bad: ['破', '危', '闭'] },
  { key: 'jiaqu', name: '嫁娶', good: ['定', '成', '满', '除'], bad: ['破', '危', '闭', '平'] },
  { key: 'kaishi', name: '开市开业', good: ['开', '成', '满', '定'], bad: ['破', '闭', '危'] },
  { key: 'ruxue', name: '入学考试', good: ['成', '开', '定'], bad: ['破', '闭'] },
  { key: 'anzang', name: '安葬', good: ['闭', '定', '成'], bad: ['破', '开', '满'] },
  { key: 'chuxing', name: '出行远行', good: ['建', '开', '除', '成'], bad: ['破', '危', '闭'] },
  { key: 'ruzhai', name: '入宅搬家', good: ['成', '开', '定', '满'], bad: ['破', '危', '闭'] }
];

// 地支六合 / 三合
const LIU_HE = { 子: '丑', 丑: '子', 寅: '亥', 卯: '戌', 辰: '酉', 巳: '申', 午: '未', 未: '午', 申: '巳', 酉: '辰', 戌: '卯', 亥: '寅' };
const SAN_HE = {
  子: ['申', '辰'], 丑: ['巳', '酉'], 寅: ['午', '戌'], 卯: ['亥', '未'],
  辰: ['申', '子'], 巳: ['酉', '丑'], 午: ['寅', '戌'], 未: ['亥', '卯'],
  申: ['子', '辰'], 酉: ['巳', '丑'], 戌: ['寅', '午'], 亥: ['卯', '未']
};

function zhiIndex(zhi) {
  return DI_ZHI.indexOf(zhi);
}

/** 月建（节气月支）：寅月为正月 */
function monthBranch(date) {
  const idx = solarTermIndex(date);
  const sm = solarMonthFromTerm(idx);
  return DI_ZHI[(sm + 1) % 12];
}

/** 建除十二神（以节气月建为「建」，日支顺数） */
function jianChuOf(date) {
  const pillars = calculateFourPillars(date, 120);
  const dayZhi = pillars.dayPillar.slice(-2, -1);
  const mb = monthBranch(date);
  const offset = (zhiIndex(dayZhi) - zhiIndex(mb) + 12) % 12;
  const name = JIAN_CHU[offset];
  return {
    name,
    offset,
    monthBranch: mb,
    dayZhi,
    info: JIAN_CHU_INFO[name],
    text: `${mb}月建，${pillars.dayPillar} 为「${name}」日：${JIAN_CHU_INFO[name].text}`
  };
}

/** 旬空（日柱所在旬的空亡二支） */
function xunKong(dayPillar) {
  const gan = dayPillar[0];
  const zhi = dayPillar[1];
  const ganIdx = TIAN_GAN.indexOf(gan);
  const zhiIdx = zhiIndex(zhi);
  // 日柱六十甲子序号
  const jiaziIdx = ((zhiIdx - ganIdx + 12) % 12) + Math.floor(ganIdx / 2) * 12;
  const xunStart = Math.floor(((zhiIdx - ganIdx + 12) % 12) / 2) * 10;
  const kong = [DI_ZHI[(xunStart + 10) % 12], DI_ZHI[(xunStart + 11) % 12]];
  return kong;
}

/**
 * 十二时辰吉凶
 * @param {Date} date
 * @param {string} sitMountain 坐山（二十四山，可选）
 * @param {string} ownerBranch 宅主本命年支（可选，用于判冲本命）
 */
function shichenList(date, sitMountain, ownerBranch) {
  const pillars = calculateFourPillars(date, 120);
  const dayGan = pillars.dayPillar[0];
  const dayZhi = pillars.dayPillar[1];
  const kong = xunKong(pillars.dayPillar);
  const ratStems = { 甲: 0, 己: 0, 乙: 2, 庚: 2, 丙: 4, 辛: 4, 丁: 6, 壬: 6, 戊: 8, 癸: 8 };
  const base = ratStems[dayGan] || 0;
  // 青龙起例：子午临申地，丑未戌上寻，寅申居子位，卯酉却在寅，辰戌龙位上，巳亥午上存
  const qingLongStart = ((zhiIndex(dayZhi) % 6) * 2 + 8) % 12;

  const list = [];
  for (let i = 0; i < 12; i++) {
    const zhi = DI_ZHI[i];
    const gan = TIAN_GAN[(base + i) % 10];
    const godIdx = ((i - qingLongStart + 12) % 12);
    const god = GOD_NAMES[godIdx];
    const huangDao = HUANG_DAO_INDEX.indexOf(godIdx) >= 0;
    const chong = (i - zhiIndex(dayZhi) + 12) % 12 === 6;
    const he = LIU_HE[dayZhi] === zhi;
    const sanhe = (SAN_HE[dayZhi] || []).indexOf(zhi) >= 0;
    const kongFlag = kong.indexOf(zhi) >= 0;
    const chongSit = sitMountain ? zhi === sitMountain : false;
    // 冲本命：该时辰地支正是宅主年支的六冲
    const clashesOwner = ownerBranch ? LIU_CHONG[ownerBranch] === zhi : false;

    let level = 'ping';
    let tip = '平常时辰';
    if (chong) { level = 'xiong'; tip = '时冲日支（日破），主事多阻，不宜关键决策'; }
    else if (kongFlag) { level = 'xiong'; tip = '旬空之时，主虚耗落空，宜守不宜进'; }
    else if (chongSit) { level = 'xiong'; tip = '时支冲坐山，动土修造忌用'; }
    else if (clashesOwner) { level = 'xiong'; tip = `时支${zhi}冲宅主本命${ownerBranch}，此时代主人行事易受冲，重要事勿用`; }
    else if (huangDao) {
      level = 'ji';
      tip = `${god}黄道吉时，宜用事${he || sanhe ? '（又得六合/三合，更吉）' : ''}`;
    }
    else if (he || sanhe) {
      level = 'ping';
      tip = `${god}黑道时，虽得${he ? '六合' : '三合'}助力，宜缓办小事`;
    }
    else { level = 'ping'; tip = `${god}黑道时，不宜开市、嫁娶、动土等大事`; }

    list.push({
      idx: i,
      zhi,
      gan,
      god,
      godType: GOD_OFFICER_INFO[god] && GOD_OFFICER_INFO[god].huang ? 'huang' : 'hei',
      huangDao,
      name: `${zhi}时`,
      pillar: `${gan}${zhi}`,
      level,
      tip,
      chong,
      kong: kongFlag,
      he,
      sanhe,
      clashesOwner
    });
  }
  return list;
}

/* ---------- 吉神与忌日（日课用神查表） ---------- */

/** 月建地支 → 节气月序（寅=1 … 丑=12） */
function monthNumOf(mb) {
  return ((zhiIndex(mb) - 2 + 12) % 12) + 1;
}

// 天德：按月查干或支（1 寅 … 12 丑）
const TIAN_DE = {
  1: ['gan', '丁'], 2: ['zhi', '申'], 3: ['gan', '壬'], 4: ['gan', '辛'],
  5: ['zhi', '亥'], 6: ['gan', '甲'], 7: ['gan', '癸'], 8: ['zhi', '寅'],
  9: ['gan', '丙'], 10: ['gan', '乙'], 11: ['zhi', '巳'], 12: ['gan', '庚']
};

// 月德：三合局对应天干
const YUE_DE = {
  寅: '丙', 午: '丙', 戌: '丙',
  申: '壬', 子: '壬', 辰: '壬',
  亥: '甲', 卯: '甲', 未: '甲',
  巳: '庚', 酉: '庚', 丑: '庚'
};

const HE_GAN = { 甲: '己', 己: '甲', 乙: '庚', 庚: '乙', 丙: '辛', 辛: '丙', 丁: '壬', 壬: '丁', 戊: '癸', 癸: '戊' };
const HE_ZHI = { 子: '丑', 丑: '子', 寅: '亥', 亥: '寅', 卯: '戌', 戌: '卯', 辰: '酉', 酉: '辰', 巳: '申', 申: '巳', 午: '未', 未: '午' };

// 天赦：春戊寅、夏甲午、秋戊申、冬甲子
const TIAN_SHE = { spring: ['戊', '寅'], summer: ['甲', '午'], autumn: ['戊', '申'], winter: ['甲', '子'] };
// 四废：春庚申辛酉、夏壬子癸亥、秋甲寅乙卯、冬丙午丁巳
const SI_FEI = {
  spring: ['庚申', '辛酉'], summer: ['壬子', '癸亥'], autumn: ['甲寅', '乙卯'], winter: ['丙午', '丁巳']
};

function seasonOf(mnum) {
  if (mnum >= 1 && mnum <= 3) return 'spring';   // 寅卯辰
  if (mnum >= 4 && mnum <= 6) return 'summer';   // 巳午未
  if (mnum >= 7 && mnum <= 9) return 'autumn';   // 申酉戌
  return 'winter';                                // 亥子丑
}

const SEASON_TEXT = { spring: '春', summer: '夏', autumn: '秋', winter: '冬' };

/**
 * 今日吉神：天德 / 天德合 / 月德 / 月德合 / 天赦
 * 命中即「今日值此神」，未命中给「本月该神在何日」，便于另择。
 */
function auspiciousGods(date) {
  const d = date || new Date();
  const p = calculateFourPillars(d, 120);
  const dayGan = p.dayPillar[0];
  const dayZhi = p.dayPillar[1];
  const mb = monthBranch(d);
  const mnum = monthNumOf(mb);
  const season = seasonOf(mnum);

  const list = [];
  const td = TIAN_DE[mnum] || TIAN_DE[1];
  const tdVal = td[1];
  const tdHit = td[0] === 'gan' ? dayGan === tdVal : dayZhi === tdVal;
  const tdHe = td[0] === 'gan' ? HE_GAN[tdVal] : HE_ZHI[tdVal];
  list.push({
    key: 'tiande',
    name: '天德',
    hit: tdHit,
    day: tdVal,
    detail: tdHit ? '今日值天德，众煞退避，宜祈福、嫁娶、动土、入宅。' : `本月天德在${tdVal}日，可另择。`
  });
  list.push({
    key: 'tiandehe',
    name: '天德合',
    hit: td[0] === 'gan' ? dayGan === tdHe : dayZhi === tdHe,
    day: tdHe,
    detail: `本月天德合在${tdHe}日，与天德同用可解小煞。`
  });

  const yd = YUE_DE[mb] || '丙';
  list.push({
    key: 'yuede',
    name: '月德',
    hit: dayGan === yd,
    day: yd,
    detail: dayGan === yd ? '今日值月德，主福厚、解厄，诸事可作。' : `本月月德在${yd}日。`
  });
  list.push({
    key: 'yuedehe',
    name: '月德合',
    hit: dayGan === HE_GAN[yd],
    day: HE_GAN[yd],
    detail: `本月月德合在${HE_GAN[yd]}日。`
  });

  const ts = TIAN_SHE[season];
  const tsHit = dayGan === ts[0] && dayZhi === ts[1];
  list.push({
    key: 'tianshe',
    name: '天赦',
    hit: tsHit,
    day: `${ts[0]}${ts[1]}`,
    detail: tsHit ? `今日为${SEASON_TEXT[season]}季天赦日，百事皆赦，宜解厄、祈福、修造。` : `${SEASON_TEXT[season]}季天赦在${ts[0]}${ts[1]}日。`
  });

  const hits = list.filter((x) => x.hit).map((x) => x.name);
  return { monthNum: mnum, season, list, hits, text: hits.length ? `今日值${hits.join('、')}` : '今日不值天德月德' };
}

/** 今日忌日：四废（另含月破由 analyze 单独判） */
function badDaysOf(date) {
  const d = date || new Date();
  const p = calculateFourPillars(d, 120);
  const dayGanZhi = p.dayPillar[0] + p.dayPillar[1];
  const mb = monthBranch(d);
  const mnum = monthNumOf(mb);
  const season = seasonOf(mnum);
  const banned = SI_FEI[season];
  const hit = banned.indexOf(dayGanZhi) >= 0;
  return {
    season,
    dayPillar: dayGanZhi,
    list: [{
      key: 'sifei',
      name: '四废',
      hit,
      detail: hit
        ? `今日${dayGanZhi}为${SEASON_TEXT[season]}季四废日，主百事无成，忌开市、嫁娶、动土、入宅。`
        : `${SEASON_TEXT[season]}季四废为${banned.join('、')}，今日不犯。`
    }],
    hits: hit ? ['四废'] : []
  };
}

/**
 * 逐事项吉时：在该事项可用的日子里挑最合适的时辰
 * 取黄道时（level=ji）按六合/三合加分排序；无吉时则退回六合/三合时辰
 */
function eventHours(shichen, eventKey) {
  const list = shichen || [];
  const good = list.filter((s) => s.level === 'ji').map((s) => ({
    name: s.name,
    pillar: s.pillar,
    god: s.god,
    reason: s.tip,
    score: 4 + (s.he ? 2 : 0) + (s.sanhe ? 1 : 0)
  })).sort((a, b) => b.score - a.score);
  if (good.length) return { key: eventKey, list: good.slice(0, 3), fallback: false };
  const soft = list.filter((s) => s.level === 'ping' && (s.he || s.sanhe)).map((s) => ({
    name: s.name, pillar: s.pillar, god: s.god, reason: s.tip, score: 1 + (s.he ? 2 : 0) + (s.sanhe ? 1 : 0)
  })).sort((a, b) => b.score - a.score);
  return { key: eventKey, list: soft.slice(0, 2), fallback: true };
}

/**
 * 日课总断
 * @param {Date} date
 * @param {string} sitMountain 坐山（二十四山）
 * @param {object} [opts] { ownerBirthYear } 宅主出生年，用于判冲本命
 */
function analyze(date, sitMountain, opts) {
  const d = date || new Date();
  const o = opts || {};
  const ownerBranch = o.ownerBranch || birthBranchOf(o.ownerBirthYear);
  const pillars = calculateFourPillars(d, 120);
  const jc = jianChuOf(d);
  const sui = taiSuiOfYear(d.getFullYear());
  const shichen = shichenList(d, sitMountain, ownerBranch);
  const directions = dailyCompassDirections(d);
  // 今日所值之神（十二时辰各值一神，按黄黑道归类）
  const todayGods = shichen.map((s) => s.god);

  const warnings = [];
  const mb = monthBranch(d);
  const monthBreak = zhiIndex(jc.dayZhi) === (zhiIndex(mb) + 6) % 12;
  if (monthBreak) {
    warnings.push(`日支${jc.dayZhi}直冲月建${mb}，犯月破大耗，诸事不宜，尤忌开市、嫁娶、动土。`);
  }
  if (sitMountain) {
    if (zhiIndex(sitMountain) === (zhiIndex(sui.taiSui.zhi) + 6) % 12) {
      warnings.push(`坐${sitMountain}山正冲流年太岁（${sui.taiSui.zhi}），大忌动土修造。`);
    }
    if (zhiIndex(jc.dayZhi) === (zhiIndex(sitMountain) + 6) % 12) {
      warnings.push(`日支${jc.dayZhi}冲坐山${sitMountain}，此日不宜为本宅修造。`);
    }
    const sanShaZhi = { 1: ['亥', '子', '丑'], 3: ['寅', '卯', '辰'], 7: ['申', '酉', '戌'], 9: ['巳', '午', '未'] }[sui.sanSha.palace] || [];
    if (sitMountain && sanShaZhi.indexOf(sitMountain) >= 0) {
      warnings.push(`坐山落流年三煞方（${sui.sanSha.text}），忌动土、破土。`);
    }
  }

  const best = shichen.filter((s) => s.level === 'ji');
  const worst = shichen.filter((s) => s.level === 'xiong');

  // 事项择日：建除宜忌 + 月破一票否决；坐山冲煞只约束动土、入宅、安葬
  const gods = auspiciousGods(d);
  const badDays = badDaysOf(d);
  const siFei = badDays.list[0] && badDays.list[0].hit;
  const sitBlocked = warnings.some((w) => w.indexOf('冲') >= 0 || w.indexOf('三煞') >= 0);
  const activities = ACTIVITIES.map((a) => {
    const byOfficer = a.good.indexOf(jc.name) >= 0;
    const hitBad = a.bad.indexOf(jc.name) >= 0;
    const needSit = ['dongtu', 'ruzhai', 'anzang'].indexOf(a.key) >= 0;
    const tianShe = gods.list.filter((g) => g.key === 'tianshe' && g.hit).length > 0;
    const blocked = (monthBreak || siFei) && !tianShe;
    const sitHit = needSit && sitBlocked;
    const ok = byOfficer && !blocked && !(needSit && sitBlocked);
    const hours = eventHours(shichen, a.key);
    return {
      key: a.key,
      name: a.name,
      level: ok ? 'ji' : (hitBad || blocked || (needSit && sitBlocked) ? 'xiong' : 'ping'),
      hours: hours.list,
      hoursFallback: hours.fallback,
      text: ok
        ? `可与：${jc.name}日合${a.name}，吉时取 ${hours.list.map((s) => s.name).join('、') || '本日无吉时'}。`
        : (blocked
          ? `${a.name}：本日${monthBreak ? '犯月破' : '为四废日'}${needSit && sitBlocked ? '且坐山冲煞' : ''}，另择。`
          : `${a.name}：${jc.name}日不宜${needSit && sitBlocked ? '，且坐山冲煞' : ''}，建议另择。`)
    };
  });

  const ownerChongHours = ownerBranch ? shichen.filter((s) => s.clashesOwner) : [];
  if (ownerBranch && ownerChongHours.length) {
    warnings.push(
      `${ownerChongHours.map((s) => s.name).join('、')}冲宅主本命${ownerBranch}（属${ZODIAC_BY_BRANCH[ownerBranch]}），重要事宜避开这些时辰。`
    );
  }

  return {
    dateText: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`,
    pillars,
    jianChu: jc,
    taiSui: sui,
    shichen,
    bestShichen: best,
    worstShichen: worst,
    warnings,
    yi: jc.info.yi,
    ji: jc.info.ji,
    monthBranch: mb,
    monthBreak,
    activities,
    gods: gods.list,
    godHits: gods.hits,
    godText: gods.text,
    badDays: badDays.list,
    badHits: badDays.hits,
    huangDaoHours: shichen.filter((s) => s.huangDao).map((s) => s.name),
    ownerBranch,
    ownerChongHours,
    directions,
    godGuide: GOD_OFFICER_INFO,
    todayGods,
    classicalSource: ruleReference('择日·建除十二神与黄黑道传承规则'),
    chongSha: {
      zhi: LIU_CHONG[jc.dayZhi],
      zodiac: ZODIAC_BY_BRANCH[LIU_CHONG[jc.dayZhi]],
      text: `日冲${LIU_CHONG[jc.dayZhi]}（属${ZODIAC_BY_BRANCH[LIU_CHONG[jc.dayZhi]]}），该属相者今日宜静，忌远行、签约、动土。`
    }
  };
}

/** 未来吉日：建除吉日且不冲坐山 */
function upcomingAuspicious(startDate, sitMountain, count) {
  const n = count || 8;
  const out = [];
  const d = new Date(startDate || Date.now());
  for (let i = 0; i < 90 && out.length < n; i++) {
    const cur = new Date(d.getTime() + i * 86400000);
    const jc = jianChuOf(cur);
    const pillars = calculateFourPillars(cur, 120);
    const ok = ['成', '开', '定', '满', '除'].indexOf(jc.name) >= 0;
    const chongSit = sitMountain ? zhiIndex(pillars.dayPillar[1]) === (zhiIndex(sitMountain) + 6) % 12 : false;
    if (ok && !chongSit) {
      out.push({
        date: `${cur.getMonth() + 1}月${cur.getDate()}日`,
        iso: `${cur.getFullYear()}-${String(cur.getMonth() + 1).padStart(2, '0')}-${String(cur.getDate()).padStart(2, '0')}`,
        jianChu: jc.name,
        dayPillar: pillars.dayPillar,
        yi: jc.info.yi
      });
    }
  }
  return out;
}

/**
 * 日课自检（对齐 iOS ZeRiWidgetBuilder.make）
 * 三大神煞自检 + 动土/安门专项 + 总评，供择日页与罗盘页「今日日课」卡使用
 * 返回 { suiPo, yuePo, sittingClash, sanShaHit, canGroundbreak, canInstallDoor,
 *        groundbreakBadge, installDoorBadge, overallStatus, isAuspicious,
 *        sittingTitle, detailsText, yi, ji, chongSha, directions }
 */
function dayCourseAudit(date, sitMountain, opts) {
  const d = date || new Date();
  const o = opts || {};
  const base = analyze(d, sitMountain, o);
  const suiZhi = base.taiSui.taiSui.zhi;
  const jc = base.jianChu;
  const mb = base.monthBranch;

  const suiPo = zhiIndex(jc.dayZhi) === (zhiIndex(suiZhi) + 6) % 12;
  const yuePo = zhiIndex(jc.dayZhi) === (zhiIndex(mb) + 6) % 12;
  const sittingClash = sitMountain
    ? zhiIndex(jc.dayZhi) === (zhiIndex(sitMountain) + 6) % 12
    : null;
  const sanShaZhi = { 1: ['亥', '子', '丑'], 3: ['寅', '卯', '辰'], 7: ['申', '酉', '戌'], 9: ['巳', '午', '未'] }[base.taiSui.sanSha.palace] || [];
  const sanShaHit = sitMountain ? sanShaZhi.indexOf(sitMountain) >= 0 : false;
  // 坐山正冲流年太岁：与「日支冲山」不同，属整年性禁忌，iOS 单列警告，此处一并纳入动土/安门否决
  const sittingTaiSui = sitMountain
    ? zhiIndex(sitMountain) === (zhiIndex(suiZhi) + 6) % 12
    : false;

  // 动土与安门：岁破、月破、冲山、坐山冲太岁、坐山落三煞，任一命中即不放行
  const blocked = suiPo || yuePo || sittingClash === true || sittingTaiSui || sanShaHit;
  const canGroundbreak = !blocked;
  const canInstallDoor = !blocked;

  const isAuspicious = jc.info.level === 'ji' && !blocked;
  const overallStatus = isAuspicious
    ? '吉日可用'
    : (jc.info.level === 'xiong' ? '凶日慎用' : (blocked ? '有煞慎用' : '平日平用'));

  const sittingTitle = sitMountain
    ? `${sitMountain}山${LIU_CHONG[sitMountain]}向`
    : '通用日课 · 未锁坐山';

  const selfChecks = [
    `岁破：${suiPo ? `犯（日支${jc.dayZhi}冲流年${suiZhi}）` : '无'}`,
    `月破：${yuePo ? `犯（日支${jc.dayZhi}冲月建${mb}）` : '无'}`,
    `冲山：${sitMountain ? (sittingClash ? `犯（日支${jc.dayZhi}冲${sitMountain}山）` : '坐山吉') : '未设坐山'}`
  ];
  if (sanShaHit) selfChecks.push(`三煞：犯（坐山落流年三煞方）`);
  if (sittingTaiSui) selfChecks.push(`太岁：坐山正冲流年${suiZhi}`);

  const detailsText = [
    `${base.dateText} · ${base.pillars.yearPillar} ${base.pillars.monthPillar} ${base.pillars.dayPillar}`,
    `${jc.name}日 · ${overallStatus}`,
    selfChecks.join(' ｜ '),
    `宜：${base.yi}`,
    `忌：${base.ji}`,
    base.warnings.length ? `提示：${base.warnings.join(' ')}` : ''
  ].filter(Boolean).join('\n');

  return {
    dateText: base.dateText,
    pillars: base.pillars,
    jianChu: jc,
    suiPo,
    yuePo,
    sittingClash,
    sanShaHit,
    canGroundbreak,
    canInstallDoor,
    groundbreakBadge: canGroundbreak ? '宜修造动土' : '忌动土起造',
    installDoorBadge: canInstallDoor ? '宜安门立向' : '忌安门修方',
    overallStatus,
    isAuspicious,
    sittingTitle,
    detailsText,
    yi: base.yi,
    ji: base.ji,
    chongSha: base.chongSha,
    directions: base.directions,
    warnings: base.warnings
  };
}

module.exports = {
  JIAN_CHU,
  JIAN_CHU_INFO,
  LIU_HE,
  SAN_HE,
  LIU_CHONG,
  ZODIAC_BY_BRANCH,
  GOD_NAMES,
  GOD_OFFICER_INFO,
  HUANG_DAO_INDEX,
  PALACE_GOD,
  WEALTH_PALACE_BY_STEM,
  JOY_PALACE_BY_STEM,
  ACTIVITIES,
  birthBranchOf,
  dailyCompassDirections,
  officerSummary,
  jianChuOf,
  xunKong,
  shichenList,
  auspiciousGods,
  badDaysOf,
  eventHours,
  analyze,
  dayCourseAudit,
  upcomingAuspicious
};
