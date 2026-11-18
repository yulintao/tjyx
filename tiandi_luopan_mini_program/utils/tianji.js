/**
 * tianji.js
 * 天机数：把玄空、八宅、紫白、三合、择日、奇门的结果汇总为一份「天机长卷」报告
 */

const XK = require('./xuankong');
const BZ = require('./bazhai');
const ZB = require('./zibai');
const SH = require('./sanhe');
const ZR = require('./zeri');
const QM = require('./qimen');
const SHA = require('./sha');
const FP = require('./floorplan');

const SHA_ITEMS = SHA.ITEMS || [];
const SEVERITY_RANK = { critical: 0, warning: 1, minor: 2, notice: 3 };
const SEVERITY_CN = { critical: '重', warning: '中', minor: '轻', notice: '提示' };

const MOUNTAIN_TO_PALACE = {
  壬: '坎', 子: '坎', 癸: '坎',
  未: '坤', 坤: '坤', 申: '坤',
  甲: '震', 卯: '震', 乙: '震',
  辰: '巽', 巽: '巽', 巳: '巽',
  丙: '离', 午: '离', 丁: '离',
  戌: '乾', 乾: '乾', 亥: '乾',
  庚: '兑', 酉: '兑', 辛: '兑',
  丑: '艮', 艮: '艮', 寅: '艮'
};

const PALACE_NUM = { 坎: 1, 坤: 2, 震: 3, 巽: 4, 乾: 6, 兑: 7, 艮: 8, 离: 9 };

/**
 * 生成天机长卷
 * @param {object} opts
 * @param {string} opts.sitMountain
 * @param {string} opts.faceMountain
 * @param {Date} [opts.date]
 * @param {number} [opts.period]
 * @param {Array} [opts.members] [{role, birthYear, gender}]
 */
function buildScroll(opts) {
  const date = opts.date || new Date();
  const sit = opts.sitMountain;
  const face = opts.faceMountain;
  const period = opts.period || XK.periodForYear(date.getFullYear());

  const xk = XK.calculateChart({ sitMountain: sit, faceMountain: face, period });
  const zb = ZB.calculateChart(date, { sitPalace: xk.sitPalace, facePalace: xk.facePalace });
  const sh = SH.analyze(sit, face);
  const zr = ZR.analyze(date, sit);
  const qm = QM.calculateChart(date);
  const houseGua = MOUNTAIN_TO_PALACE[sit];
  const bzHouse = BZ.roamStars(PALACE_NUM[houseGua]);

  const sections = [];

  sections.push({
    key: 'overview',
    title: '形势总览',
    rows: [
      `坐山：${sit}山（${XK.PALACE_INFO[xk.sitPalace].name}）`,
      `向首：${face}向（${XK.PALACE_INFO[xk.facePalace].name}）`,
      `元运：${xk.periodText}（${xk.periodRange.start}–${xk.periodRange.end}）`,
      `排盘：${xk.chartTypeText}`,
      `格局：${xk.patternText}`
    ]
  });

  sections.push({
    key: 'xuankong',
    title: '玄空九宫',
    rows: [
      `运星入中：${xk.shanStar} / ${xk.xiangStar}`,
      `坐宫山星：${xk.cells.find((c) => c.palace === xk.sitPalace).shan}，向宫向星：${xk.cells.find((c) => c.palace === xk.facePalace).xiang}`,
      ...[5, 6, 7, 8, 9, 1, 2, 3, 4].map((p) => {
        const c = xk.cells.find((x) => x.palace === p);
        return `${c.name}（${c.dir}） 运${c.yun} 山${c.shan} 向${c.xiang}`;
      })
    ]
  });

  sections.push({
    key: 'bazhai',
    title: '八宅宅命',
    rows: [
      `宅卦：${bzHouse.gua}宅（${bzHouse.group}）`,
      `吉方：${bzHouse.cells.filter((c) => c.type === 'ji').map((c) => c.palace + c.star).join('、')}`,
      `凶方：${bzHouse.cells.filter((c) => c.type === 'xiong').map((c) => c.palace + c.star).join('、')}`
    ]
  });

  if (opts.members && opts.members.length) {
    const rooms = BZ.assignRooms(opts.members, houseGua);
    sections.push({
      key: 'members',
      title: '家人配房',
      rows: rooms.map((r) => r.text)
    });
  }

  sections.push({
    key: 'zibai',
    title: '流年紫白',
    rows: [
      `${zb.year}年${zb.beforeLiChun ? '（立春前，仍属上年）' : ''}：年星 ${zb.yearCenter} 入中，月星 ${zb.monthCenter} 入中`,
      `五黄落 ${XK.PALACE_INFO[zb.fivePalace].name}，二黑落 ${XK.PALACE_INFO[zb.twoPalace].name}`,
      ...zb.warnings,
      ...(zb.hits.length ? [`坐向提示：${zb.hits.join('；')}`] : [])
    ]
  });

  const idx = sections.length;
  sections.push({
    key: 'sanhe',
    title: '三合水法',
    rows: [
      `局属：${sh.bureau.name}（${sh.bureau.trio.join('、')}）`,
      `坐山阶段：${sh.phase.shan} ${sh.phase.phase}`,
      `黄泉：${sh.huangQuan.title} — ${sh.huangQuan.text}`,
      `八煞：${sh.baSha.text}`,
      `宜来水：${sh.waterAdvice}`,
      `宜去水：${sh.drainAdvice}`,
      `断语：${sh.verdictText}`
    ]
  });

  sections.push({
    key: 'zeri',
    title: '择日课期',
    rows: [
      `四柱：${zr.pillars.fullStr}`,
      `建除：${zr.jianChu.name}日 — ${zr.jianChu.text}`,
      `宜：${zr.yi}`,
      `忌：${zr.ji}`,
      `吉时：${zr.bestShichen.map((s) => s.name).join('、') || '无'}`,
      ...(zr.warnings.length ? [`冲犯：${zr.warnings.join('；')}`] : [])
    ]
  });

  sections.push({
    key: 'qimen',
    title: '奇门时至',
    rows: [
      `局：${qm.term}${qm.yuan} · ${qm.juText}`,
      `值符：${qm.zhiFu.star}临${qm.zhiFu.dir}；值使：${qm.zhiShi.gate}`,
      `吉方：${qm.goodDirs.join('、')}`,
      ...qm.cells.filter((c) => !c.isCenter).map((c) => `${c.dir} ${c.star}/${c.gate}/${c.god}`)
    ]
  });

  const NUMERALS = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二', '十三', '十四', '十五', '十六'];

  // ---- 玄空详解：三般卦 / 七星打劫 / 逐宫化解 ----
  const xkCells = xk.cells;
  const xkAlarms = xkCells.filter((c) => c.alarm25 || c.culprit >= 4);
  sections.push({
    key: 'xuankong_deep',
    title: '玄空详解',
    rows: [
      `格局：${xk.patternText}`,
      `三般卦：${xk.sanBanText}`,
      `七星打劫：${xk.qiXingText}`,
      `当旺星（${xk.period}运）到坐 ${xkCells.find((c) => c.palace === xk.sitPalace).shan}、到向 ${xkCells.find((c) => c.palace === xk.facePalace).xiang}。`,
      ...(xkAlarms.length
        ? xkAlarms.map((c) => `${c.name}（${c.dir}）山${c.shan}向${c.xiang}：${c.culpritName || '见煞'} — ${c.action}`)
        : ['九宫未见五黄二黑叠加或重煞，可按常规布局。'])
    ]
  });

  // ---- 紫白化解：五黄 / 二黑逐宫配化解 ----
  const zbFive = zb.cells.find((c) => c.palace === zb.fivePalace);
  const zbTwo = zb.cells.find((c) => c.palace === zb.twoPalace);
  sections.push({
    key: 'zibai_remedy',
    title: '紫白化解',
    rows: [
      `本年 ${zb.year} 年：年星 ${zb.yearCenter} 入中，五黄在${XK.PALACE_INFO[zb.fivePalace].name}、二黑在${XK.PALACE_INFO[zb.twoPalace].name}。`,
      zbFive ? `五黄宫（${zbFive.name}）：${zbFive.yearTitle || ''} — ${zbFive.yearRemedy || ''}` : '',
      zbTwo ? `二黑宫（${zbTwo.name}）：${zbTwo.yearTitle || ''} — ${zbTwo.yearRemedy || ''}` : '',
      ...zb.cells.filter((c) => c.yearCombo && c.yearComboLevel !== 'ping').slice(0, 4)
        .map((c) => `${c.name}（${c.dir}）组合 ${c.yearCombo}：${c.yearTitle || ''}`),
      ...(zb.warnings || [])
    ].filter(Boolean)
  });

  // ---- 八宅凶星：逐宫断语与化解 ----
  const bzXiong = bzHouse.cells.filter((c) => c.type === 'xiong');
  sections.push({
    key: 'bazhai_xiong',
    title: '八宅凶星',
    rows: [
      `宅卦：${bzHouse.gua}宅（${bzHouse.group}），命卦宜忌以本命卦为准。`,
      ...bzXiong.map((c) => `${c.palace}宫 ${c.star}（${c.starName}）：${c.lore || c.desc || ''}`),
      bzXiong.length ? `化解通则：凶方宜压不宜动，可置柜、置卫浴以镇之；忌开大门、设卧床。` : '八宅未见凶星落宫。'
    ]
  });

  // ---- 择日详解：吉方、冲煞、宅主本命、值神 ----
  const dirs = zr.directions;
  const ownerGod = (zr.todayGods && zr.todayGods[0]) || '';
  sections.push({
    key: 'zeri_deep',
    title: '择日详解',
    rows: [
      `四柱：${zr.pillars.fullStr}`,
      dirs ? `今日吉方：财神在${dirs.wealth.dir}（${dirs.wealth.name}），喜神在${dirs.joy.dir}（${dirs.joy.name}）。` : '',
      `日冲：冲${zr.chongSha.zhi}（属${zr.chongSha.zodiac}），该属相宜静，忌远行签约。`,
      ownerGod ? ZR.officerSummary(ownerGod) : '',
      ...(zr.ownerChongHours && zr.ownerChongHours.length
        ? [`冲宅主本命：${zr.ownerChongHours.map((s) => s.name).join('、')}，重要事宜避开。`]
        : []),
      `黄道时：${zr.huangDaoHours.join('、') || '本日无黄道时'}`
    ].filter(Boolean)
  });

  // ---- 奇门详解：最利用神方位与门星神加会 ----
  const qmBest = QM.evaluateScenario ? QM.evaluateScenario(qm, 'wealth') : null;
  sections.push({
    key: 'qimen_deep',
    title: '奇门详解',
    rows: [
      `局：${qm.term}${qm.yuan} · ${qm.juText}`,
      `值符：${qm.zhiFu.star}临${qm.zhiFu.dir}；值使：${qm.zhiShi.gate}`,
      qmBest && qmBest.bestCell ? `最利方位：${qmBest.bestCell.dir}（${qmBest.bestCell.palaceName || ''}），得「${qmBest.bestCell.gate}+${qmBest.bestCell.star}+${qmBest.bestCell.god}」加会。` : '',
      qmBest && qmBest.gateLine ? `八门断语：${qmBest.gateLine}` : '',
      qmBest && qmBest.guide ? qmBest.guide : ''
    ].filter(Boolean)
  });

  // ---- 形煞自查：按严重程度取前六条 ----
  const shaTop = (SHA_ITEMS || []).slice()
    .sort((a, b) => SEVERITY_RANK[a.severity] - SEVERITY_RANK[b.severity])
    .slice(0, 6);
  sections.push({
    key: 'sha',
    title: '形煞自查',
    rows: shaTop.length
      ? shaTop.map((it) => `${it.name}【${SEVERITY_CN[it.severity] || it.severity}】辨识：${it.identify}影响：${it.effect}化解：${it.remedy}`)
      : ['外煞条目未载入。'],
    note: '外煞须临场目验，本卷所列为常见条目自查提纲，不作吉凶断定的唯一依据。'
  });

  // ---- 户型：有房间数据才做九宫审计 ----
  if (opts.rooms && opts.rooms.length) {
    const fpAudit = FP.audit(opts.rooms, xk);
    const fpMissing = FP.missingCornerAudits(opts.rooms).filter((m) => m.status === 'missing');
    const sites = FP.openingSites(opts.openings, opts.rooms);
    const openSum = FP.openingSummary(FP.normalizeOpenings(opts.openings, opts.rooms));
    const doorFace = FP.facingFromDoor(opts.openings, opts.rooms);
    sections.push({
      key: 'floorplan',
      title: '户型审计',
      rows: [
        `房间 ${opts.rooms.length} 间，图形面积 ${fpAudit.area}，吉 ${fpAudit.levelCount.ji} / 平 ${fpAudit.levelCount.ping} / 凶 ${fpAudit.levelCount.xiong}。`,
        ...fpAudit.summary,
        ...fpMissing.map((m) => `${m.dir}缺角：${m.hurt}化解：${m.remedy}`),
        ...(openSum.total
          ? [`门窗：门 ${openSum.doors} 扇、窗 ${openSum.windows} 扇，落宫见下。`]
            .concat(sites.slice(0, 8).map((s) => `${s.typeText}｜${s.roomName} ${s.sideText}侧 → ${s.palaceName}宫（${s.dir}）`))
          : ['门窗未录入：可在户型页手工补录，补录后本卷自动带出落宫清单。']),
        ...(doorFace ? [`入户门判向：${doorFace.note}`] : [])
      ]
    });
  }

  sections.forEach((s, i) => {
    s.title = `${NUMERALS[i] || i + 1}、${s.title}`;
  });

  const guidance = guidanceText({
    sit, face, xk, bzHouse, zb, sh, zr, qmBest, fpRooms: opts.rooms
  });

  const digest = [
    `宅：${sit}山${face}向 · ${xk.periodText} · ${xk.chartTypeText}`,
    `格局：${xk.patternText}`,
    `八宅：${bzHouse.gua}宅，吉方 ${bzHouse.best.palace}（${bzHouse.best.star}）`,
    `流年：${zb.year} 年五黄在${XK.PALACE_INFO[zb.fivePalace].dir}，二黑在${XK.PALACE_INFO[zb.twoPalace].dir}`,
    `水法：${sh.bureau.name}，${sh.verdict}`,
    `择日：${zr.jianChu.name}日，宜 ${String(zr.yi).split('、').slice(0, 2).join('、')}`,
    `奇门：${qm.juText}，吉方 ${qm.goodDirs.slice(0, 2).join('、')}`
  ];

  return {
    generatedAt: new Date(),
    dateText: `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日`,
    title: `${sit}山${face}向 · 天机长卷`,
    sections,
    digest,
    guidance,
    raw: { sit, face, xk, zb, sh, zr, qm, bzHouse, qmBest }
  };
}

/**
 * 深盘风险排序：把各派的凶象汇总，按影响程度排出处置优先级
 * @param {object} r buildScroll 的返回（或其 raw）
 */
function deepAnalysis(r) {
  const raw = (r && r.raw) || r || {};
  const xk = raw.xk || {};
  const zb = raw.zb || {};
  const bzHouse = raw.bzHouse || {};
  const zr = raw.zr || {};
  const risks = [];

  const lvlScore = { high: 3, mid: 2, low: 1 };

  (xk.cells || []).forEach((c) => {
    if (c.alarm25) {
      risks.push({
        level: 'high',
        source: '玄空',
        title: `${c.name}五黄二黑叠加（山${c.shan}向${c.xiang}）`,
        text: `${c.name}（${c.dir}）山向星见五黄与二黑同宫，主病符关煞同临，最忌久居与安床。`,
        remedy: c.action || '以金泄土、避动土，可置铜器、六帝钱。'
      });
    } else if (c.culprit >= 4) {
      risks.push({
        level: 'mid',
        source: '玄空',
        title: `${c.name}重煞（${c.culpritName || '煞星'}）`,
        text: `${c.name}（${c.dir}）山${c.shan}向${c.xiang}，${c.lore || ''}`,
        remedy: c.action || '按星性调理。'
      });
    }
  });

  if (zb.fivePalace) {
    risks.push({
      level: 'high',
      source: '紫白',
      title: `${zb.year} 年五黄落${XK.PALACE_INFO[zb.fivePalace].name}`,
      text: `年五黄在${XK.PALACE_INFO[zb.fivePalace].dir}，主突发之灾与阻滞；动土、开门、搬迁尤忌此方。`,
      remedy: (zb.cells || []).filter((c) => c.palace === zb.fivePalace)[0]?.yearRemedy || '宜静不宜动，金器化泄。'
    });
  }
  if (zb.twoPalace) {
    risks.push({
      level: 'mid',
      source: '紫白',
      title: `${zb.year} 年二黑落${XK.PALACE_INFO[zb.twoPalace].name}`,
      text: `年二黑在${XK.PALACE_INFO[zb.twoPalace].dir}，主脾胃、妇科与缠绵之疾。`,
      remedy: (zb.cells || []).filter((c) => c.palace === zb.twoPalace)[0]?.yearRemedy || '六白金泄之，忌红黄重色。'
    });
  }

  (bzHouse.cells || []).filter((c) => c.type === 'xiong').forEach((c) => {
    risks.push({
      level: c.star === '五鬼' || c.star === '绝命' ? 'high' : 'mid',
      source: '八宅',
      title: `${c.palace}宫${c.star}`,
      text: `${c.palace}宫得${c.star}（${c.starName}），${c.lore || c.desc || ''}`,
      remedy: '凶方宜压宜静：置重柜、设卫浴，忌开门、卧床、动土。'
    });
  });

  if (zr.jianChu && zr.jianChu.info && zr.jianChu.info.level === 'xiong') {
    risks.push({
      level: 'mid',
      source: '择日',
      title: `${zr.jianChu.name}日`,
      text: zr.jianChu.info.text,
      remedy: '重大事宜另择吉日；本日宜静守、修整、疗病。'
    });
  }
  (zr.warnings || []).forEach((w) => {
    risks.push({ level: 'mid', source: '择日', title: '冲犯提示', text: w, remedy: '避开相应时辰与方位。' });
  });

  risks.sort((a, b) => (lvlScore[b.level] || 0) - (lvlScore[a.level] || 0));

  const high = risks.filter((x) => x.level === 'high').length;
  const mid = risks.filter((x) => x.level === 'mid').length;
  // 只计前 5 项中煞，避免同类多宫重复扣分把分数压到 0
  const score = Math.max(25, 100 - high * 12 - Math.min(mid, 5) * 4);

  return {
    score,
    grade: score >= 80 ? '上吉' : (score >= 60 ? '中平' : (score >= 40 ? '偏凶' : '凶')),
    highCount: high,
    midCount: mid,
    risks: risks.slice(0, 10),
    actions: risks.slice(0, 5).map((x) => `【${x.source}】${x.title}：${x.remedy}`)
  };
}

/**
 * 总纲建议：把各派结论组织成可直接执行的几句话
 */
function guidanceText(r) {
  const x = r || {};
  const xk = x.xk || {};
  const bzHouse = x.bzHouse || {};
  const zb = x.zb || {};
  const sh = x.sh || {};
  const zr = x.zr || {};
  const qmBest = x.qmBest || null;
  const sit = x.sit || '';
  const face = x.face || '';

  const parts = [];
  parts.push(`${sit}山${face}向，${xk.periodText || ''}${xk.chartTypeText ? '，' + xk.chartTypeText : ''}；${xk.patternText || ''}`);

  if (bzHouse.best) {
    parts.push(`八宅以${bzHouse.gua}宅论，${bzHouse.best.palace}宫得${bzHouse.best.star}为最吉，宜作主卧或书房；${(bzHouse.worst && bzHouse.worst.palace) ? bzHouse.worst.palace + '宫' + (bzHouse.worst.star || '') + '最凶，宜压低处置。' : ''}`);
  }
  if (zb && zb.fivePalace) {
    parts.push(`本年五黄在${XK.PALACE_INFO[zb.fivePalace].dir}、二黑在${XK.PALACE_INFO[zb.twoPalace].dir}，此二方忌动土、开门、久坐，宜金器化泄。`);
  }
  if (sh && sh.verdictText) {
    parts.push(`水法：${sh.verdictText}`);
  }
  if (zr && zr.jianChu) {
    parts.push(`择日：本日${zr.jianChu.name}日，宜${String(zr.yi || '').split('、').slice(0, 3).join('、')}；冲${(zr.chongSha && zr.chongSha.zhi) || ''}，该属相避忌。`);
  }
  if (qmBest && qmBest.bestCell) {
    parts.push(`奇门：当下最利${qmBest.bestCell.dir}方，得「${qmBest.bestCell.gate}+${qmBest.bestCell.star}+${qmBest.bestCell.god}」加会，出行可往此方动身。`);
  }
  if (!x.fpRooms) {
    parts.push('户型未录入：可到「户型九宫」手工描摹或导入底图，再回本卷补全缺角与房间审计。');
  }
  parts.push('以上皆为传统术数的本地推算，仅供研究参考，重大决定请现场复核并咨询专业意见。');
  return parts.filter(Boolean).join('\n');
}

module.exports = { buildScroll, deepAnalysis, guidanceText, MOUNTAIN_TO_PALACE, PALACE_NUM };
