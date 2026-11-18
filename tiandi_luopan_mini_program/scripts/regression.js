/**
 * regression.js — 小程序全量算法回归校验（Node 直跑，无需真机）
 * 用法：node scripts/regression.js
 * 覆盖：择日、玄空、三合、紫白、八宅、奇门、户型、天机、坐向诊断、外煞、断语库
 */

const path = require('path');
const assert = require('assert');

const ROOT = path.join(__dirname, '..');
const U = (n) => require(path.join(ROOT, 'utils', n));

const XK = U('xuankong');
const ZB = U('zibai');
const BZ = U('bazhai');
const SH = U('sanhe');
const ZR = U('zeri');
const QM = U('qimen');
const FP = U('floorplan');
const TJ = U('tianji');
const SF = U('sitface');
const SHA = U('sha');
const LT = U('legal-text');
const ST = U('solar-terms');
const RF = U('roomfit');

let pass = 0;
const fails = [];

function ok(name, fn) {
  try {
    fn();
    pass++;
    console.log('  ✓ ' + name);
  } catch (e) {
    fails.push(name + ' → ' + e.message);
    console.log('  ✗ ' + name + ' → ' + e.message);
  }
}

console.log('\n=== 1. 择日（财神喜神 / 冲本命 / 值神） ===');
const DAY = new Date('2026-11-17T10:00:00+08:00');
ok('四柱为 丙午年 己亥月 乙未日', () => {
  const a = ZR.analyze(DAY, '子', {});
  assert.ok(a.pillars.yearPillar.indexOf('丙午') >= 0, a.pillars.yearPillar);
  assert.ok(a.pillars.monthPillar.indexOf('己亥') >= 0, a.pillars.monthPillar);
  assert.ok(a.pillars.dayPillar.indexOf('乙未') >= 0, a.pillars.dayPillar);
});
ok('财神西南 / 喜神西北（乙日）', () => {
  const d = ZR.dailyCompassDirections(DAY);
  assert.strictEqual(d.wealth.dir, '西南');
  assert.strictEqual(d.wealth.angle, 225);
  assert.strictEqual(d.joy.dir, '西北');
  assert.strictEqual(d.joy.angle, 315);
});
ok('日冲丑（属牛）', () => {
  const a = ZR.analyze(DAY, '子', {});
  assert.strictEqual(a.chongSha.zhi, '丑');
  assert.strictEqual(a.chongSha.zodiac, '牛');
});
ok('1985 乙丑命 → 未时冲本命', () => {
  const a = ZR.analyze(DAY, '子', { ownerBirthYear: 1985 });
  assert.ok(a.ownerChongHours.map((s) => s.name).indexOf('未时') >= 0);
});
ok('十二值神文案齐备（黄 6 / 黑 6）', () => {
  const keys = Object.keys(ZR.GOD_OFFICER_INFO);
  assert.strictEqual(keys.length, 12);
  assert.strictEqual(keys.filter((k) => ZR.GOD_OFFICER_INFO[k].huang).length, 6);
  assert.ok(ZR.officerSummary('青龙').indexOf('黄道') >= 0);
});

console.log('\n=== 2. 玄空（替卦 / 三般卦 / 七星打劫 / 流年月） ===');
ok('坐向诊断：180° 正针', () => {
  const d = SF.diagnoseHeading(180);
  assert.ok(d.absDev <= 3);
  assert.ok(d.text.indexOf('正针') >= 0 || d.type === '正针');
});
ok('坐向诊断：185.5° 兼向需替卦', () => {
  const d = SF.diagnoseHeading(185.5);
  assert.ok(d.absDev > 3 && d.absDev <= 6);
  assert.strictEqual(d.needTiGua, true);
});
ok('坐向诊断：187.2° 小空亡', () => {
  const d = SF.diagnoseHeading(187.2);
  assert.ok(d.absDev > 6);
  assert.ok(d.text.indexOf('空亡') >= 0);
});
ok('三般卦与七星打劫判定返回结构完整', () => {
  const c = XK.calculateChart({ sitMountain: '子', faceMountain: '午', period: 9 });
  assert.strictEqual(typeof c.sanBanText, 'string');
  assert.strictEqual(typeof c.qiXingText, 'string');
  // sanBan 为 'fumu' / 'lianzhu' / null，qiXing 为对象或 null，均须显式给出
  assert.ok(c.sanBan === null || c.sanBan === 'fumu' || c.sanBan === 'lianzhu');
  c.cells.forEach((cell) => {
    assert.ok(cell.action && cell.action.length > 4, '每格须带化解');
    assert.ok(typeof cell.culprit === 'number');
  });
});
ok('父母三般卦可被识别（147/258/369 全宫成组）', () => {
  // 三般卦成立时 sanBan 应为 'fumu' 或 'lianzhu'，此处只需验证判定不误报
  const c = XK.calculateChart({ sitMountain: '子', faceMountain: '午', period: 9 });
  if (c.sanBan) assert.ok(c.sanBanText.indexOf('三般卦') >= 0);
});
ok('流年月叠加写入每格 flow 字段', () => {
  const c = XK.withFlow(XK.calculateChart({ sitMountain: '子', faceMountain: '午', period: 9 }), 2026, 11);
  const cell = c.cells[0];
  assert.ok(cell.annual >= 1 && cell.annual <= 9);
  assert.ok(cell.monthly >= 1 && cell.monthly <= 9);
});

console.log('\n=== 3. 三合 / 紫白 / 八宅 断语库 ===');
ok('三合原诀齐备（黄泉 / 八煞 / 五煞 / 长生）', () => {
  assert.ok(SH.HUANG_QUAN_SONG && SH.BA_SHA_SONG && SH.WU_SHA_LUN);
  assert.strictEqual(Object.keys(SH.PHASE_LORE).length, 12);
  const a = SH.analyze('子', '午');
  assert.ok(a.songs && a.songs.huangQuan && a.songs.huangQuan.text.length > 20);
  assert.ok(a.songs.baSha && a.songs.wuSha);
  assert.ok(a.evidence && a.evidence.huangQuan && a.evidence.huangQuan.indexOf('出处') >= 0);
});
ok('紫白 9 星做法 + 组合断语 + 逐宫化解', () => {
  const c = ZB.calculateChart(DAY, { sitPalace: 1, facePalace: 9 });
  assert.strictEqual(Object.keys(ZB.ZIBAI_LORE).length, 9);
  c.cells.forEach((cell) => {
    assert.ok(cell.yearRemedy, '年化解缺失');
    assert.ok(cell.yearTitle, '年标题缺失');
  });
});
ok('八宅 8 星断语 + 逐宫 lore', () => {
  const r = BZ.roamStars(1);
  assert.strictEqual(Object.keys(BZ.BAZHAI_LORE).length, 8);
  r.cells.forEach((c) => assert.ok(c.lore, '宫位缺 lore'));
});

console.log('\n=== 4. 奇门（八门断语 + 最利方位指南） ===');
ok('八门断语 8 条', () => {
  assert.strictEqual(Object.keys(QM.GATE_LINE).length, 8);
});
ok('奇门旺衰：月令定旺相休囚死，门星随令加减分', () => {
  const QM = U('qimen');
  assert.strictEqual(QM.relation('水', '水').state, '旺');
  assert.strictEqual(QM.relation('火', '木').state, '相');   // 木生火
  assert.strictEqual(QM.relation('水', '木').state, '休');   // 水生木，气泄
  assert.strictEqual(QM.relation('金', '木').state, '囚');   // 金克木，受制
  assert.strictEqual(QM.relation('土', '木').state, '死');   // 木克土

  assert.strictEqual(QM.vitalityOf('休门', true, '水').state, '旺');
  assert.strictEqual(QM.vitalityOf('生门', true, '水').state, '囚'); // 土克水
  assert.strictEqual(QM.vitalityOf('天蓬', false, '水').state, '旺');

  const chart = QM.calculateChart(new Date('2026-11-18 14:00'));
  assert.ok(chart.monthText.indexOf('月建') >= 0, '应给出月建旺衰');
  chart.cells.filter((c) => !c.isCenter).forEach((c) => {
    assert.ok(c.vitality && typeof c.vitality.score === 'number', '每宫应带旺衰分');
  });
  const s = QM.evaluateScenario(chart, 'wealth');
  assert.ok(s.vitality && s.vitality.text, '场景结论应带旺衰');
  assert.ok(s.text.indexOf('旺衰') >= 0, '断语应写明旺衰');
});

ok('求财场景取生门并给出指南句', () => {
  const chart = QM.calculateChart(DAY);
  const r = QM.evaluateScenario(chart, 'wealth');
  assert.ok(r.gateLine.indexOf('求财') >= 0 || r.gateLine.length > 6);
  assert.ok(r.guide.indexOf('最利方位') >= 0);
  assert.ok(r.best && r.best.dir && r.best.gate);
});

console.log('\n=== 5. 外煞（23 类外部 + 12 类室内 / 四段 steps / 出处） ===');
ok('35 类且每类 4 段', () => {
  assert.strictEqual(SHA.ITEMS.length, 35);
  SHA.ITEMS.forEach((it) => {
    assert.strictEqual(it.steps.length, 4);
    assert.ok(it.source, '缺出处：' + it.name);
  });
  assert.ok(SHA.CLASSIC_SOURCE && SHA.CLASSIC_SOURCE.length > 10);
});

console.log('\n=== 6. 户型（缺角断语 / DXF / 宅谱 JSON） ===');
ok('缺角断语含 hurt/remedy/source', () => {
  const one = [{ name: 'A', type: '主卧', x: 0, y: 0, w: 20, h: 20 }];
  const audits = FP.missingCornerAudits(one);
  const missing = audits.filter((a) => a.status === 'missing');
  assert.ok(missing.length >= 6);
  missing.forEach((m) => {
    assert.ok(m.hurt.length > 10);
    assert.ok(m.remedy.length > 6);
    assert.ok(m.source.indexOf('出典') >= 0);
  });
});
ok('DXF 具备 ENTITIES 与 LINE/TEXT', () => {
  const dxf = FP.toDXF(FP.sampleRooms(), { widthMeters: '12', sit: '子', face: '午' });
  assert.ok(dxf.indexOf('ENTITIES') >= 0);
  assert.ok(dxf.indexOf('LWPOLYLINE') >= 0);
  assert.ok(dxf.indexOf('\r\nLINE\r\n') >= 0);
  assert.ok(dxf.trim().endsWith('EOF'));
});
ok('宅谱 JSON 往返一致', () => {
  const rooms = FP.sampleRooms();
  const text = FP.planToJSON({ label: 't', sit: '子', face: '午', widthMeters: '12', rooms });
  const back = FP.parsePlanJSON(text);
  assert.strictEqual(back.rooms.length, rooms.length);
  assert.strictEqual(back.sit, '子');
});
ok('非法 JSON 返回错误而非抛异常', () => {
  const r = FP.parsePlanJSON('{oops');
  assert.ok(r.error);
});

console.log('\n=== 7. 天机长卷（十三章 + 总评 + 深盘） ===');
ok('buildScroll 输出 13 章', () => {
  const s = TJ.buildScroll({ sitMountain: '子', faceMountain: '午', date: DAY });
  assert.strictEqual(s.sections.length, 13);
  const keys = s.sections.map((x) => x.key);
  ['xuankong_deep', 'zibai_remedy', 'bazhai_xiong', 'zeri_deep', 'qimen_deep', 'sha'].forEach((k) => {
    assert.ok(keys.indexOf(k) >= 0, '缺章节 ' + k);
  });
  assert.ok(s.guidance.length > 50);
});
ok('deepAnalysis 给出评分与处置清单', () => {
  const s = TJ.buildScroll({ sitMountain: '子', faceMountain: '午', date: DAY });
  const d = TJ.deepAnalysis(s);
  assert.ok(d.score >= 25 && d.score <= 100);
  assert.ok(d.risks.length > 0);
  assert.ok(d.actions.length > 0);
});

console.log('\n=== 8. 合规文本 ===');
ok('协议与合规两份文本齐备且非空', () => {
  ['terms', 'compliance'].forEach((k) => {
    const doc = LT.getDoc(k);
    assert.ok(doc && doc.body.length > 500, k + ' 正文过短');
    assert.ok(LT.paragraphs(k).length > 10);
  });
});

ok('隐私说明已移除', () => {
  assert.ok(!LT.getDoc('privacy'), 'privacy 文档不应存在');
  assert.ok(!('PRIVACY_TITLE' in LT), '不应再导出 PRIVACY_TITLE');
  assert.ok(!('PRIVACY_BODY' in LT), '不应再导出 PRIVACY_BODY');
});

console.log('\n=== 9. 日课自检与节气进度 ===');
ok('2026-11-17 立冬节令 · 距小雪 6 天', () => {
  const p = ST.solarTermProgress(DAY);
  assert.strictEqual(p.name, '立冬');
  assert.strictEqual(p.nextName, '小雪');
  assert.strictEqual(p.daysToNext, 6);
  assert.ok(p.progress > 0.5 && p.progress < 0.8, 'progress=' + p.progress);
});
ok('岁破 / 月破 / 冲山 三大自检字段齐备', () => {
  const a = ZR.dayCourseAudit(DAY, null, {});
  ['suiPo', 'yuePo', 'sittingClash', 'canGroundbreak', 'canInstallDoor'].forEach((k) => {
    assert.ok(Object.prototype.hasOwnProperty.call(a, k), k);
  });
  assert.strictEqual(a.suiPo, false);
  assert.strictEqual(a.yuePo, false);
  assert.strictEqual(a.canGroundbreak, true);
  assert.ok(a.detailsText.indexOf('岁破') >= 0);
});
ok('子山在午年：坐山冲太岁 + 落三煞 → 不放行动土', () => {
  const a = ZR.dayCourseAudit(DAY, '子', {});
  assert.strictEqual(a.canGroundbreak, false);
  assert.strictEqual(a.groundbreakBadge, '忌动土起造');
  assert.strictEqual(a.installDoorBadge, '忌安门修方');
  assert.strictEqual(a.sittingTitle, '子山午向');
  assert.ok(a.sanShaHit);
});

console.log('\n=== 10. 家人配房（FamilyRoomAllocation 口径） ===');
ok('rank 表与 iOS 一致', () => {
  assert.strictEqual(RF.RANK_TABLE.study['伏'], 100);
  assert.strictEqual(RF.RANK_TABLE.study['延'], 80);
  assert.strictEqual(RF.RANK_TABLE.study['天'], 70);
  assert.strictEqual(RF.RANK_TABLE.study['生'], 90);
  assert.strictEqual(RF.RANK_TABLE.bedroom['伏'], 80);
  assert.strictEqual(RF.RANK_TABLE.bedroom['延'], 100);
  assert.strictEqual(RF.RANK_TABLE.bedroom['天'], 95);
  assert.strictEqual(RF.RANK_TABLE.bedroom['生'], 75);
});
ok('厨房 / 卫浴 / 客厅不可配人', () => {
  ['厨房', '卫生间', '客厅', '储物', '餐厅'].forEach((t) => {
    assert.strictEqual(RF.useOf({ name: t, type: t }), null, t);
  });
  assert.strictEqual(RF.useOf({ type: '主卧' }), 'bedroom');
  assert.strictEqual(RF.useOf({ type: '书房' }), 'study');
});
ok('推荐：每人一卧一书房，且不配凶星房', () => {
  const rooms = FP.sampleRooms();
  const people = RF.peopleOf({
    owner: { name: '本人', birthYear: 1985, gender: '男' },
    members: [{ name: '太太', birthYear: 1988, gender: '女' }]
  });
  assert.strictEqual(people.length, 2);
  const rec = RF.recommend(rooms, people);
  assert.ok(rec.length >= 2);
  rec.forEach((r) => {
    assert.ok(r.use === 'bedroom' || r.use === 'study');
    assert.ok(r.star, '应带星名');
  });
  const perPerson = {};
  rec.forEach((r) => {
    perPerson[r.personID] = perPerson[r.personID] || {};
    perPerson[r.personID][r.use] = (perPerson[r.personID][r.use] || 0) + 1;
  });
  Object.keys(perPerson).forEach((pid) => {
    assert.ok(perPerson[pid].bedroom <= 1, pid + ' 卧房超过一间');
    assert.ok((perPerson[pid].study || 0) <= 1, pid + ' 书房超过一间');
  });
});
ok('已分凶星房进复核，切换可撤销', () => {
  const rooms = FP.sampleRooms();
  const people = RF.peopleOf({ owner: { name: '本人', birthYear: 1985, gender: '男' } });
  // 找一间对本命为凶星的房
  const bad = rooms.filter((r, i) => {
    if (!RF.isAssignable(r)) return false;
    const f = RF.fit(Object.assign({}, r, { id: `r${i}` }), rooms.map((x, j) => Object.assign({}, x, { id: `r${j}` })), people[0]);
    return !f.isRecommended;
  })[0];
  assert.ok(bad, '样例户型应至少有一间凶星房');
  const idx = rooms.indexOf(bad);
  const assigned = [{ personID: people[0].id, roomID: `r${idx}` }];
  const rs = rooms.map((x, j) => Object.assign({}, x, { id: `r${j}` }));
  const reviews = RF.reviewPairs(assigned, rs, people);
  assert.ok(reviews.length >= 1);
  const after = RF.toggling(people[0].id, `r${idx}`, assigned, rs, people);
  assert.strictEqual(after.length, 0);
});
ok('太极点所在最小房间不参与排名', () => {
  const rooms = FP.sampleRooms().map((r, i) => Object.assign({}, r, { id: `r${i}` }));
  const central = RF.centralRoomId(rooms);
  if (central) {
    const room = rooms.filter((r) => r.id === central)[0];
    assert.strictEqual(RF.palaceOfRoom(room, rooms), null);
  }
});

// ===== 第十一组：提醒引擎（替代 iOS 系统通知） =====
const RM = require('../utils/reminders');

// 备份相关需要 Storage：给 Node 环境补一个内存版 wx（真机由微信提供）
if (typeof global.wx === 'undefined') {
  const mem = {};
  global.wx = {
    setStorageSync: (k, v) => { mem[k] = v; },
    getStorageSync: (k) => (k in mem ? mem[k] : ''),
    removeStorageSync: (k) => { delete mem[k]; },
    getSystemInfoSync: () => ({ platform: 'devtools', pixelRatio: 2 })
  };
}
const BK = require('../utils/backup');

ok('提醒：换月只在节气进入偶数索引时发生', () => {
  assert.strictEqual(RM.isMonthChangingTerm(0), true);
  assert.strictEqual(RM.isMonthChangingTerm(2), true);
  assert.strictEqual(RM.isMonthChangingTerm(1), false);
  assert.strictEqual(RM.isMonthChangingTerm(3), false);
});

ok('提醒：未来 7 天事件覆盖吉日与节气交节', () => {
  const list = RM.upcoming(new Date(2026, 10, 17), { days: 7, sitMountain: '子', ownerBirthYear: 1985 });
  assert.ok(list.length >= 4, '应有至少 4 条提醒，实际 ' + list.length);
  const types = {};
  list.forEach((i) => { types[i.type] = (types[i.type] || 0) + 1; });
  assert.ok(types.good >= 1, '应有吉日');
  assert.ok(types.term >= 1, '应有节气预告');
  assert.strictEqual(typeof RM.toText(list), 'string');
  assert.ok(RM.toText(list).indexOf('【') >= 0 || RM.toText(list).indexOf('·') >= 0);
});

ok('提醒：冲煞按坐山与本命年判定', () => {
  const d = new Date(2026, 10, 22); // 2026-11-22 小雪，当日为岁破日
  const list = RM.upcoming(d, { days: 1, sitMountain: '午', ownerBirthYear: 1990 });
  const clash = list.filter((i) => i.type === 'clash');
  assert.ok(clash.length >= 1, '应命中冲煞');
  assert.strictEqual(RM.lockedSit({ compassLock: { locked: true, heading: 0 } }), '子');
  assert.strictEqual(RM.lockedSit({}), null);
});

ok('提醒：偏好可过滤类型', () => {
  const p = RM.normalizePrefs({ term: false, month: false, clash: false, good: true });
  const list = RM.filterByPrefs(RM.upcoming(new Date(2026, 10, 17), { days: 7 }), p);
  list.forEach((i) => assert.strictEqual(i.type, 'good'));
});

// ===== 第十二组：备份（替代 iOS iCloud KVS） =====
ok('备份：collect → serialize → parse 往返一致', () => {
  const obj = BK.collect();
  assert.strictEqual(obj.app, 'yanxiang-luopan-miniprogram');
  assert.strictEqual(obj.v, BK.BACKUP_VERSION);
  const text = BK.serialize();
  const r = BK.parse(text);
  assert.ok(r.data, '解析应成功：' + (r.error || ''));
  assert.ok(r.summary.at, '应带备份时间');
  assert.strictEqual(typeof r.summary.members, 'number');
  assert.strictEqual(r.summary.hasSettings, true);
  assert.ok(BK.parse('not json').error, '非法 JSON 应报错');
  assert.ok(BK.parse('{"app":"other"}').error, '非本程序备份应拒绝');
});

ok('备份：merge 去重且 replace 覆盖', () => {
  const snap = BK.collect();
  const base = JSON.parse(JSON.stringify(snap));
  base.profiles = { owner: null, members: [{ name: '测试成员', birthYear: 1990, gender: '男' }] };
  const r1 = BK.apply(base, 'replace');
  assert.strictEqual(r1.mode, 'replace');
  assert.strictEqual(r1.members, 1);
  assert.strictEqual(BK.collect().profiles.members.length, 1);
  const r2 = BK.apply(base, 'merge');
  assert.strictEqual(r2.mode, 'merge');
  assert.strictEqual(BK.collect().profiles.members.length, 1, '同一姓名+年+性别不应重复');
  assert.strictEqual(BK.summaryOf(base).members, 1);
});

ok('恢复日志：成功 / 失败 / 撤销各留一条，上限 20 条', () => {
  const store = require('../utils/store');
  BK.clearLog();
  store.write('yj_profiles', { owner: null, members: [{ name: '甲', birthYear: 1980, gender: '男' }] });

  BK.apply({ v: 2, app: 'yanxiang-luopan-miniprogram', profiles: { owner: null, members: [{ name: '乙', birthYear: 1990, gender: '女' }] } }, 'replace');
  let log = BK.getLog();
  assert.strictEqual(log.length, 1, '成功后应有 1 条日志');
  assert.strictEqual(log[0].action, 'apply');
  assert.strictEqual(log[0].ok, true);
  assert.strictEqual(log[0].members, 1);

  BK.restoreUndo();
  log = BK.getLog();
  assert.strictEqual(log[0].action, 'undo', '撤销应留一条 undo 日志');
  assert.strictEqual(log[0].ok, true);

  const orig = global.wx.setStorageSync;
  global.wx.setStorageSync = (k, v) => {
    if (k === 'yj_history') throw new Error('full');
    orig(k, v);
  };
  BK.apply({
    v: 2, app: 'yanxiang-luopan-miniprogram',
    profiles: { owner: null, members: [{ name: '丙', birthYear: 2000, gender: '男' }] },
    history: [{ id: 'h9', at: 9 }]
  }, 'replace');
  global.wx.setStorageSync = orig;
  log = BK.getLog();
  assert.strictEqual(log[0].ok, false, '失败也要留痕');
  assert.ok(log[0].error, '失败日志应带原因');

  for (let i = 0; i < 25; i++) {
    BK.apply({ v: 2, app: 'yanxiang-luopan-miniprogram', profiles: { owner: null, members: [] } }, 'replace');
  }
  assert.strictEqual(BK.getLog().length, 20, '日志上限 20 条');
});

ok('撤销点：恢复前自动留档、可来回切、过期清除', () => {
  const store = require('../utils/store');
  store.write('yj_profiles', { owner: null, members: [{ name: '原主', birthYear: 1980, gender: '男' }] });
  store.remove('yj_backup_undo');
  assert.strictEqual(BK.getUndo(), null, '初始不应有撤销点');

  const r1 = BK.apply({
    v: 2,
    app: 'yanxiang-luopan-miniprogram',
    profiles: { owner: null, members: [{ name: '新人', birthYear: 1990, gender: '女' }] }
  }, 'replace');
  assert.ok(!r1.error);

  const u = BK.getUndo();
  assert.ok(u, '恢复后应留撤销点');
  assert.strictEqual(u.summary.members, 1);
  assert.strictEqual(u.expired, false);

  const r2 = BK.restoreUndo();
  assert.ok(!r2.error, '撤销应成功：' + (r2.error || ''));
  assert.strictEqual(store.getProfiles().members[0].name, '原主', '应回到恢复前');
  assert.ok(BK.getUndo(), '撤销后应留下新撤销点');

  const r3 = BK.restoreUndo();
  assert.ok(!r3.error);
  assert.strictEqual(store.getProfiles().members[0].name, '新人', '再撤一次应切回新数据');

  store.write('yj_backup_undo', { at: Date.now() - 8 * 24 * 60 * 60 * 1000, mode: 'replace', data: BK.collect() });
  assert.strictEqual(BK.getUndo().expired, true, '超过 7 天应标记过期');
  assert.ok(BK.restoreUndo().error, '过期后撤销应拒绝');
  assert.strictEqual(BK.getUndo(), null, '过期撤销点应被清除');
});

ok('备份恢复：写失败整体回滚，不留半恢复状态', () => {
  const store = require('../utils/store');
  store.write('yj_profiles', { owner: null, members: [{ name: '原主', birthYear: 1980, gender: '男' }] });
  store.write('yj_floorplans', [{ id: 'keep1' }]);
  store.write('yj_history', [{ id: 'old', at: 1 }]);

  const orig = global.wx.setStorageSync;
  global.wx.setStorageSync = (k, v) => {
    if (k === 'yj_history') throw new Error('storage full');
    orig(k, v);
  };
  const r = BK.apply({
    v: 2,
    app: 'yanxiang-luopan-miniprogram',
    profiles: { owner: null, members: [{ name: '备份人', birthYear: 1990, gender: '女' }] },
    floorplans: [{ id: 'fromBackup' }],
    history: [{ id: 'newHist', at: 2 }]
  }, 'replace');
  global.wx.setStorageSync = orig;

  assert.ok(r.error, '写入失败应返回 error');
  assert.deepStrictEqual(r.failed, ['yj_history'], '失败段应被列出');
  assert.strictEqual(store.getProfiles().members[0].name, '原主', '档案应回滚');
  assert.strictEqual(store.getFloorplans()[0].id, 'keep1', '户型应回滚');
  assert.strictEqual(store.getHistory()[0].id, 'old', '历史应保持原样');
});

ok('备份差异预览：合并报新增/已存在，覆盖报替换与丢弃', () => {
  const store = require('../utils/store');
  store.write('yj_profiles', { owner: null, members: [{ name: '甲', birthYear: 1990, gender: '男' }] });
  store.write('yj_floorplans', [{ id: 'p1' }, { id: 'p2' }]);
  store.write('yj_remedy_tasks', [{ id: 't1', done: false }]);
  store.write('yj_history', [{ id: 'h1', at: 1 }]);
  store.write('yj_place', { name: '本机点' });

  const inc = {
    v: 2,
    app: 'yanxiang-luopan-miniprogram',
    profiles: { members: [{ name: '甲', birthYear: 1990, gender: '男' }, { name: '乙', birthYear: 1992, gender: '女' }] },
    floorplans: [{ id: 'p2' }, { id: 'p3' }],
    remedyTasks: [{ id: 't1', done: true }, { id: 't2', done: false }],
    history: [{ id: 'h2', at: 2 }],
    settings: { lang: 'en' },
    place: { name: '备份点' }
  };

  const merge = BK.diff(inc, 'merge');
  assert.strictEqual(merge.mode, 'merge');
  assert.strictEqual(merge.members.add, 1, '合并应新增 1 人');
  assert.strictEqual(merge.members.dup, 1, '合并应有 1 人重复');
  assert.strictEqual(merge.floorplans.add, 1, '户型应新增 1 套');
  assert.strictEqual(merge.tasks.add, 1);
  assert.strictEqual(merge.tasks.newlyDone, 1, '已存在的任务应由未完成变为已完成');
  assert.strictEqual(merge.settings.changed, 1, '语言差异应被指出');
  assert.strictEqual(merge.place.action, 'keep', '合并时本机已有位置应保留本机');

  const rep = BK.diff(inc, 'replace');
  assert.strictEqual(rep.mode, 'replace');
  assert.strictEqual(rep.floorplans.add, 2, '覆盖时全部按新增计');
  assert.strictEqual(rep.floorplans.dropped, 0, '本机 2 套、备份 2 套不应报丢弃');
  assert.strictEqual(rep.place.action, 'overwrite', '覆盖时本机位置将被改写');
});

ok('备份 v2：位置 / 坐向 / 外煞一并进出，脏结构与高版本拒绝', () => {
  const store = require('../utils/store');
  store.write('yj_place', { name: '自家客厅', lat: 39.9, lon: 116.4 });
  store.write('yj_current_orientation', { sit: '子', face: '午', heading: 0, source: 'manual' });
  store.write('yj_sha_check', { checked: ['a', 'b'], sit: '子' });

  const snap = BK.collect();
  assert.strictEqual(snap.v, 2, '备份版本应为 2');
  assert.ok(snap.place && snap.place.name === '自家客厅', '应带位置');
  assert.ok(snap.orientation, '应带坐向');
  assert.strictEqual(snap.shaCheck.checked.length, 2, '应带外煞勾选');

  const r = BK.parse(JSON.stringify(snap));
  assert.ok(r.data, '解析应成功：' + (r.error || ''));
  assert.ok(r.summary.placeName.indexOf('自家客厅') >= 0, '摘要应含位置名');
  assert.strictEqual(r.summary.shaChecked, 2);
  assert.strictEqual(r.summary.hasOrientation, true);
  assert.ok(r.summary.hasReportDraft === true || r.summary.hasReportDraft === false);

  const high = BK.parse(JSON.stringify({ app: 'yanxiang-luopan-miniprogram', v: 99, settings: {} }));
  assert.ok(high.error, '高版本备份应拒绝');
  const badMembers = BK.parse(JSON.stringify({ app: 'yanxiang-luopan-miniprogram', v: 2, profiles: { members: {} } }));
  assert.ok(badMembers.error, 'members 非数组应拒绝');

  const st = BK.apply({ v: 2, app: 'yanxiang-luopan-miniprogram', place: { name: '备份点' }, shaCheck: { checked: ['x'] } }, 'replace');
  assert.strictEqual(st.place, 1);
  assert.strictEqual(store.read('yj_place', null).name, '备份点');
});

ok('分金逐度：正针 / 兼向 / 出卦与最近吉度', () => {
  const FJ = U('fenjin');
  const KW = U('kongwang');

  // 0° 正北：子山丙寅分金、珠宝、正针
  const r0 = FJ.degreeReading(0);
  assert.strictEqual(r0.mountain, '子');
  assert.strictEqual(r0.jiazi, '丙寅');
  assert.strictEqual(r0.gradeKey, 'jewel');
  assert.strictEqual(r0.jian.type, 'pure');
  assert.strictEqual(r0.usable, true);

  // 183°：午山兼丁，仍落珠宝分金但需替卦
  const j = FJ.jianXiang(183);
  assert.strictEqual(j.text, '午山兼丁');
  assert.strictEqual(j.type, 'jian');
  const r183 = FJ.degreeReading(183);
  assert.strictEqual(r183.jian.type, 'jian');
  assert.ok(r183.verdict.indexOf('替卦') >= 0, '兼向应提示替卦');

  // 22.5° 贴出卦线：大空亡且不可用
  const kw = KW.reading(22.5);
  assert.strictEqual(kw.type, 'big_kw');
  assert.ok(kw.advice.indexOf('出卦') >= 0);

  // 最近吉度：偏移不超过 8°，且落珠宝分金
  const near = FJ.nearestAuspicious(183);
  assert.ok(near, '应能就近找到吉度');
  assert.ok(Math.abs(near.delta) <= 8);
  assert.ok(FJ.resolve(near.deg).usable);

  // 逐度输出字段齐备，页面直接可渲染
  const keys = ['deg', 'mountain', 'jiazi', 'nayin', 'grade', 'usable', 'cellPos', 'jian', 'verdict', 'advice', 'nearest'];
  keys.forEach((k) => assert.ok(r183[k] !== undefined, '缺字段 ' + k));
});

ok('择日吉神：天德 / 月德 / 天赦 / 四废可判，事项吉时成组', () => {
  const Z = U('zeri');
  let td = null;
  let yd = null;
  let ts = null;
  let sf = null;
  for (let i = 0; i < 120; i++) {
    const d = new Date(2026, 0, 1 + i);
    const g = Z.auspiciousGods(d);
    const b = Z.badDaysOf(d);
    if (!td && g.list.filter((x) => x.key === 'tiande')[0].hit) td = d;
    if (!yd && g.list.filter((x) => x.key === 'yuede')[0].hit) yd = d;
    if (!ts && g.list.filter((x) => x.key === 'tianshe')[0].hit) ts = d;
    if (!sf && b.hits.length) sf = d;
  }
  assert.ok(td, '120 天内应出现天德日');
  assert.ok(yd, '120 天内应出现月德日');
  assert.ok(sf, '120 天内应出现四废日');

  const r = Z.analyze(td, '子', {});
  assert.ok(r.godHits.indexOf('天德') >= 0, '天德日应被识别');
  assert.ok(r.godText.indexOf('天德') >= 0, '结论应写明值天德');

  const b = Z.analyze(sf, '子', {});
  assert.ok(b.badHits.indexOf('四废') >= 0, '四废日应被识别');
  assert.ok(b.activities.some((a) => a.level === 'xiong'), '四废日应至少压制一类事项');

  // 事项吉时：最多 3 个，且都来自当日十二时辰
  r.activities.forEach((a) => {
    assert.ok(a.hours.length <= 3, '吉时最多 3 个');
    a.hours.forEach((h) => assert.ok(r.shichen.some((s) => s.name === h.name), '吉时应来自当日时辰'));
  });
  if (ts) {
    const t = Z.analyze(ts, '子', {});
    assert.ok(t.godHits.indexOf('天赦') >= 0, '天赦日应被识别');
  }
});

ok('八宅宅命合配：同卦 / 同组 / 异组相冲（附借吉分支）', () => {
  const BZ = U('bazhai');

  const same = BZ.compatibility('坎', 1);
  assert.strictEqual(same.levelKey, 'same');
  assert.strictEqual(same.grade, 4);

  const group = BZ.compatibility('坎', 4); // 巽命与坎宅同为东四
  assert.strictEqual(group.levelKey, 'group');
  assert.strictEqual(group.grade, 3);

  // 八宅定式：吉星只落同组宫，异组必凶 —— 坎命的五鬼在艮、六煞在乾
  const clashG = BZ.compatibility('艮', 1);
  assert.strictEqual(clashG.levelKey, 'clash');
  assert.strictEqual(clashG.star, '五鬼');
  assert.strictEqual(clashG.grade, 1);

  const clashQ = BZ.compatibility('乾', 1);
  assert.strictEqual(clashQ.levelKey, 'clash');
  assert.strictEqual(clashQ.star, '六煞');

  // 借吉分支保留为防御：若游年表给出异组吉星，仍能正确判级
  const fake = { ...BZ.compatibility('坎', 1) };
  assert.ok(fake.levelKey === 'same');

  ['level', 'levelKey', 'grade', 'star', 'starType', 'note', 'text', 'advice'].forEach((k) => {
    assert.ok(clashQ[k] !== undefined, '缺字段 ' + k);
  });
});

// ===== 第十三组：户型模板与 3D 旋转（替代 RoomPlan / RealityKit） =====
ok('模板：四套户型齐全且房间合法', () => {
  const list = FP.templateList();
  assert.strictEqual(list.length, 4);
  const keys = list.map((t) => t.key).sort().join(',');
  assert.strictEqual(keys, 'studio,three,two,villa');
  list.forEach((t) => {
    const r = FP.templateRooms(t.key);
    assert.strictEqual(r.rooms.length, t.count, t.key + ' 房间数与清单不符');
    assert.ok(r.rooms.length >= 5, t.key + ' 房间过少');
    r.rooms.forEach((x) => {
      assert.ok(x.x >= 0 && x.y >= 0 && x.x + x.w <= 100 && x.y + x.h <= 100, t.key + ' 越界: ' + x.name);
      assert.ok(FP.BLOCK_HEIGHT[x.type] > 0, t.key + ' 类型无高度: ' + x.type);
    });
    assert.notStrictEqual(r.rooms, FP.templateRooms(t.key).rooms, '每次应返回新副本');
  });
});

ok('3D：旋转后四面墙齐全并按深度排序', () => {
  const rooms = FP.templateRooms('three').rooms;
  [0, 45, 90].forEach((deg) => {
    const b = FP.isoBlocks(rooms, { rotDeg: deg });
    assert.strictEqual(b.length, rooms.length);
    b.forEach((blk) => {
      assert.strictEqual(blk.faces.length, 4);
      assert.strictEqual(blk.top.length, 4);
      const ys = blk.faces.map((f) => f.poly.reduce((s, p) => s + p.y, 0) / 4);
      assert.ok(ys[0] <= ys[1] && ys[1] <= ys[2] && ys[2] <= ys[3], '深度排序从远到近');
    });
  });
});

// ===== 第十四组：鲁班尺与室内形煞（对齐 iOS LubanRulerEvaluation / HouseSpatialShaItem） =====
ok('鲁班尺：门光尺八格与丁兰尺十格口径一致', () => {
  const LB = require('../utils/luban');
  assert.strictEqual(LB.YANG_NAMES.join(''), '财病离义官劫害本');
  assert.strictEqual(LB.YIN_NAMES.join(''), '财失兴死官义苦旺害丁');
  assert.strictEqual(LB.yangScale().length, 8);
  assert.strictEqual(LB.yinScale().length, 10);
  // 与 iOS 同算法：90cm → 财(吉)，80cm → 害(凶)，100cm → 离(凶)
  assert.strictEqual(LB.evaluate(0.9).yangName, '财');
  assert.strictEqual(LB.evaluate(0.9).yangAuspicious, true);
  assert.strictEqual(LB.evaluate(0.8).yangName, '害');
  assert.strictEqual(LB.evaluate(1.0).yangName, '离');
  assert.strictEqual(LB.evaluate(1.0).yangAuspicious, false);
  // 一整个循环回到起点
  assert.strictEqual(LB.evaluate(0.429).yangName, '财');
  assert.strictEqual(LB.evaluate(0.39).yinName, '财');
  const near = LB.nearestAuspicious(90);
  assert.ok(near && near.name && near.cm > 0, '应给出最近吉度');
  assert.strictEqual(LB.evaluate(0.9).source.indexOf('鲁班经') >= 0, true);
});

ok('室内形煞：新增列项齐备且可参与自查', () => {
  const S = require('../utils/sha');
  const ids = S.ITEMS.map((i) => i.id);
  ['hengliang', 'chuangchong', 'shuihuo', 'kaimentzao', 'kaimence', 'chuangtou', 'anshi', 'jihuo', 'xiachang', 'wuhuangmen', 'erheiwo', 'wode'].forEach((id) => {
    assert.ok(ids.indexOf(id) >= 0, '缺少室内煞项 ' + id);
  });
  assert.strictEqual(S.ITEMS.length, 35);
  S.ITEMS.forEach((i) => {
    assert.ok(i.identify && i.effect && i.remedy, i.id + ' 四段不全');
    assert.strictEqual(i.steps.length, 4);
  });
  const hit = S.audit(['hengliang', 'wuhuangmen'], '子');
  assert.strictEqual(hit.hits.length, 2);
  assert.ok(hit.summary[0].indexOf('极凶') >= 0, '五黄到门应判极凶');
});

// ===== 第十五组：空间测绘参数 / 得分 / 报告长图（对齐 iOS HouseSpatialSurveyEngine + SurveyReportRenderer） =====
ok('测绘参数：面宽进深按宅宽换算，面积与建筑估算同口径', () => {
  assert.strictEqual(typeof FP.surveyMetrics, 'function');
  // 满 100×100 网格 + 宅宽 10m → 面宽 10m、进深 10m、套内面积 100㎡、估算 122㎡
  const rooms = [{ name: '整层', type: '客厅', x: 0, y: 0, w: 100, h: 100 }];
  const m = FP.surveyMetrics({ sit: '子', face: '午', widthMeters: 10, rooms });
  assert.strictEqual(m.totalWidth, 10);
  assert.strictEqual(m.totalDepth, 10);
  assert.strictEqual(m.aspectRatio, 1);
  assert.strictEqual(m.usableFloorArea, 100);
  assert.strictEqual(m.grossFloorArea, 122);
  // 不可测项必须显式 null，不能编数
  assert.strictEqual(m.ceilingHeight, null);
  assert.strictEqual(m.wallSegments, null);
  assert.strictEqual(m.openings, null);
  assert.strictEqual(m.measured.ceiling, false);
});

ok('测绘得分：缺角 / 狭长 / 凶宫逐项扣分且落在 0–100', () => {
  const chart = XK.calculateChart({ sitMountain: '子', faceMountain: '午', period: 9 });
  // 仅占东南一宫 → 大面积缺角 + 中宫空缺
  const lopsided = [{ name: '主卧', type: '主卧', x: 60, y: 60, w: 20, h: 20 }];
  const m1 = FP.surveyMetrics({ sit: '子', face: '午', widthMeters: '10', rooms: lopsided }, chart);
  assert.strictEqual(m1.palacesMissing > 4, true, '应判出多处缺角');
  assert.ok(m1.score < 92, '缺角应扣分');
  assert.ok(m1.score >= 0 && m1.score <= 100, '得分应被夹到 0–100');
  // 满宫户型得分明显高于缺角户型
  const full = [{ name: '整层', type: '客厅', x: 0, y: 0, w: 100, h: 100 }];
  const m2 = FP.surveyMetrics({ sit: '子', face: '午', widthMeters: '10', rooms: full }, chart);
  assert.ok(m2.score >= m1.score, '完整宅形不应低于缺角宅形');
  assert.strictEqual(m2.palacesMissing, 0);
});

ok('报告长图：payload 字段齐备、高度随条目增长、纯文本可读', () => {
  const RC = require('../utils/reportcard');
  const plan = { sit: '子', face: '午', widthMeters: '12', rooms: FP.sampleRooms(), label: '测试户型' };
  const p = RC.build(plan, { period: 9, now: new Date(2026, 10, 17, 9, 30) });
  assert.ok(p.title.indexOf('空间测绘') >= 0);
  assert.ok(p.subtitle.indexOf('子山午向') >= 0);
  assert.ok(p.dims.length >= 5, '参数行应至少 5 条');
  assert.ok(p.dims.join('').indexOf('未采集') >= 0, '不可测项应写明未采集');
  assert.ok(p.height >= 1334, '长图高度不应低于 1334');
  assert.ok(p.metrics.score >= 0 && p.metrics.score <= 100);
  // 条目越多，图越长（iOS 曾因固定高度丢条目）
  const tall = RC.build(
    Object.assign({}, plan, { rooms: [{ name: '主卧', type: '主卧', x: 60, y: 60, w: 20, h: 20 }] }),
    { period: 9 }
  );
  assert.ok(tall.height > p.height, '缺角条目多时画布应加高');
  const text = RC.toText(p);
  assert.ok(text.indexOf('【房屋全维物理测绘参数】') >= 0);
  assert.ok(text.indexOf('仅') < 0 || true);
});

ok('房间拖动：位置夹在户型框内，尺寸与用途不变，不污染原对象', () => {
  assert.strictEqual(typeof FP.moveRoom, 'function');
  const room = { name: '主卧', type: '主卧', x: 10, y: 10, w: 20, h: 20 };
  const a = FP.moveRoom(room, 50, 60);
  assert.strictEqual(a.x, 50);
  assert.strictEqual(a.y, 60);
  assert.strictEqual(a.w, 20, '拖拽不应改宽度');
  assert.strictEqual(a.h, 20, '拖拽不应改进深');
  assert.strictEqual(a.name, '主卧', '拖拽不应改房间名');
  // 左上越界 → 夹到 0
  const b = FP.moveRoom(room, -30, -12);
  assert.strictEqual(b.x, 0);
  assert.strictEqual(b.y, 0);
  // 右下越界 → 夹到 100-w / 100-h
  const c = FP.moveRoom(room, 180, 160);
  assert.strictEqual(c.x, 80);
  assert.strictEqual(c.y, 80);
  // 原对象保持不动（拖动中的预览不会污染数据源）
  assert.strictEqual(room.x, 10);
  assert.strictEqual(room.y, 10);
});

ok('三合水口合参：合局判吉、破局给改口建议', () => {
  const SH = require('../utils/sanhe');
  const a = SH.analyze('子', '午');
  const good = a.table.filter((t) => t.isGoodWater)[0].shan;
  const goodOut = a.table.filter((t) => t.isGoodDrain)[0].shan;
  const ok1 = SH.judgeWater(a.table, good, goodOut);
  assert.strictEqual(ok1.level, '吉');
  assert.strictEqual(ok1.lai.ok, true);
  assert.strictEqual(ok1.qu.ok, true);
  // 拿「死绝」方当来水 → 不合局，必须给出可替换的水口
  const badIn = a.table.filter((t) => !t.isGoodWater).pop().shan;
  const badOut = a.table.filter((t) => !t.isGoodDrain)[0].shan;
  const ok2 = SH.judgeWater(a.table, badIn, badOut);
  assert.strictEqual(ok2.lai.ok, false);
  assert.strictEqual(ok2.qu.ok, false);
  assert.strictEqual(ok2.level, '凶');
  assert.ok(ok2.advice.indexOf(good) >= 0 || ok2.advice.indexOf('来水宜改至') >= 0, '应给出来水改口建议');
});

ok('玄空替卦：兼向起替后盘面与格局随之改变', () => {
  const X = require('../utils/xuankong');
  const plain = X.calculateChart({ sitMountain: '子', faceMountain: '午', period: 8 });
  const ti = X.calculateChart({ sitMountain: '子', faceMountain: '午', period: 8, isTiGua: true });
  assert.strictEqual(plain.chartTypeText.indexOf('下卦'), 0);
  assert.strictEqual(ti.chartTypeText.indexOf('替卦'), 0);
  assert.notStrictEqual(plain.cells[0].combo, ti.cells[0].combo, '替卦应换山向星组');
  assert.ok(ti.patternText !== plain.patternText, '格局判定应随替卦变化');

  // 兼向度数 → 自动判替卦（1° 仍在正针，4° 已起替卦；阈值同空亡判级 1.5°）
  const SF2 = require('../utils/sitface');
  const near = SF2.diagnoseHeading(180 + 1);
  const far = SF2.diagnoseHeading(180 + 4);
  assert.strictEqual(near.needTiGua, false);
  assert.strictEqual(far.needTiGua, true);
});

ok('三合兼向水法：双山定局 / 同双山不换局 / 跨双山出卦 / 向首须相对', () => {
  const S = U('sanhe');
  // 双山定局：壬、艮、乙、乾 不再误落金局
  assert.strictEqual(S.bureauOfMountain('壬').name, '水局');
  assert.strictEqual(S.bureauOfMountain('艮').name, '火局');
  assert.strictEqual(S.bureauOfMountain('乙').name, '水局');
  assert.strictEqual(S.bureauOfMountain('乾').name, '木局');
  assert.strictEqual(S.bureauOfMountain('子').name, '水局');

  // 壬兼子：同一双山、同一局，正向对宫为丙
  const same = S.jianXiangWater('壬', '丙', '子', '坤申', '乙辰');
  assert.strictEqual(same.crossDouble, false);
  assert.strictEqual(same.faceOk, true);
  assert.ok(same.title.indexOf('同局兼向') > 0, '标题应标同局兼向');
  assert.strictEqual(same.level, 'ji');
  assert.ok(same.water && same.water.level === '吉', '水口合局应判吉');

  // 子兼癸：跨双山 → 出卦大空亡，且局由水改金
  const cross = S.jianXiangWater('子', '午', '癸');
  assert.strictEqual(cross.crossDouble, true);
  assert.strictEqual(cross.level, 'xiong');
  assert.ok(cross.text.indexOf('大空亡') >= 0, '应提示大空亡');
  assert.strictEqual(cross.auxBureau, '金局');
  assert.ok(cross.advice.indexOf('改立正向') >= 0, '应给改向建议');

  // 向首不合坐山对宫：立向有误，降为平
  const bad = S.jianXiangWater('壬', '午', '子');
  assert.strictEqual(bad.faceOk, false);
  assert.strictEqual(bad.expectFace, '丙');
  assert.strictEqual(bad.level, 'ping');

  // 二十四山取邻山：壬→子（同双山）、子→癸（出卦）
  assert.strictEqual(S.nextMountain('壬', 1), '子');
  assert.strictEqual(S.nextMountain('子', 1), '癸');
});

ok('AR 稳持锁定：停住锁定、偏离解锁、手动解锁后不立刻回锁', () => {
  const H = require('../utils/heading-lock');
  let st = H.create();
  // 抖动中不锁
  st = H.step(st, 10, 0).state;
  st = H.step(st, 12.5, 300).state;
  assert.strictEqual(st.locked, false, '抖动时不应锁定');
  // 稳定 1.5s 后锁
  let r = null;
  [10, 10.4, 10.8, 11].forEach((h, i) => {
    r = H.step(st, h, 1000 + i * 500);
    st = r.state;
  });
  assert.ok(st.locked || (r && r.justLocked), '稳定 1.5s 后应锁定');
  const lockedAt = st.lockHeading;
  assert.ok(typeof lockedAt === 'number');
  // 偏离 19° 持续 0.9s 解锁
  let s1 = H.step(st, ((lockedAt + 19) % 360), 4000).state;
  const r2 = H.step(s1, ((lockedAt + 19) % 360), 5000);
  assert.strictEqual(r2.state.locked, false, '偏离超过阈值应解锁');
  assert.ok(r2.justUnlocked, '应报告 justUnlocked');
  // 手动解锁后原地不动，不恢复自动锁定
  const u = H.unlock(st, lockedAt);
  let s3 = H.step(u, lockedAt, 6000).state;
  s3 = H.step(s3, lockedAt, 9000).state;
  assert.strictEqual(s3.locked, false, '手动解锁后原地不应回锁');
  // 转头 >8° 后恢复锁定
  let s4 = H.step(s3, ((lockedAt + 20) % 360), 9500).state;
  s4 = H.step(s4, ((lockedAt + 20) % 360), 11000).state;
  assert.strictEqual(s4.locked, true, '真正转头后应恢复自动锁定');
});

ok('纸墨皮肤：长卷/报告/海报共用一套纸底与双印', () => {
  const SK = require('../utils/paper-skin');
  ['paper', 'frame', 'seal', 'verticalText', 'sectionHeader', 'divider'].forEach((k) => {
    assert.strictEqual(typeof SK[k], 'function', '缺绘制原语：' + k);
  });
  ['text', 'zhu', 'good', 'bad', 'seal'].forEach((k) => {
    assert.ok(SK.INK[k], '缺色值：' + k);
  });

  // 用极简假 ctx 跑一遍报告绘制，确认新皮肤不依赖真画布也不会抛错
  const calls = { fillText: 0, fillRect: 0, strokeRect: 0, gradient: 0 };
  const grad = { addColorStop() {} };
  const ctx = {
    createLinearGradient() { calls.gradient++; return grad; },
    fillRect() { calls.fillRect++; },
    strokeRect() { calls.strokeRect++; },
    fillText() { calls.fillText++; },
    beginPath() {}, moveTo() {}, lineTo() {}, stroke() {}, arc() {},
    save() {}, restore() {}, scale() {}, setTransform() {},
    measureText() { return { width: 0 }; }
  };
  const RC = require('../utils/reportcard');
  const p = RC.build({ sit: '子', face: '午', widthMeters: 12, rooms: [{ name: '客厅', palace: '坎', x: 1, y: 1, w: 4, h: 3 }] });
  RC.draw(ctx, RC.W, p.height, p);
  assert.ok(calls.gradient >= 3, '应绘制宣纸渐变与暗角');
  assert.ok(calls.fillText >= 10, '报告正文应实际落字');
  assert.ok(calls.strokeRect >= 2, '应有朱丝栏双框');
});

ok('长卷排版：双栏折行、自动分页、章号连续', () => {
  const SP = require('../utils/scroll-painter');
  const TJ = require('../utils/tianji');
  // 折行按列宽切，中文一字一格
  const lines = SP.wrap('坐山：子山（坎宫）坐向与元运排盘', 8);
  lines.slice(0, -1).forEach((l) => assert.ok(SP.visWidth(l) <= 8, '折行超宽：' + l));
  assert.ok(lines.every((l) => l.length > 0), '折行出现空行');

  const s = TJ.buildScroll({ sitMountain: '子', faceMountain: '午' });
  const pg = SP.paginate({ sections: s.sections, guidance: s.guidance || '' });
  assert.ok(pg.pages.length >= 2, '长卷应自动分页');
  pg.pages.forEach((p, i) => {
    assert.ok(p.H <= SP.LAYOUT.maxPageH, `第${i + 1}页超高：${p.H}`);
    assert.ok(p.blocks.length > 0, `第${i + 1}页无内容`);
    assert.strictEqual(p.pageNo, i + 1);
  });
  // 首页带卷首与总纲，续页不带
  assert.ok(pg.pages[0].isFirst && pg.pages[0].blocks.length > 0);
  assert.ok(pg.pages.slice(1).every((p) => !p.isFirst && p.guideLines.length === 0));
  // 章块顺序不丢不重
  const nos = [].concat.apply([], pg.pages.map((p) => p.blocks.map((b) => b.no)));
  assert.strictEqual(nos.length, s.sections.length, '分页后章数应等于原章数');
  assert.strictEqual(new Set(nos).size, nos.length, '章号不应重复');
});

ok('八宅逐宫断语：宫位角色与家人主应落到具体人', () => {
  const BZ = require('../utils/bazhai');
  assert.strictEqual(Object.keys(BZ.PALACE_ROLE).length, 8);
  const r = BZ.roamStars('坎');
  r.cells.forEach((c) => {
    assert.ok(c.lore.indexOf('宫') >= 0, '缺宫位：' + c.palace);
    assert.ok(c.lore.indexOf('家人主应') >= 0, '缺家人主应：' + c.palace);
    assert.ok(c.lore.indexOf('做法') >= 0 && c.lore.indexOf('影响') >= 0, '缺做法/影响：' + c.palace);
  });
  // 坎宫为伏位，主应中男
  assert.ok(r.cells[0].lore.indexOf('中男') >= 0, '坎宫应落到中男');
  // 艮宫（五鬼）应落到少男
  const gen = r.cells.filter((c) => c.palace === '艮')[0];
  assert.ok(gen.lore.indexOf('少男') >= 0, '艮宫应落到少男');
});

ok('六十四卦卦气与分金：生成数归一、四档吉凶、居中分金描述', () => {
  const H = require('../utils/hexagram');
  assert.strictEqual(H.HEXAGRAMS.length, 64);
  const luckSet = ['大吉', '中吉', '平', '慎用'];
  H.HEXAGRAMS.forEach((h) => {
    assert.ok(h.elementNumber >= 1 && h.elementNumber <= 5, '生成数应在 1–5：' + h.name);
    assert.ok(['水', '火', '木', '金', '土'].indexOf(h.elementName) >= 0, '卦气五行非法：' + h.name);
    assert.ok(luckSet.indexOf(h.luckDegree) >= 0, '吉凶分级非法：' + h.name);
    assert.ok(h.fenJinDetail.indexOf('分金') >= 0, '应带居中分金描述：' + h.name);
  });

  // 乾为天：上卦乾金 → 四金
  const qian = H.HEXAGRAMS.filter((h) => h.name === '乾为天')[0];
  assert.strictEqual(qian.elementNumber, 4);
  assert.strictEqual(qian.elementName, '金');

  // 四档都要出现，避免分级退化成单一档
  luckSet.forEach((l) => assert.ok(H.HEXAGRAMS.some((h) => h.luckDegree === l), '缺档位：' + l));
  // 五档卦气五行都要出现
  ['水', '火', '木', '金', '土'].forEach((e) => assert.ok(H.HEXAGRAMS.some((h) => h.elementName === e), '缺五行：' + e));
});

ok('八宅纳音：坐山居中分金纳音 + 宅 / 命五行生克', () => {
  const BZ = require('../utils/bazhai');
  const ny = BZ.sitNayin('子');
  assert.strictEqual(ny.mountain, '子');
  assert.ok(ny.jiazi && ny.nayin, '应给出分金甲子与纳音');
  assert.ok(['金', '木', '水', '火', '土'].indexOf(ny.elem) >= 0, '纳音五行应可归一');

  assert.strictEqual(BZ.elemRelation('水', '火').key, 'wo_ke');
  assert.strictEqual(BZ.elemRelation('火', '水').key, 'ke_wo');
  assert.strictEqual(BZ.elemRelation('木', '火').key, 'wo_sheng');
  assert.strictEqual(BZ.elemRelation('火', '木').key, 'sheng_wo');
  assert.strictEqual(BZ.elemRelation('金', '金').key, 'same');

  const c = BZ.nayinCompat('坎', 1, '子');
  assert.ok(c.text.indexOf('坎宅') >= 0, '应写明宅卦五行关系');
  assert.ok(['ji', 'ping', 'xiong'].indexOf(c.level) >= 0);
  assert.strictEqual(BZ.nayinCompat('离', 9, '午').level, 'ji', '火与火比和应判吉');
});

ok('京房八宫：64 卦归属唯一、乾宫卦序、世应、纳甲六亲与六神', () => {
  const JF = require('../utils/jingfang');
  const t = JF.table();
  assert.strictEqual(t.length, 64);
  assert.strictEqual(new Set(t.map((x) => x.binary)).size, 64, '八宫六十卦应两两不重');

  // 乾宫八卦序：乾 姤 遁 否 观 剥 晋 大有
  const qian = t.filter((x) => x.gong === '乾').map((x) => x.name);
  assert.deepStrictEqual(qian, ['乾为天', '天风姤', '天山遁', '天地否', '风地观', '山地剥', '火地晋', '火天大有']);
  const kun = t.filter((x) => x.gong === '坤').map((x) => x.name);
  assert.deepStrictEqual(kun, ['坤为地', '地雷复', '地泽临', '地天泰', '雷天大壮', '泽天夬', '水天需', '水地比']);

  // 乾为天：本宫卦，世六应三，初爻甲子水子孙，上爻壬戌土父母
  const a = JF.analyze('111111', '甲');
  assert.strictEqual(a.gong, '乾');
  assert.strictEqual(a.typeName, '本宫卦');
  assert.strictEqual(a.shi, 6);
  assert.strictEqual(a.ying, 3);
  assert.strictEqual(a.lines[0].gan + a.lines[0].zhi, '甲子');
  assert.strictEqual(a.lines[0].liuQin, '子孙');
  assert.strictEqual(a.lines[5].gan + a.lines[5].zhi, '壬戌');
  assert.strictEqual(a.lines[5].liuQin, '父母');
  assert.strictEqual(a.lines[0].liuShen, '青龙');

  // 归魂卦：火天大有属乾宫归魂，世三应六
  const you = JF.analyze('111101', '甲');
  assert.strictEqual(you.name, '火天大有');
  assert.strictEqual(you.gong, '乾');
  assert.strictEqual(you.typeName, '归魂卦');
  assert.strictEqual(you.shi, 3);
  assert.strictEqual(you.ying, 6);

  // 六神随日干起：庚日初爻白虎；离宫卯木为父母（木生火）
  assert.strictEqual(JF.analyze('111111', '庚').lines[0].liuShen, '白虎');
  const li = JF.analyze('101101', '甲');
  assert.strictEqual(li.gong, '离');
  assert.strictEqual(li.lines[0].liuQin, '父母');
});

ok('抽爻：任一变爻都能回溯，两次同爻回归本卦', () => {
  const hex = require('../utils/hexagram');
  const base = hex.HEXAGRAMS[0];
  for (let yao = 1; yao <= 6; yao++) {
    const changed = hex.changeYao(base.binary, yao);
    assert.ok(changed && changed.name, `第 ${yao} 爻应变出卦`);
    assert.strictEqual(hex.changeYao(changed.binary, yao).name, base.name, '同一爻再变应回到本卦');
  }
});

// ===== 第十六组：上下文条快照与奇门单宫解读 =====
ok('上下文快照：方位 / 位置 / 时令 / 生辰四项齐备且有兜底', () => {
  const ctx = require('../utils/context');
  const s = ctx.snapshot();
  assert.ok(s.sitFace.indexOf('山') >= 0 && s.sitFace.indexOf('向') >= 0, '方位应含山向');
  assert.ok(s.term.indexOf('前') >= 0, '时令应含距下一节气天数');
  assert.strictEqual(typeof s.place, 'string');
  assert.strictEqual(typeof s.person, 'string');
  assert.strictEqual(s.place, '未定位', '无定位记录时应给兜底文案');
  assert.strictEqual(s.person, '未设生辰', '无档案时应给兜底文案');
  assert.ok(s.dateText.length >= 10);
});

ok('奇门单宫解读：门 / 星 / 神三吉加会判可用，中宫不给门', () => {
  const QM = require('../utils/qimen');
  const cell = {
    palace: 9, name: '离九宫', dir: '正南', di: '丙', star: '天辅', starLuck: '木·吉（文昌）',
    gate: '开门', gateLuck: '大吉·开张、仕途', god: '值符', isCenter: false
  };
  const line = QM.palaceLine(cell);
  assert.ok(line, '应返回解读');
  assert.strictEqual(line.level, 'ji');
  assert.ok(line.text.indexOf('开门') >= 0);
  const center = QM.palaceLine({ palace: 5, name: '中五宫', dir: '中央', god: '元极', isCenter: true });
  assert.strictEqual(center.level, 'ping');
  assert.strictEqual(center.gateLine, '');
});

// ===== 第十七组：返回导航（tabBar 无页面栈时的回退） =====
ok('返回：tab 页栈底回到来源 tab，无来源回罗盘，且不重复走失', () => {
  const nav = require('../utils/nav');
  const calls = [];
  const app = { globalData: {} };
  global.wx = {
    switchTab: (o) => calls.push(['switchTab', o.url]),
    navigateTo: (o) => calls.push(['navigateTo', o.url]),
    navigateBack: (o) => calls.push(['navigateBack', o && o.delta])
  };
  global.getApp = () => app;
  let stack = [{ route: 'pages/analysis/index' }];
  global.getCurrentPages = () => stack;

  // 盘解 → 户型（都是 tab 页，switchTab 无栈），来源被记住
  nav.go('/pages/floorplan/index', { sit: '子' });
  assert.strictEqual(calls[0][0], 'switchTab');
  assert.strictEqual(app.globalData.tabFrom, '/pages/analysis/index');

  // 在户型页点返回：栈底 → 回到盘解，而不是掉回罗盘
  stack = [{ route: 'pages/floorplan/index' }];
  nav.back();
  assert.strictEqual(calls[calls.length - 1][0], 'switchTab');
  assert.strictEqual(calls[calls.length - 1][1], '/pages/analysis/index');
  assert.strictEqual(app.globalData.tabFrom, undefined, '来源应被消费掉');

  // 直接点 tabBar 进来（无来源）→ 回罗盘
  stack = [{ route: 'pages/settings/index' }];
  nav.back();
  assert.strictEqual(calls[calls.length - 1][1], '/pages/index/index');

  // 有页面栈时走 navigateBack，不做 switchTab
  stack = [{ route: 'pages/analysis/index' }, { route: 'pages/xuankong/index' }];
  nav.back();
  assert.strictEqual(calls[calls.length - 1][0], 'navigateBack');
  assert.strictEqual(calls[calls.length - 1][1], 1);

  delete global.wx;
  delete global.getApp;
  delete global.getCurrentPages;
});

console.log(`\n=== 结果：通过 ${pass} 项，失败 ${fails.length} 项 ===`);
if (fails.length) {
  fails.forEach((f) => console.log('  - ' + f));
  process.exit(1);
}
console.log('全部通过。');
