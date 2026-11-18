/**
 * xuankong.js
 * 玄空飞星（沈氏玄空）排盘引擎：三元九运、下卦 / 替卦、山向飞星、81 组合断、流年五黄二黑
 * 数据与逻辑对齐 iOS Models/FlyingStarsEngine.swift 与 App 内置 Web 版玄空盘。
 */

const PALACE_INFO = {
  1: { name: '坎宫', dir: '正北', elem: '水' },
  2: { name: '坤宫', dir: '西南', elem: '土' },
  3: { name: '震宫', dir: '正东', elem: '木' },
  4: { name: '巽宫', dir: '东南', elem: '木' },
  5: { name: '中宫', dir: '中央', elem: '土' },
  6: { name: '乾宫', dir: '西北', elem: '金' },
  7: { name: '兑宫', dir: '正西', elem: '金' },
  8: { name: '艮宫', dir: '东北', elem: '土' },
  9: { name: '离宫', dir: '正南', elem: '火' }
};

// 洛书飞星步进顺序：中 5 → 乾 6 → 兑 7 → 艮 8 → 离 9 → 坎 1 → 坤 2 → 震 3 → 巽 4
const LUOSHU_ORDER = [5, 6, 7, 8, 9, 1, 2, 3, 4];

// 二十四山三元龙：地元(天元、人元)与阴阳
const MOUNTAIN_LONG_INFO = {
  子: { palace: 1, dragon: 'tian', yy: -1 },
  癸: { palace: 1, dragon: 'ren', yy: -1 },
  壬: { palace: 1, dragon: 'di', yy: 1 },
  丑: { palace: 8, dragon: 'di', yy: -1 },
  艮: { palace: 8, dragon: 'tian', yy: 1 },
  寅: { palace: 8, dragon: 'ren', yy: 1 },
  甲: { palace: 3, dragon: 'di', yy: 1 },
  卯: { palace: 3, dragon: 'tian', yy: -1 },
  乙: { palace: 3, dragon: 'ren', yy: -1 },
  辰: { palace: 4, dragon: 'di', yy: -1 },
  巽: { palace: 4, dragon: 'tian', yy: 1 },
  巳: { palace: 4, dragon: 'ren', yy: 1 },
  丙: { palace: 9, dragon: 'di', yy: 1 },
  午: { palace: 9, dragon: 'tian', yy: -1 },
  丁: { palace: 9, dragon: 'ren', yy: -1 },
  未: { palace: 2, dragon: 'di', yy: -1 },
  坤: { palace: 2, dragon: 'tian', yy: 1 },
  申: { palace: 2, dragon: 'ren', yy: 1 },
  庚: { palace: 7, dragon: 'di', yy: 1 },
  酉: { palace: 7, dragon: 'tian', yy: -1 },
  辛: { palace: 7, dragon: 'ren', yy: -1 },
  戌: { palace: 6, dragon: 'di', yy: -1 },
  乾: { palace: 6, dragon: 'tian', yy: 1 },
  亥: { palace: 6, dragon: 'ren', yy: 1 }
};

// 元旦盘各宫三元龙对应的二十四山
const PALACE_DRAGON_MOUNTAINS = {
  1: { di: '壬', tian: '子', ren: '癸' },
  2: { di: '未', tian: '坤', ren: '申' },
  3: { di: '甲', tian: '卯', ren: '乙' },
  4: { di: '辰', tian: '巽', ren: '巳' },
  6: { di: '戌', tian: '乾', ren: '亥' },
  7: { di: '庚', tian: '酉', ren: '辛' },
  8: { di: '丑', tian: '艮', ren: '寅' },
  9: { di: '丙', tian: '午', ren: '丁' }
};

// 替卦歌诀：子癸甲申贪狼一；壬卯乙未坤巨门二；乾亥辰巽巳武曲六；酉辛丑破军七；艮丙禄存三；庚丁右弼九
const TIGUA_MAP = {
  子: 1, 癸: 1, 甲: 1, 申: 1, 寅: 1,
  壬: 2, 卯: 2, 乙: 2, 未: 2, 坤: 2,
  乾: 6, 亥: 6, 辰: 6, 巽: 6, 巳: 6,
  酉: 7, 辛: 7, 丑: 7,
  艮: 3, 丙: 3,
  庚: 9, 丁: 9, 午: 9, 戌: 6
};

const STAR_NAMES = {
  1: '一白贪狼',
  2: '二黑巨门',
  3: '三碧禄存',
  4: '四绿文曲',
  5: '五黄廉贞',
  6: '六白武曲',
  7: '七赤破军',
  8: '八白左辅',
  9: '九紫右弼'
};

// 81 组山向星情断诀（覆核常用组合，未覆盖组合给出通用断法）
const LORE_81 = {
  11: '双一白汇聚，主聪慧多智、科名有成；水多则漂泊，需防耳疾肾亏。宜明堂见文笔峰。',
  12: '一白逢二黑，水土相克，主脾胃疾病、中男老母失和。宜静守，忌动土。',
  13: '一白水生三碧木，主长房得贵、官非亦随之，宜文不宜讼。',
  14: '一白生四绿，文星高照，主科考、学术、声名远播。',
  15: '一白逢五黄，水土交战，主重病、损丁。宜以金化土（铜器、六帝钱）。',
  16: '一六相逢为「虚联奎璧」，金水相生，科甲功名、武贵显赫。',
  17: '一白逢七赤，金水相生而带煞，主口舌、盗损，宜水制金。',
  18: '一八相会，土克水，主中男不利、财来财去，宜静水养气。',
  19: '一九相逢，水火既济，主喜庆、功名、添丁；见水更吉。',
  21: '二黑逢一白，病符遇水，主肾病、妇科隐患，宜铜葫芦化二黑。',
  22: '二黑重叠，病符聚结，主慢性病、孤寡，最忌动土。',
  23: '二黑逢三碧，木克土，主口舌官非、斗讼，宜红色调和水木。',
  24: '二黑逢四绿，木土相战，主脾胃虚弱、学业受阻，宜静。',
  25: '【二五交加】大凶，病符逢五黄，主重病、横祸、孤寡。严禁动土安门，宜六帝钱化泄。',
  26: '二黑逢六白，土生金，病气稍解，主老父操劳、财权渐旺。',
  27: '二黑逢七赤，土生金而带破，主口舌破财，防咽喉之疾。',
  28: '二黑逢八白，二八合十，主田宅安稳、财帛渐丰，宜静守。',
  29: '二黑逢九紫，火生土，病符得势，主眼疾、炎症，宜金化泄。',
  31: '三碧逢一白，水生木，主长房聪明、文书顺利。',
  32: '三碧逢二黑，木克土，主是非口舌、脾胃不安。',
  33: '三碧重叠，蚩尤相争，主官非、争斗、兄弟不和。',
  34: '三四相逢，木木同气，主文昌与声名俱进，唯须防漂泊。',
  35: '三碧逢五黄，木克土，五黄得势，主凶祸、官讼，宜铜器化之。',
  36: '三碧逢六白，金克木，主伤足、长子不利，忌金属尖角。',
  37: '【贼星穿心】三碧逢七赤，金木相战，主盗贼、官非、骨肉相残。宜安忍水化解。',
  38: '三碧逢八白，木克土，主小口不利、手足有伤，宜柔和布局。',
  39: '三碧逢九紫，木生火，主文明之喜，长房显达。',
  41: '四绿逢一白，水木相生，文星得润，主学业功名。',
  42: '四绿逢二黑，木克土，主文书阻滞、脾胃不舒。',
  43: '四绿逢三碧，木旺，主文昌大发，亦主漂泊思虑。',
  44: '四绿重叠，文昌聚气，主科名、文职，忌见尖角冲射。',
  45: '四绿逢五黄，木克土，主文书是非、疾病，宜金化解。',
  46: '四绿逢六白，金克木，主文昌受制、头面之伤。',
  47: '四绿逢七赤，金克木，主口舌、破财，女口不安。',
  48: '四绿逢八白，木克土，主小口学业受阻，宜静室养气。',
  49: '四绿逢九紫，木生火，主聪明文秀、喜庆加身。',
  51: '五黄逢一白，土克水，主病灾、中男不利，宜金泄土。',
  52: '【二五交加】大凶，五黄逢二黑，损丁败财、横祸。宜静制动，铜葫芦化之。',
  53: '五黄逢三碧，土木交争，主官非、伤灾，宜金化土。',
  54: '五黄逢四绿，土克木，主文书疾病、文昌受损。',
  55: '五黄重叠，关煞重重，主大凶、重病、横祸，严禁动土。',
  56: '五黄逢六白，土生金，煞气稍泄，主权威而与讼。',
  57: '五黄逢七赤，土生金，财旺带煞，主横财亦主伤灾。',
  58: '五黄逢八白，土厚，主田宅而病符潜藏，宜静守。',
  59: '五黄逢九紫，火生土，煞气更盛，主血症、火灾，宜水制。',
  61: '六白逢一白，「水地归元」，文武双全，主聪慧贤达。',
  62: '六白逢二黑，土生金，老父当权，主财权而兼病符。',
  63: '六白逢三碧，金克木，主伤足、长子受制，忌金属冲射。',
  64: '六白逢四绿，金克木，文昌受制，主头面之疾。',
  65: '六白逢五黄，土生金，主权威而招凶，宜静。',
  66: '六白重叠，金气过旺，主刚断而寡合，防肺疾、金属伤。',
  67: '【交剑煞】六白逢七赤，双金相搏，主血光、争斗、肺疾。',
  68: '六白逢八白，土金相生，主财富、权柄，田宅大发。',
  69: '六白逢九紫，火克金，主头面伤灾、官讼，宜土通关。',
  71: '七赤逢一白，金生水，主口才、财源，亦主桃花。',
  72: '七赤逢二黑，土生金，财旺带病符，防咽喉、破财。',
  73: '【交相攻伐】七赤逢三碧，金木相战，主刀兵、伤损、官非。',
  74: '七赤逢四绿，金克木，主女口不安、口舌破耗。',
  75: '七赤逢五黄，土生金，主横财与凶祸并见。',
  76: '【交剑煞】七赤逢六白，同类相戈，主是非口舌、夫妻龃龉。',
  77: '七赤重叠，破军聚煞，主盗贼、官非、破耗，宜静水化之。',
  78: '七赤逢八白，土生金，主财帛进益、田宅安稳。',
  79: '七赤逢九紫，火克金，主口舌、血症、损丁，宜土通关。',
  81: '八白逢一白，土克水，主财旺而中男不利，宜金泄土。',
  82: '八白逢二黑，二八合十，田宅安稳、财帛渐丰。',
  83: '八白逢三碧，木克土，主小口伤损、手足不宁。',
  84: '八白逢四绿，木克土，主学业受阻、脾胃不安。',
  85: '八白逢五黄，土气重叠，主病灾、田产纠纷，宜金化泄。',
  86: '八白逢六白，土生金，主富贵双全、权财并进。',
  87: '八白逢七赤，土生金，财源广进而带是非。',
  88: '八白重叠，当运旺气，主田宅大发、人丁兴旺（八运尤验）。',
  89: '【喜庆重重】八白逢九紫，火生土，主田宅骤发、进财添丁。',
  91: '九紫逢一白，水火既济，主喜庆、功名。',
  92: '九紫逢二黑，火生土，病符得势，主炎症、眼疾。',
  93: '九紫逢三碧，木生火，主文明喜庆、长房发达。',
  94: '九紫逢四绿，木生火，主文名、喜庆、婚姻。',
  95: '九紫逢五黄，火生土，五黄得势，主血症、火灾，忌红色。',
  96: '九紫逢六白，火克金，主头面伤、官讼，宜土通关。',
  97: '九紫逢七赤，火克金，主口舌、血症。',
  98: '九紫逢八白，火生土，家道隆昌、富贵吉祥。',
  99: '【九紫并照】当令双星汇聚，主喜气盈门、文彩显耀、英才辈出。'
};

// 父母三般卦（一四七 / 二五八 / 三六九）与连珠三般卦（九宫顺连）
const SAN_BAN_FUMU = [[1, 4, 7], [2, 5, 8], [3, 6, 9]];
const SAN_BAN_LIANZHU = [
  [1, 2, 3], [2, 3, 4], [3, 4, 5], [4, 5, 6], [5, 6, 7],
  [6, 7, 8], [7, 8, 9], [1, 8, 9], [1, 2, 9]
];

// 九星化解要点（按五行取用，对齐 iOS xkd_action_* 口径）
const STAR_REMEDY = {
  1: { elem: '水', text: '一白属水，宜黑蓝、见明水；忌厚土压水、忌红色电器长置。' },
  2: { elem: '土', text: '二黑病符属土，宜铜葫芦、六帝钱泄土；忌此方动土、忌堆放杂物。' },
  3: { elem: '木', text: '三碧是非属木，宜红紫通关、忌金属尖角冲射；忌在此方摆放刀剑。' },
  4: { elem: '木', text: '四绿文昌属木，宜富贵竹、文昌塔；忌枯枝、尖角与镜面反照。' },
  5: { elem: '土', text: '五黄关煞属土，宜六帝钱、铜铃、金器化土；严禁动土安门，忌红色催旺。' },
  6: { elem: '金', text: '六白属金，宜白金色、见水泄金；忌红色直冲、忌金属堆积过旺。' },
  7: { elem: '金', text: '七赤破军属金，宜安忍水、黑蓝器物化金；忌刀剑金属、忌红色催动。' },
  8: { elem: '土', text: '八白财星属土，宜白米黄、宜静守聚气；忌木重克土、忌此处空置。' },
  9: { elem: '火', text: '九紫喜庆属火，宜红色灯光催旺；忌水直冲、忌此处阴暗潮湿。' }
};

const SEVERITY_ORDER = [5, 2, 7, 3, 9, 6, 1, 4, 8];

const { forXuanKongPattern } = require('./traditional-evidence');

// 现场实用动作清单：逐条取自 iOS XuanKongPracticalAction / LocalizationManager
// `xkd_action_*`（简体中文口径，共 22 项），按「先核对事实、再低干预改善」排列。
// 原则：星数只提示关注方位，不据星数要求搬灶、移床或增设流水。
const PRACTICAL_ACTIONS = [
  { key: 'access', text: '清出门窗和通道，修好门扇异响，保持正常出入。' },
  { key: 'noise', text: '先处理持续噪音、振动；不额外增加水泵或音箱。' },
  { key: 'glare', text: '用遮阳或柔光灯减眩光，保留正常采光与通风。' },
  { key: 'sleep', text: '床边先降噪、遮眩光、稳床头；床位按实测标记复核。' },
  { key: 'kitchen', text: '先查灶边排烟、隔热与通道；不凭星数停用或搬灶。' },
  { key: 'window', text: '清理窗前遮挡，检查漏风与遮阳；保留必要换气。' },
  { key: 'study', text: '书桌避开通行动线，补足照明，减少工作时的打扰。' },
  { key: 'edges', text: '检查狭窄交汇处、门扇碰撞与家具尖角，先整理动线。' },
  { key: 'heat', text: '检查电器散热、插座负荷和热源间距，清走易燃杂物。' },
  { key: 'wet', text: '湿区先修漏水、补排风、做干湿分离；保留原有必要功能。' },
  { key: 'corner', text: '先核对真实外墙轮廓和立极点，确认是否确有缺角。' },
  { key: 'traffic', text: '外部道路影响先核对距离、车流与噪音，再考虑隔音遮挡。' },
  { key: 'wind', text: '现场核对夹缝来风，先调窗缝密封和可调挡风。' },
  { key: 'privacy', text: '复核窗外视线，用可调遮帘改善隐私，保留采光。' },
  { key: 'structure', text: '复核外部记录的实际形态和距离；建筑问题交专业人员检查。' },
  { key: 'water', text: '复核现有流水设备的噪音与漏水；先减扰，不新增设备。' },
  { key: 'work', text: '此方位列入施工复核；必要维修照常，先控噪、防尘。' },
  { key: 'separate', text: '通行活动与安静座位分开；轻分区，别堵通风和出口。' },
  { key: 'rest', text: '稳定座椅靠背，避开频繁走动处，保留柔和照明与通风。' },
  { key: 'everyday', text: '按房间用途处理漏水、昏暗与拥堵，保持整洁。' },
  { key: 'sanban', text: '逐宫核对用途与通行；先解决已记录的干扰，再安排动静分区。' },
  { key: 'qixing', text: '联看标出的三方门窗与通行，逐方核对开阔、靠实及干扰；不据此增加流水。' }
];

// 现场事实字段：与 iOS XuanKongSiteFact / XuanKongHomeContext 对齐。
// 小程序无 AR 自动采集，事实由用户提供（户型实测 / 人工记录），
// 因此缺失时不臆造结论，只输出「待核对」提示。
const SITE_FACT_FIELDS = {
  openBright: { label: '明堂开阔', hint: '门窗前方是否开阔、有正常采光' },
  solidBacking: { label: '背后靠实', hint: '座位/床头背后是否为实墙' },
  movingWater: { label: '动水设备', hint: '是否已有流水、鱼缸等设备及其噪音漏水' },
  noise: { label: '持续噪音', hint: '是否有持续噪音或振动源' },
  glare: { label: '眩光', hint: '是否有直射眩光或反光' },
  blockedAccess: { label: '通行受阻', hint: '门窗与通道是否拥堵' }
};

function sameTriple(a, b) {
  const x = a.slice().sort((m, n) => m - n);
  const y = b.slice().sort((m, n) => m - n);
  return x[0] === y[0] && x[1] === y[1] && x[2] === y[2];
}

/**
 * 父母三般卦 / 连珠三般卦判定（口径同 iOS FlyingStarsEngine.checkSanBanGua）
 * 九宫每宫的「运星·山星·向星」三元组须全部落在同一组三般卦内
 */
function checkSanBanGua(cells) {
  const triples = cells.map((c) => [c.yun, c.shan, c.xiang]);
  const allIn = (list) => triples.every((t) => list.some((g) => sameTriple(g, t)));
  if (allIn(SAN_BAN_FUMU)) return 'fumu';
  if (allIn(SAN_BAN_LIANZHU)) return 'lianzhu';
  return null;
}

/**
 * 七星打劫判定（口径同 iOS FlyingStarsEngine.checkQiXingDaJie）
 * 当旺向星到向，且离震乾 或 坎兑巽 三宫向星合成一四七/二五八/三六九
 */
function checkQiXingDaJie(cells, period, facePalace) {
  const byPalace = {};
  cells.forEach((c) => { byPalace[c.palace] = c; });
  if (!byPalace[facePalace] || byPalace[facePalace].xiang !== period) return null;
  const pick = (ids) => ids.map((p) => (byPalace[p] ? byPalace[p].xiang : 0));
  const zhen = pick([9, 3, 6]);
  const jia = pick([1, 7, 4]);
  if (SAN_BAN_FUMU.some((g) => sameTriple(g, zhen))) return { group: [9, 3, 6], groupText: '离、震、乾三宫', text: '七星打劫 · 离震乾三宫向星合成三般卦，当旺向星到向，可借三方旺气' };
  if (SAN_BAN_FUMU.some((g) => sameTriple(g, jia))) return { group: [1, 7, 4], groupText: '坎、兑、巽三宫', text: '七星打劫 · 坎兑巽三宫向星合成三般卦，当旺向星到向，可借三方旺气' };
  return null;
}

/** 单宫化解动作：取该宫山/向星中最凶者立论 */
function remedyFor(shan, xiang) {
  const worst = SEVERITY_ORDER.filter((s) => s === shan || s === xiang)[0];
  const r = STAR_REMEDY[worst];
  return {
    culprit: worst,
    culpritName: STAR_NAMES[worst],
    elem: r.elem,
    text: `以${r.elem}法调之：${r.text}`
  };
}

/**
 * 流年 / 流月紫白叠加（对齐 iOS 每宫带 yearStar / monthStar 的用法）
 * @param {object} chart calculateChart 结果
 * @param {number} year 流年
 * @param {number} [month] 节气月（寅=1…丑=12），缺省取当前
 */
function withFlow(chart, year, month) {
  const { monthStar, solarMonthFromTerm, solarTermIndex } = require('./zibai');
  const y = year || new Date().getFullYear();
  const m = month || solarMonthFromTerm(solarTermIndex(new Date()));
  const yearMap = flyNineStars(yearStar(y), true);
  const monthMap = flyNineStars(monthStar(y, m), true);
  const cells = chart.cells.map((c) => {
    const annual = yearMap[c.palace];
    const monthly = monthMap[c.palace];
    let flowNote = '';
    if (annual === 5) flowNote = '流年五黄到宫：忌动土、装修、开门，宜六帝钱化煞。';
    else if (annual === 2) flowNote = '流年二黑到宫：病符加临，宜铜葫芦泄土，注意脾胃与妇科。';
    else if (annual === 7) flowNote = '流年七赤到宫：口舌破耗，忌金属尖角、忌此方设门路。';
    else if (annual === chart.period) flowNote = '流年当旺星到宫：可催财丁，宜聚气不宜空旷。';
    else if (monthly === 5) flowNote = '流月五黄到宫：本月忌动土修造，宜静不宜动。';
    else flowNote = '流年流月无大煞，可按山向星情布置。';
    return Object.assign({}, c, {
      annual,
      monthly,
      flowNote,
      flowAlarm: annual === 5 || annual === 2,
      comboFlow: `${c.combo} · 年${annual} 月${monthly}`
    });
  });
  return {
    year: y,
    month: m,
    yearStar: yearStar(y),
    monthStar: monthStar(y, m),
    yearStars: yearMap,
    monthStars: monthMap,
    cells
  };
}


function flyNineStars(startStar, forward) {
  const map = {};
  let star = startStar;
  for (let i = 0; i < 9; i++) {
    map[LUOSHU_ORDER[i]] = star;
    star = forward ? (star % 9) + 1 : (star - 1 < 1 ? 9 : star - 1);
  }
  return map;
}

/** 三元九运：1864 年起一运，每运 20 年 */
function periodForYear(year) {
  const p = Math.floor((year - 1864) / 20) + 1;
  return Math.min(9, Math.max(1, p));
}

function periodRange(period) {
  const startYear = 1864 + (period - 1) * 20;
  return { start: startYear, end: startYear + 19 };
}

function periodLabel(period) {
  const names = ['一运', '二运', '三运', '四运', '五运', '六运', '七运', '八运', '九运'];
  return names[period - 1] || `${period}运`;
}

/**
 * 玄空排盘
 * @param {object} opts
 * @param {string} opts.sitMountain 坐山（二十四山之一）
 * @param {string} opts.faceMountain 向首
 * @param {boolean} [opts.isTiGua] 是否兼向起替卦
 * @param {number} [opts.period] 运，缺省按当前年份
 * @param {number} [opts.year] 流年，缺省当前年
 */
function calculateChart(opts) {
  const sitMountain = opts.sitMountain;
  const faceMountain = opts.faceMountain;
  const sitInfo = MOUNTAIN_LONG_INFO[sitMountain];
  const faceInfo = MOUNTAIN_LONG_INFO[faceMountain];
  if (!sitInfo || !faceInfo) throw new Error('invalid mountain');

  const period = opts.period || periodForYear(opts.year || new Date().getFullYear());
  const isTiGua = !!opts.isTiGua;
  const yunStars = flyNineStars(period, true);

  const sitPalace = sitInfo.palace;
  const facePalace = faceInfo.palace;

  // 山星：坐宫运星入中，按同元龙阴阳定顺逆
  let shanStar = yunStars[sitPalace];
  if (isTiGua) shanStar = TIGUA_MAP[sitMountain] || shanStar;
  const shanForward = resolveForward(shanStar, sitMountain, sitInfo);

  let xiangStar = yunStars[facePalace];
  if (isTiGua) xiangStar = TIGUA_MAP[faceMountain] || xiangStar;
  const xiangForward = resolveForward(xiangStar, faceMountain, faceInfo);

  const shanStars = flyNineStars(shanStar, shanForward);
  const xiangStars = flyNineStars(xiangStar, xiangForward);

  // 格局判定
  const sitShan = shanStars[sitPalace];
  const sitXiang = xiangStars[sitPalace];
  const faceShan = shanStars[facePalace];
  const faceXiang = xiangStars[facePalace];

  let pattern = 'regular';
  let patternText = '一般格局 · 按九宫星情分区布局';
  let patternLevel = 'ping';
  if (sitShan === period && faceXiang === period) {
    pattern = 'wang_shan_wang_xiang';
    patternText = '旺山旺向 · 丁财两旺，坐后有山、向首有水最验';
    patternLevel = 'ji';
  } else if (faceShan === period && faceXiang === period) {
    pattern = 'shuang_xing_dao_xiang';
    patternText = '双星到向 · 旺财损丁，前宜见水、后宜空';
    patternLevel = 'ji';
  } else if (sitShan === period && sitXiang === period) {
    pattern = 'shuang_xing_dao_zuo';
    patternText = '双星到坐 · 旺丁败财，后宜聚水、前宜见山';
    patternLevel = 'xiong';
  } else if (faceShan === period && sitXiang === period) {
    pattern = 'shang_shan_xia_shui';
    patternText = '上山下水 · 丁财两退，需平洋倒杖或改向';
    patternLevel = 'xiong';
  }

  // 九宫单元格
  const cells = [];
  const displayOrder = [4, 9, 2, 3, 5, 7, 8, 1, 6];
  displayOrder.forEach((pid) => {
    const info = PALACE_INFO[pid];
    const s = shanStars[pid];
    const x = xiangStars[pid];
    const y = yunStars[pid];
    const remedy = remedyFor(s, x);
    cells.push({
      palace: pid,
      name: info.name,
      dir: info.dir,
      elem: info.elem,
      yun: y,
      shan: s,
      xiang: x,
      combo: `${s}${x}`,
      lore: LORE_81[`${s}${x}`] || `山星${s}（${STAR_NAMES[s]}）配向星${x}（${STAR_NAMES[x]}），按五行生克与砂水虚实定吉凶。`,
      action: remedy.text,
      culprit: remedy.culprit,
      culpritName: remedy.culpritName,
      isCenter: pid === 5,
      alarm25: (s === 2 && x === 5) || (s === 5 && x === 2)
    });
  });

  const sanBan = checkSanBanGua(cells);
  const qiXing = checkQiXingDaJie(cells, period, facePalace);
  const sanBanText = sanBan === 'fumu'
    ? '父母三般卦 · 九宫运山向三星各归 147／258／369，主三元不败、福力绵长，宜守成不宜轻改。'
    : sanBan === 'lianzhu'
      ? '连珠三般卦 · 九宫三星连珠成串，主气脉贯通、财丁渐进，须防一处破局则全局断链。'
      : '非三般卦 · 按九宫山向星逐宫调理。';

  return {
    period,
    periodText: periodLabel(period),
    periodRange: periodRange(period),
    isTiGua,
    chartTypeText: isTiGua ? '替卦（兼向）' : '下卦（正针）',
    sitMountain,
    faceMountain,
    sitPalace,
    facePalace,
    yunStars,
    shanStar,
    xiangStar,
    shanForward,
    xiangForward,
    pattern,
    patternText,
    patternLevel,
    sanBan,
    sanBanText,
    qiXing,
    qiXingText: qiXing ? qiXing.text : '未成七星打劫局 · 当旺向星未到向，或三宫向星未合三般卦。',
    cells,
    siteFactFields: SITE_FACT_FIELDS,
    practicalActions: PRACTICAL_ACTIONS,
    evidence: forXuanKongPattern(`${patternText} · 坐${sitMountain} 向${faceMountain}`)
  };
}

/** 山星 / 向星顺逆：按该星所属元旦盘宫位中与坐山同元龙之山的阴阳 */
function resolveForward(star, mountain, info) {
  let yy = info.yy;
  // 五黄入中无元旦盘寄宫，直接按坐山 / 向首本山的阴阳定顺逆（阳顺阴逆）
  if (star === 5) {
    return info.yy > 0;
  }
  const dragon = PALACE_DRAGON_MOUNTAINS[star];
  if (dragon && dragon[info.dragon]) {
    const target = MOUNTAIN_LONG_INFO[dragon[info.dragon]];
    if (target) yy = target.yy;
  }
  return yy > 0;
}

/** 流年紫白入中星（年紫白） */
function yearStar(year) {
  let s = (65 - (year % 9)) % 9;
  return s === 0 ? 9 : s;
}

/** 五黄 / 二黑 流年落宫 */
function annualFiveYellow(year) {
  const map = flyNineStars(yearStar(year), true);
  let five = 5;
  let two = 2;
  Object.keys(map).forEach((p) => {
    if (map[p] === 5) five = parseInt(p, 10);
    if (map[p] === 2) two = parseInt(p, 10);
  });
  return {
    year,
    yearStar: yearStar(year),
    yearStars: map,
    fivePalace: five,
    fiveName: PALACE_INFO[five].name,
    twoPalace: two,
    twoName: PALACE_INFO[two].name
  };
}

module.exports = {
  PALACE_INFO,
  LUOSHU_ORDER,
  MOUNTAIN_LONG_INFO,
  PALACE_DRAGON_MOUNTAINS,
  TIGUA_MAP,
  STAR_NAMES,
  STAR_REMEDY,
  LORE_81,
  PRACTICAL_ACTIONS,
  SITE_FACT_FIELDS,
  SAN_BAN_FUMU,
  SAN_BAN_LIANZHU,
  flyNineStars,
  periodForYear,
  periodRange,
  periodLabel,
  calculateChart,
  checkSanBanGua,
  checkQiXingDaJie,
  remedyFor,
  withFlow,
  yearStar,
  annualFiveYellow
};
