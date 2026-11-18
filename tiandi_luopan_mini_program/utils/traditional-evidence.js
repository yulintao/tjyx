/**
 * traditional-evidence.js
 * 古籍引用与应用规则的区分标注，移植自 iOS Models/TraditionalEvidence.swift。
 *
 * 口径：古籍引文只支持对应概念；九星条件、格局判定与房间调整属应用规则归纳，
 * 不冒充古籍原文。维基文库链接固定到已审校的旧版本（oldid），避免内容漂移。
 */

const SOURCE_URLS = {
  mountainWater: 'https://zh.wikisource.org/w/index.php?oldid=1557328',
  elements: 'https://zh.wikisource.org/w/index.php?oldid=7915687'
};

const SCOPE_NOTE = '古籍引文支持对应概念；九星条件和房间调整另按应用规则归纳。';

const CLASSIC_QUOTES = {
  mountainWater: '山上龍神不下水，水裏龍神不上山。',
  generating: ['木生火', '火生土', '土生金', '金生水', '水生木'],
  controlling: ['木剋土', '火剋金', '土剋水', '金剋木', '水剋火']
};

/**
 * 玄空格局证据链：一条古籍引文 + 一条当前格局规则。
 * @param {string} context 当前格局/方位描述
 */
function forXuanKongPattern(context) {
  return [
    {
      id: 'classic.mountain_water',
      kind: 'classic',
      title: '《青囊序》· 山水分工原则',
      quotes: [CLASSIC_QUOTES.mountainWater],
      matches: [context],
      sourceUrl: SOURCE_URLS.mountainWater
    },
    {
      id: 'pattern.rule',
      kind: 'rule',
      title: '玄空山向盘 · 当前格局判定',
      quotes: [],
      matches: [context],
      sourceUrl: null
    },
    {
      id: 'scope.note',
      kind: 'rule',
      title: SCOPE_NOTE,
      quotes: [],
      matches: [],
      sourceUrl: null
    }
  ];
}

/**
 * 五行关系证据链：相生/相剋引文 + 应用规则。
 * @param {number} a 星数 1-9
 * @param {number} b 星数 1-9
 * @param {string} match 当前匹配描述
 */
function forElementPair(a, b, match) {
  const elementOf = (n) => [null, '水', '土', '木', '木', '土', '金', '金', '土', '火'][n];
  const first = elementOf(a);
  const second = elementOf(b);
  const refs = [];
  const generating = { 木: '火', 火: '土', 土: '金', 金: '水', 水: '木' };
  const controlling = { 木: '土', 土: '水', 水: '火', 火: '金', 金: '木' };
  if (generating[first] === second || generating[second] === first) {
    refs.push({
      id: 'elements.generating',
      kind: 'classic',
      title: '五行相生',
      quotes: [generating[first] === second ? `${first}生${second}` : `${second}生${first}`],
      matches: [match],
      sourceUrl: SOURCE_URLS.elements
    });
  }
  if (controlling[first] === second || controlling[second] === first) {
    refs.push({
      id: 'elements.controlling',
      kind: 'classic',
      title: '五行相剋',
      quotes: [controlling[first] === second ? `${first}剋${second}` : `${second}剋${first}`],
      matches: [match],
      sourceUrl: SOURCE_URLS.elements
    });
  }
  refs.push({
    id: 'scope.note',
    kind: 'rule',
    title: SCOPE_NOTE,
    quotes: [],
    matches: [],
    sourceUrl: null
  });
  return refs;
}

/** 择日规则出处：与 iOS QimenEngine.classicalSourceNote 同一口径。 */
function ruleReference(title, scope) {
  return {
    id: 'rule.reference',
    kind: 'rule',
    title: title || '传承规则',
    quotes: [],
    matches: [],
    sourceUrl: null,
    scope: scope || SCOPE_NOTE
  };
}

// ===== 以下 1:1 移植自 iOS Models/TraditionalEvidence.swift =====

// 星数→五行索引：0 木 1 火 2 土 3 金 4 水（生成序 木→火→土→金→水）
const STAR_ELEMENT_INDEX = { 1: 4, 2: 2, 3: 0, 4: 0, 5: 2, 6: 3, 7: 3, 8: 2, 9: 1 };
const GENERATING_QUOTES = ['木生火', '火生土', '土生金', '金生水', '水生木'];
const CONTROLLING_QUOTES = ['木剋土', '火剋金', '土剋水', '金剋木', '水剋火'];

// 星组 motif 的简体应用规则标题（iOS 用 titleKey，这里直接落简体文案）
const PAIR_RULE_TITLES = {
  same: '同气同宫',
  two: '二黑病符',
  five: '五黄关煞',
  five_five: '五五交并',
  two_five: '二五交加',
  one_four: '一四文昌',
  one_six: '一六武曲文昌',
  three_seven: '三七穿心',
  seven_nine: '七九火燥',
  nine_nine: '九九重阳'
};

/** XuanKongStarPair：81 组星对的确定五行关系 + motif 语义标签 */
function starPair(first, second) {
  const elements = STAR_ELEMENT_INDEX;
  const a = elements[first] === undefined ? 2 : elements[first];
  const b = elements[second] === undefined ? 2 : elements[second];
  let relation;
  if (a === b) relation = 'same';
  else if ((a + 1) % 5 === b) relation = 'firstGeneratesSecond';
  else if ((b + 1) % 5 === a) relation = 'secondGeneratesFirst';
  else if ((a + 2) % 5 === b) relation = 'firstControlsSecond';
  else relation = 'secondControlsFirst';

  const s = [first, second];
  const set = [first, second].filter((v, i, arr) => arr.indexOf(v) === i).sort();
  const isPair = (x, y) => set.length === 2 && set[0] === x && set[1] === y;
  return {
    first, second,
    firstElementIndex: elements[first],
    secondElementIndex: elements[second],
    relation,
    relationTitle: {
      same: '比和同气', firstGeneratesSecond: '我生', secondGeneratesFirst: '生我',
      firstControlsSecond: '我克', secondControlsFirst: '克我'
    }[relation],
    hasEarthCaution: s.indexOf(2) >= 0 || s.indexOf(5) >= 0,
    isStudy: isPair(1, 4) || isPair(1, 6),
    isFriction: isPair(3, 7),
    isHeat: isPair(7, 9) || (first === 9 && second === 9)
  };
}

function mergeEvidence(references) {
  const result = [];
  references.forEach((ref) => {
    const i = result.map((r) => r.id).indexOf(ref.id);
    if (i >= 0) {
      (ref.quotes || []).forEach((q) => { if (result[i].quotes.indexOf(q) < 0) result[i].quotes.push(q); });
      (ref.matches || []).forEach((m) => { if (result[i].matches.indexOf(m) < 0) result[i].matches.push(m); });
    } else {
      result.push(Object.assign({}, ref, { quotes: (ref.quotes || []).slice(), matches: (ref.matches || []).slice() }));
    }
  });
  return result;
}

function evidenceText(references) {
  return mergeEvidence(references).map((r) => {
    const head = (r.kind === 'classic' ? '古籍引文' : '应用规则') + ' · ' + r.title;
    const lines = [head];
    if (r.quotes.length) lines.push('“' + r.quotes.join('；') + '”');
    if (r.matches.length) lines.push('对应：' + r.matches.join('；'));
    return lines.join('\n');
  }).join('\n\n');
}

/** TraditionalEvidenceCatalog.pair：星对 → 证据链（古籍引文 + 应用规则） */
function pairEvidence(first, second, context) {
  const pair = starPair(first, second);
  if (pair.firstElementIndex === undefined || pair.secondElementIndex === undefined) return [];
  const a = pair.firstElementIndex;
  const b = pair.secondElementIndex;
  const match = `${context || ''} ${first}/${second}`;
  const refs = [];
  const rule = (id, title) => refs.push({ id, kind: 'rule', title, quotes: [], matches: [match], sourceUrl: null });

  if (pair.relation === 'same') {
    rule('elements.same', PAIR_RULE_TITLES.same);
  } else if (pair.relation === 'firstGeneratesSecond' || pair.relation === 'secondGeneratesFirst') {
    const idx = pair.relation === 'firstGeneratesSecond' ? a : b;
    refs.push({ id: 'elements.generating', kind: 'classic', title: '五行相生',
      quotes: [GENERATING_QUOTES[idx]], matches: [match], sourceUrl: SOURCE_URLS.elements });
  } else {
    const idx = pair.relation === 'firstControlsSecond' ? a : b;
    refs.push({ id: 'elements.controlling', kind: 'classic', title: '五行相剋',
      quotes: [CONTROLLING_QUOTES[idx]], matches: [match], sourceUrl: SOURCE_URLS.elements });
  }

  if (first === 2 || second === 2) rule('stars.two', PAIR_RULE_TITLES.two);
  if (first === 5 || second === 5) rule('stars.five', PAIR_RULE_TITLES.five);
  if (first === 5 && second === 5) rule('pair.five_five', PAIR_RULE_TITLES.five_five);
  if ((first === 2 && second === 5) || (first === 5 && second === 2)) rule('pair.two_five', PAIR_RULE_TITLES.two_five);
  if ((first === 1 && second === 4) || (first === 4 && second === 1)) rule('pair.one_four', PAIR_RULE_TITLES.one_four);
  if ((first === 1 && second === 6) || (first === 6 && second === 1)) rule('pair.one_six', PAIR_RULE_TITLES.one_six);
  if ((first === 3 && second === 7) || (first === 7 && second === 3)) rule('pair.three_seven', PAIR_RULE_TITLES.three_seven);
  if ((first === 7 && second === 9) || (first === 9 && second === 7)) rule('pair.seven_nine', PAIR_RULE_TITLES.seven_nine);
  if (first === 9 && second === 9) rule('pair.nine_nine', PAIR_RULE_TITLES.nine_nine);
  return refs;
}

/** TraditionalEvidenceCatalog.purpleWhite：紫白客星年份/月份 → 证据链 */
function purpleWhiteEvidence(year, month, palace) {
  const match = `${palace || ''} · 客星 ${year}/${month}`;
  const refs = pairEvidence(year, month, palace + ' · 客星');
  refs.push({ id: 'purplewhite.timing', kind: 'rule', title: '客星应期', quotes: [], matches: [match], sourceUrl: null });
  if (year !== 2 && year !== 5 && month !== 2 && month !== 5) {
    let title;
    if (year === 9) title = '九紫当令';
    else if (year === 8) title = '八白当令';
    else if ([1, 4, 6].indexOf(year) >= 0) title = '文昌贵气';
    else title = '平年常应';
    refs.push({ id: `purplewhite.year.${year}`, kind: 'rule', title, quotes: [], matches: [match], sourceUrl: null });
  }
  return mergeEvidence(refs);
}

module.exports = {
  SOURCE_URLS,
  SCOPE_NOTE,
  CLASSIC_QUOTES,
  forXuanKongPattern,
  forElementPair,
  ruleReference,
  STAR_ELEMENT_INDEX,
  starPair,
  mergeEvidence,
  evidenceText,
  pairEvidence,
  purpleWhiteEvidence
};
