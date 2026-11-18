/**
 * sanhe.js
 * 三合水法：杨公八路黄泉、八煞黄泉、四大局十二长生、纳水吉凶
 * 对齐 iOS Models/SanHeWaterEngine.swift 的黄泉与长生规则。
 */

const PHASES = ['长生', '沐浴', '冠带', '临官', '帝旺', '衰', '病', '死', '墓', '绝', '胎', '养'];

// 二十四山双山分组（每 2 山共 1 宫）
const SHUANG_SHAN = [
  { idx: 0, name: '壬子', zhi: '子', start: '壬' },
  { idx: 1, name: '癸丑', zhi: '丑', start: '癸' },
  { idx: 2, name: '艮寅', zhi: '寅', start: '艮' },
  { idx: 3, name: '甲卯', zhi: '卯', start: '甲' },
  { idx: 4, name: '乙辰', zhi: '辰', start: '乙' },
  { idx: 5, name: '巽巳', zhi: '巳', start: '巽' },
  { idx: 6, name: '丙午', zhi: '午', start: '丙' },
  { idx: 7, name: '丁未', zhi: '未', start: '丁' },
  { idx: 8, name: '坤申', zhi: '申', start: '坤' },
  { idx: 9, name: '庚酉', zhi: '酉', start: '庚' },
  { idx: 10, name: '辛戌', zhi: '戌', start: '辛' },
  { idx: 11, name: '乾亥', zhi: '亥', start: '乾' }
];

const MOUNTAIN_TO_SHAN = {};
SHUANG_SHAN.forEach((s) => {
  MOUNTAIN_TO_SHAN[s.start] = s;
  MOUNTAIN_TO_SHAN[s.zhi] = s;
});

// 二十四山顺时针（壬子癸丑艮寅甲卯乙辰巽巳丙午丁未坤申庚酉辛戌乾亥）
const MOUNTAIN_24 = [];
SHUANG_SHAN.forEach((s) => {
  MOUNTAIN_24.push(s.start, s.zhi);
});

/** 二十四山上取相邻山：step=-1 兼左（逆时针前一山），step=1 兼右 */
function nextMountain(mountain, step) {
  const i = MOUNTAIN_24.indexOf(mountain);
  if (i < 0) return mountain;
  const n = (i + (step >= 0 ? 1 : -1) + 24) % 24;
  return MOUNTAIN_24[n];
}

// 八路黄泉：按向首
const HUANG_QUAN_RULES = {
  庚: { taboo: '坤', text: '向首庚，坤方出水为杀人大黄泉（损丁败财）；坤方来水反为催官水。', danger: true },
  丁: { taboo: '坤', text: '向首丁，坤方出水为杀人大黄泉；坤方来水可救贫。', danger: true },
  坤: { favor: ['庚', '丁'], text: '坤向见庚方或丁方来水为救贫黄泉，大吉，人兴财旺。', danger: false },
  乙: { taboo: '巽', text: '向首乙，巽方出水为八煞黄泉（官非口舌、火灾损丁）；巽方来水吉。', danger: true },
  丙: { taboo: '巽', text: '向首丙，巽方出水为八煞黄泉；巽方来水可救贫。', danger: true },
  巽: { favor: ['乙', '丙'], text: '巽向见乙方或丙方来水为救贫黄泉，利科名文彩。', danger: false },
  甲: { taboo: '艮', text: '向首甲，艮方出水为黄泉杀水（残疾退财、官非）。', danger: true },
  癸: { taboo: '艮', text: '向首癸，艮方出水为黄泉杀水；艮方来水可救贫。', danger: true },
  艮: { favor: ['甲', '癸'], text: '艮向见甲方或癸方来水为救贫催官水，少男发达。', danger: false },
  辛: { taboo: '乾', text: '向首辛，乾方出水为破军黄泉（血症、横祸破败）。', danger: true },
  壬: { taboo: '乾', text: '向首壬，乾方出水为破军黄泉；乾方来水可救贫。', danger: true },
  乾: { favor: ['辛', '壬'], text: '乾向见辛方或壬方来水为救贫黄泉，长房显耀。', danger: false }
};

// 八煞黄泉：按坐卦
const BA_SHA_BY_GUA = {
  坎: { zhi: '辰', dir: '东南', text: '坎卦三山（壬子癸）煞在辰。忌辰方高压电塔、尖角怪石，犯之主肾疾损丁。' },
  坤: { zhi: '卯', dir: '正东', text: '坤卦三山（未坤申）煞在卯。忌正东冲射，主脾胃败坏、老母伤损。' },
  震: { zhi: '申', dir: '西南', text: '震卦三山（甲卯乙）煞在申。忌申方尖峰，主长房伤残、官非。' },
  巽: { zhi: '酉', dir: '正西', text: '巽卦三山（辰巽巳）煞在酉。忌酉金直冲，主妇女产厄、是非。' },
  乾: { zhi: '午', dir: '正南', text: '乾卦三山（戌乾亥）煞在午。忌午火反克天门，主心脑血光。' },
  兑: { zhi: '巳', dir: '东南', text: '兑卦三山（庚酉辛）煞在巳。忌巳火伤金，主少女不利、肺疾。' },
  艮: { zhi: '寅', dir: '东北', text: '艮卦三山（丑艮寅）煞在寅。忌寅方破山绝涧，损少男。' },
  离: { zhi: '亥', dir: '西北', text: '离卦三山（丙午丁）煞在亥。忌亥水冲射，主眼疾暗昧。' }
};

/* ---------- 古法原文与出处（对齐 iOS SanHeWaterEngine 的 sourceNote / 歌诀） ---------- */

const HUANG_QUAN_SONG = {
  title: '杨公八路黄泉歌',
  text: '庚丁坤上是黄泉，乙丙须防巽水先。甲癸向中休见艮，辛壬水路怕当乾。',
  source: '出处：杨筠松《八路黄泉歌》（传本有异文，以向首论来去水）。解释：歌诀中的“损丁、败财、横祸”是古法象徵，不是医疗、法律或财务预测；现场须核对排水方向与安全。'
};

const BA_SHA_SONG = {
  title: '八煞黄泉歌',
  text: '坎龙坤兔震山猴，巽鸡乾马兑蛇头，艮虎离猪为煞曜。',
  source: '出处：传统八煞黄泉诀（以坐卦论煞曜方位）。解释：煞方宜避高压、尖射、破面；不可据此替代工程安全评估。'
};

const WU_SHA_LUN = {
  title: '消砂五行口诀',
  text: '生我为生砂（催贵），同我为旺砂（旺丁财），克我为煞砂（大凶血光），我克为奴砂（得财帛），我生为泄砂（虚耗脱白）。',
  source: '出处：传统消砂五行口诀。解释：旺丁、血光与财帛语句是古法象徵，请现场核对安全，不是医疗或财务预测。'
};

// 十二长生水法断语（六类文案覆盖十二阶段，出处同「传统三合十二长生水法」）
const PHASE_LORE = {
  长生: '来水吉，大发富贵；去水凶，损丁破财。',
  沐浴: '桃花水，来去皆忌，主风流荡产。',
  冠带: '贵人来水，催官发甲；出水不利。',
  临官: '贵人来水，催官发甲；出水不利。',
  帝旺: '来水吉，大发富贵；去水凶，损丁破财。',
  衰: '去水吉，化煞为权；来水大凶，黄泉破局。',
  病: '去水吉，化煞为权；来水大凶，黄泉破局。',
  死: '去水吉，化煞为权；来水大凶，黄泉破局。',
  墓: '去水吉，化煞为权；来水大凶，黄泉破局。',
  绝: '去水吉，化煞为权；来水大凶，黄泉破局。',
  胎: '平和之位，宜缓流静蓄。',
  养: '巨门水，来去均宜，借库消水。'
};

const CHANG_SHENG_SOURCE = '出处：传统三合十二长生水法（传本有异文）。解释：其中富贵、损丁与病死等语句是古法象徵，不是医疗或财务预测；请现场检查排水与安全。';

// 四大局：三合局与长生起点
const FOUR_BUREAU = {
  water: { name: '水局', trio: ['申', '子', '辰'], startShanIdx: 8, start: '申' },
  wood: { name: '木局', trio: ['亥', '卯', '未'], startShanIdx: 11, start: '亥' },
  fire: { name: '火局', trio: ['寅', '午', '戌'], startShanIdx: 2, start: '寅' },
  metal: { name: '金局', trio: ['巳', '酉', '丑'], startShanIdx: 5, start: '巳' }
};

const GUA_BY_MOUNTAIN = {
  壬: '坎', 子: '坎', 癸: '坎',
  未: '坤', 坤: '坤', 申: '坤',
  甲: '震', 卯: '震', 乙: '震',
  辰: '巽', 巽: '巽', 巳: '巽',
  丙: '离', 午: '离', 丁: '离',
  戌: '乾', 乾: '乾', 亥: '乾',
  庚: '兑', 酉: '兑', 辛: '兑',
  丑: '艮', 艮: '艮', 寅: '艮'
};

/**
 * 坐山所属四大局：以「双山」定局（壬子同属水、癸丑同属金、艮寅同属火、甲卯同属木…）
 * 单以三合地支判局会把壬、艮、甲、巽、丙、丁、辛、乾等八山误落到金局，故按双山取局。
 */
function bureauOfMountain(mountain) {
  const shan = MOUNTAIN_TO_SHAN[mountain];
  if (!shan) return FOUR_BUREAU.water;
  const k = shan.idx % 4;
  if (k === 0) return FOUR_BUREAU.water;
  if (k === 1) return FOUR_BUREAU.metal;
  if (k === 2) return FOUR_BUREAU.fire;
  return FOUR_BUREAU.wood;
}

function shanIndexOf(mountain) {
  const s = MOUNTAIN_TO_SHAN[mountain];
  return s ? s.idx : 0;
}

/** 十二长生分布（以坐山所属局的长生位顺时针排十二阶段） */
function changShengTable(sitMountain) {
  const bureau = bureauOfMountain(sitMountain);
  const table = [];
  for (let i = 0; i < 12; i++) {
    const idx = (bureau.startShanIdx + i) % 12;
    table.push({
      phase: PHASES[i],
      shan: SHUANG_SHAN[idx].name,
      zhi: SHUANG_SHAN[idx].zhi,
      isGoodWater: i <= 4,
      isGoodDrain: i >= 5 && i <= 9,
      lore: PHASE_LORE[PHASES[i]]
    });
  }
  return { bureau, table };
}

/** 本坐山在十二长生中所处阶段 */
function phaseOfSitting(sitMountain, table) {
  const bureau = bureauOfMountain(sitMountain);
  const idx = shanIndexOf(sitMountain);
  const rel = (idx - bureau.startShanIdx + 12) % 12;
  return table[rel];
}

function huangQuan(faceMountain) {
  const rule = HUANG_QUAN_RULES[faceMountain];
  if (!rule) {
    return {
      level: 'none',
      danger: false,
      title: '不属八路黄泉正煞位',
      text: `向首${faceMountain}，不犯八路黄泉正煞。水法依三合十二长生消纳：宜长生、冠带、临官、帝旺方来水，宜衰、病、死、墓、绝方出水。`
    };
  }
  if (rule.favor) {
    return {
      level: 'favor',
      danger: false,
      title: '救贫黄泉水（吉）',
      text: rule.text
    };
  }
  return {
    level: 'danger',
    danger: true,
    title: `${rule.taboo}方出水·黄泉煞`,
    text: rule.text
  };
}

function baSha(sitMountain) {
  const gua = GUA_BY_MOUNTAIN[sitMountain] || '坎';
  const info = BA_SHA_BY_GUA[gua];
  return {
    gua,
    zhi: info.zhi,
    dir: info.dir,
    text: `当前坐${sitMountain}山（${gua}宫）。坐山煞曜在${info.dir}【${info.zhi}方】。${info.text}`
  };
}

/**
 * 三合总断
 * @param {string} sitMountain 坐山
 * @param {string} faceMountain 向首
 */
function analyze(sitMountain, faceMountain) {
  const cs = changShengTable(sitMountain);
  const phase = phaseOfSitting(sitMountain, cs.table);
  const hq = huangQuan(faceMountain);
  const bs = baSha(sitMountain);

  const waterAdvice = cs.table
    .filter((t) => t.isGoodWater)
    .map((t) => `${t.shan}（${t.phase}）`)
    .join('、');
  const drainAdvice = cs.table
    .filter((t) => t.isGoodDrain)
    .map((t) => `${t.shan}（${t.phase}）`)
    .join('、');

  let score = 0;
  if (hq.level === 'favor') score += 2;
  if (hq.level === 'danger') score -= 3;
  if (phase.isGoodWater) score += 1;
  if (phase.phase === '帝旺' || phase.phase === '临官') score += 1;
  if (phase.phase === '墓' || phase.phase === '绝' || phase.phase === '死') score -= 1;

  let verdict = '平';
  let verdictText = '水法中平，按四大局长生消纳即可，重在形峦与来去水实地核对。';
  if (score >= 3) {
    verdict = '吉';
    verdictText = '水法成局，坐山得长生旺气，向首合救贫黄泉，主丁财两旺。';
  } else if (score <= -2) {
    verdict = '凶';
    verdictText = '水法破局，坐山落死墓绝或向首犯黄泉煞，主退财损丁，宜改向或开门放水调和。';
  }

  return {
    sitMountain,
    faceMountain,
    bureau: cs.bureau,
    phase,
    table: cs.table,
    huangQuan: hq,
    baSha: bs,
    waterAdvice,
    drainAdvice,
    score,
    verdict,
    verdictText,
    songs: {
      huangQuan: HUANG_QUAN_SONG,
      baSha: BA_SHA_SONG,
      wuSha: WU_SHA_LUN
    },
    evidence: {
      huangQuan: HUANG_QUAN_SONG.source,
      baSha: BA_SHA_SONG.source,
      wuSha: WU_SHA_LUN.source,
      changSheng: CHANG_SHENG_SOURCE
    }
  };
}

/**
 * 来水 / 去水合参：在十二长生表上判定进水口与出水口是否合消纳之法
 * 规则依传统三合水法：长生至帝旺（前五位）宜来水，衰至绝（后五位）宜去水。
 * @param {Array} table changShengTable(...).table
 * @param {string} laiShan 来水双山名（如「壬子」）
 * @param {string} quShan 去水双山名
 */
function judgeWater(table, laiShan, quShan) {
  const list = Array.isArray(table) ? table : [];
  const find = (n) => list.filter((t) => t.shan === n)[0] || null;
  const lai = find(laiShan);
  const qu = find(quShan);
  if (!lai || !qu) return null;

  const laiOk = !!lai.isGoodWater;
  const quOk = !!qu.isGoodDrain;
  const goodLai = list.filter((t) => t.isGoodWater).map((t) => t.shan);
  const goodQu = list.filter((t) => t.isGoodDrain).map((t) => t.shan);

  const reasons = [
    `来水 ${lai.shan}（${lai.phase}）：${laiOk ? '合「长生·冠带·临官·帝旺」来水之法，主进气聚财。' : '落在衰病死墓绝，来水即带衰气，古法谓损丁破财。'}`
  ];
  if (lai.shan === qu.shan) {
    reasons.push('来水与去水同在一字，水口无从分界，实际多为一进一出同一缺口，宜分开立水口再论。');
  }
  reasons.push(
    `去水 ${qu.shan}（${qu.phase}）：${quOk ? '合「衰·病·死·墓·绝」去水之法，去水不见势，主财不泄。' : '落在生旺方，去水即泄旺气，古法谓财来财去、难聚。'}`
  );

  let level = '凶';
  if (laiOk && quOk) level = '吉';
  else if (laiOk || quOk) level = '平';

  let advice = '';
  if (!laiOk) advice += `来水宜改至 ${goodLai.slice(0, 3).join('、')} 之一；`;
  if (!quOk) advice += `去水宜改至 ${goodQu.slice(3, 6).join('、') || goodQu.slice(0, 3).join('、')} 之一；`;
  if (level === '吉') advice = '来去各得其位，无需改动；现场仍需核验实际排水坡度与防倒灌。';

  return {
    lai: { shan: lai.shan, phase: lai.phase, ok: laiOk, tag: laiOk ? '宜来水' : '不宜来水' },
    qu: { shan: qu.shan, phase: qu.phase, ok: quOk, tag: quOk ? '宜去水' : '不宜去水' },
    level,
    reasons,
    advice,
    goodLai,
    goodQu
  };
}

/**
 * 兼向水法：三合以「双山」定局，兼向只在双山内微调；越出双山即成出卦（大空亡），局随之改。
 * 判据：① 向首须与坐山成 180°（否则立向有误）；② 兼山与坐山是否同双山；
 * ③ 水口（来水 / 去水双山）归哪一局，据此定「以何局消纳」。
 * @param {string} sitMountain 坐山（二十四山之一）
 * @param {string} faceMountain 向首
 * @param {string} auxMountain 兼山（兼左 / 兼右的那一山；不兼传空）
 * @param {string} [laiShan] 来水双山名（如「坤申」）
 * @param {string} [quShan] 去水双山名
 */
function jianXiangWater(sitMountain, faceMountain, auxMountain, laiShan, quShan) {
  const sitIdx = MOUNTAIN_24.indexOf(sitMountain);
  const mainShan = MOUNTAIN_TO_SHAN[sitMountain] || SHUANG_SHAN[0];
  const auxShan = auxMountain ? (MOUNTAIN_TO_SHAN[auxMountain] || null) : null;
  const mainBureau = bureauOfMountain(sitMountain);
  const auxBureau = auxMountain ? bureauOfMountain(auxMountain) : null;

  // 向首须与坐山相对（差 12 山）
  const expectFace = sitIdx >= 0 ? MOUNTAIN_24[(sitIdx + 12) % 24] : '';
  const expectFaceAux = auxMountain ? MOUNTAIN_24[(MOUNTAIN_24.indexOf(auxMountain) + 12) % 24] : '';
  const faceOk = expectFace ? faceMountain === expectFace : false;

  const crossDouble = !!auxShan && auxShan.idx !== mainShan.idx;

  // 水口归属：按双山取局
  const points = [];
  [[laiShan, '来水'], [quShan, '去水']].forEach((pair) => {
    if (!pair[0]) return;
    const shan = SHUANG_SHAN.filter((s) => s.name === pair[0])[0];
    if (!shan) return;
    points.push({ kind: pair[1], shan: shan.name, bureau: bureauOfMountain(shan.start).name });
  });

  // 有水口则以水口归局者为「用局」，否则以坐山局为用
  const activeBureau = points.length ? points[0].bureau : mainBureau.name;
  const basis = points.length ? `以${points[0].kind}${points[0].shan}归${points[0].bureau}` : '以坐山定局';

  // 主局长生表上判来去水（水口齐全时）
  let water = null;
  if (laiShan && quShan) {
    const anchor = points.length ? (SHUANG_SHAN.filter((s) => s.name === laiShan)[0] || mainShan).start : sitMountain;
    water = judgeWater(changShengTable(anchor).table, laiShan, quShan);
  }

  let level = 'ji';
  let title = '正向 · 单局消纳';
  let text = '';
  let advice = '';

  if (!auxMountain) {
    level = faceOk ? 'ji' : 'ping';
    text = `坐${sitMountain}向${faceMountain}，不作兼向，属${mainBureau.name}，坐山在长生表上为「${phaseOfSitting(sitMountain, changShengTable(sitMountain).table).phase}」。`;
    if (!faceOk) text += `向首应为${expectFace}（坐${sitMountain}之对宫），今取${faceMountain}，立向不合，须先校正。`;
    advice = faceOk
      ? '按本局十二长生消纳：长生至帝旺宜来水，衰至墓绝宜去水。'
      : `改向至${expectFace}，再谈消纳；向不正则水法无从依托。`;
  } else if (!crossDouble) {
    level = faceOk ? 'ji' : 'ping';
    title = `兼${auxMountain} · 同局兼向`;
    text = `坐${sitMountain}兼${auxMountain}，两山同属${mainShan.name}双山、同为${mainBureau.name}，兼向不换局，只作度数微调（宜在双山 30° 内取 3° 以内）。`;
    if (!faceOk) text += `向首应为${expectFace}，今取${faceMountain}，立向与坐山不成 180°。`;
    advice = faceOk
      ? '可放心用兼向，水口仍按本局长生位取用；兼度勿越双山边界。'
      : `先改向至${expectFace}；若兼向成立，向首亦应为${expectFaceAux}。`;
  } else {
    level = 'xiong';
    title = `兼${auxMountain} · 出卦（跨双山 · 大空亡）`;
    text = `坐${sitMountain}兼${auxMountain}，${auxMountain}已出${mainShan.name}双山、入${auxShan.name}双山，局由${mainBureau.name}改为${auxBureau.name}，中间一线为空亡（古称大空亡／差错），主丁财不专、是非口舌。`;
    advice = `古法忌用此兼。宜改立正向${sitMountain}（向${expectFace}），或兼回${mainShan.name}双山内之山；确需用此兼，须以${auxBureau.name}长生重排来去水，勿混两局。`;
    if (points.length) text += ` ${basis}，故实际消纳以${activeBureau}为准。`;
  }

  // 水口合参并入结论
  if (water) {
    text += ` 来水${water.lai.shan}（${water.lai.phase}）${water.lai.ok ? '合宜来' : '不宜来'}；去水${water.qu.shan}（${water.qu.phase}）${water.qu.ok ? '合宜去' : '不宜去'}。`;
    advice += ` ${water.advice}`;
    if (water.level === '凶' && level !== 'xiong') level = 'ping';
  }

  return {
    sitMountain,
    faceMountain,
    auxMountain: auxMountain || '',
    mainShan: mainShan.name,
    auxShan: auxShan ? auxShan.name : '',
    mainBureau: mainBureau.name,
    auxBureau: auxBureau ? auxBureau.name : '',
    expectFace,
    expectFaceAux,
    faceOk,
    crossDouble,
    activeBureau,
    basis,
    points,
    water,
    level,
    title,
    text,
    advice
  };
}

module.exports = {
  PHASES,
  SHUANG_SHAN,
  MOUNTAIN_24,
  nextMountain,
  jianXiangWater,
  FOUR_BUREAU,
  HUANG_QUAN_RULES,
  BA_SHA_BY_GUA,
  HUANG_QUAN_SONG,
  BA_SHA_SONG,
  WU_SHA_LUN,
  PHASE_LORE,
  CHANG_SHENG_SOURCE,
  bureauOfMountain,
  changShengTable,
  phaseOfSitting,
  huangQuan,
  baSha,
  judgeWater,
  analyze
};
