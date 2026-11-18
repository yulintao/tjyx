/**
 * spatial-findings.js
 * 空间勘查几何自动判煞编排，移植自 iOS ARRoomPlanCaptureView.computeSpatialFengshuiFindings。
 * iOS 输入为 ARKit CapturedRoom（门/窗/物体带 3D transform）；小程序无 RoomPlan，
 * 故改为「凡平面几何能推出的部分照搬判据，缺数据的项给出待核对提示」：
 *   - 水火冲：厨房与卫浴房间中心距 ≤ 2.1m（由户型矩形直接可算）
 *   - 门宽鲁班尺：给定入户门宽（米）即按门光尺判吉凶
 *   - 穿堂煞 / 门冲床：给出门窗/门床的点位与法向即可按 iOS 阈值判定
 * 所有判据阈值与 iOS 完全一致，只是输入源换成机型可得的数据。
 */

const LUBAN = require('./luban');

const THRESHOLD = {
  doorWidthMin: 0.45,      // iOS: mainDoor.dimensions.x > 0.45
  throughDist: [1.8, 12.0], // iOS: dist >= 1.8 && dist <= 12.0
  throughAlign: 0.88,       // iOS: alignment >= 0.88
  throughLateral: 0.65,     // iOS: lateral <= 0.65
  bedDist: [0.8, 4.8],      // iOS: dist >= 0.8 && dist <= 4.8
  bedAlign: 0.85,           // iOS: alignment >= 0.85
  bedLateral: 0.70,         // iOS: lateral <= 0.70
  waterFireDist: 2.1        // iOS: dist <= 2.1
};

function dist(a, b) {
  const dx = a.x - b.x;
  const dy = (a.y === undefined ? (a.z || 0) : a.y) - (b.y === undefined ? (b.z || 0) : b.y);
  return Math.sqrt(dx * dx + dy * dy);
}

/** 归一化法向 */
function norm(v) {
  const len = Math.sqrt((v.nx || 0) * (v.nx || 0) + (v.ny || 0) * (v.ny || 0));
  if (len < 1e-4) return null;
  return { nx: v.nx / len, ny: v.ny / len };
}

/** 门法向与指向的对齐度 + 横向偏移（iOS: alignment / lateral） */
function alignmentAndLateral(door, target) {
  const n = norm(door);
  if (!n) return null;
  const d = dist(door, target);
  if (d < 1e-6) return null;
  const dir = { x: (target.x - door.x) / d, y: ((target.y === undefined ? (target.z || 0) : target.y) - ((door.y === undefined ? (door.z || 0) : door.y))) / d };
  const dot = Math.abs(n.nx * dir.x + n.ny * dir.y);
  const lateral = d * Math.sqrt(Math.max(0, 1 - dot * dot));
  return { alignment: dot, lateral, distance: d };
}

/** 1. 入户门宽鲁班尺判定 */
function doorWidthFinding(doorWidthMeters) {
  const w = Number(doorWidthMeters);
  if (!isFinite(w) || w <= THRESHOLD.doorWidthMin) return null;
  const ev = LUBAN.evaluate(w);
  return `门宽 ${w.toFixed(2)}m · 鲁班尺【${ev.yangName}】(${ev.yangAuspicious ? '吉门' : '失度'})`;
}

/** 2. 穿堂煞：门对窗直通（iOS alignment>=0.88 && lateral<=0.65, dist 1.8~12m） */
function throughDraftFinding(door, windows) {
  let best = null;
  (windows || []).forEach((win) => {
    const r = alignmentAndLateral(door, win);
    if (!r) return;
    if (r.distance >= THRESHOLD.throughDist[0] && r.distance <= THRESHOLD.throughDist[1]
      && r.alignment >= THRESHOLD.throughAlign && r.lateral <= THRESHOLD.throughLateral) {
      if (!best || r.distance < best.distance) best = r;
    }
  });
  return best ? `⚠️ 穿堂煞：门窗对冲直通 (间距 ${best.distance.toFixed(1)}m)` : null;
}

/** 3. 门冲床：房门直对卧床（iOS alignment>=0.85 && lateral<=0.70, dist 0.8~4.8m） */
function doorToBedFinding(door, beds) {
  let best = null;
  (beds || []).forEach((bed) => {
    const r = alignmentAndLateral(door, bed);
    if (!r) return;
    if (r.distance >= THRESHOLD.bedDist[0] && r.distance <= THRESHOLD.bedDist[1]
      && r.alignment >= THRESHOLD.bedAlign && r.lateral <= THRESHOLD.bedLateral) {
      if (!best || r.distance < best.distance) best = r;
    }
  });
  return best ? `⚠️ 门冲床：房门直对卧床 (${best.distance.toFixed(1)}m)` : null;
}

/** 4. 水火冲：厨灶与卫浴紧邻（iOS dist<=2.1m） */
function waterFireFinding(stoves, toilets) {
  let best = null;
  (stoves || []).forEach((s) => {
    (toilets || []).forEach((t) => {
      const d = dist(s, t);
      if (d <= THRESHOLD.waterFireDist && (!best || d < best.distance)) best = { distance: d };
    });
  });
  return best ? `⚠️ 水火冲：厨灶与卫浴紧邻 (${best.distance.toFixed(1)}m)` : null;
}

/**
 * 编排入口：从户型平面数据推导 findings。
 * plan: { rooms:[{name,type,x,y,w,h}], widthMeters, openings:{doors,windows,beds,stoves,toilets} }
 * 房间坐标 0–100，x 自西向东、y 自北向南；widthMeters 为宅宽，进深按 aspectRatio 折算。
 */
function computeSpatialFindings(plan) {
  const findings = [];
  if (!plan || !plan.rooms || !plan.rooms.length) return findings;
  const openings = plan.openings || {};
  const widthMeters = Number(plan.widthMeters) > 0 ? Number(plan.widthMeters) : 10;

  // 由户型矩形直接算水火冲（厨房中心 vs 卫生间中心）
  const sx = widthMeters / 100;
  const aspect = Number(plan.aspectRatio) > 0 ? Number(plan.aspectRatio) : 1;
  const sy = (widthMeters / aspect) / 100;
  const center = (r) => ({ x: (r.x + r.w / 2) * sx, y: (r.y + r.h / 2) * sy });
  const kitchens = plan.rooms.filter((r) => /厨房|灶/.test(r.type || r.name || '')).map(center);
  const baths = plan.rooms.filter((r) => /卫生间|卫浴|厕所/.test(r.type || r.name || '')).map(center);
  const wf = waterFireFinding(openings.stoves && openings.stoves.length ? openings.stoves : kitchens,
    openings.toilets && openings.toilets.length ? openings.toilets : baths);
  if (wf) findings.push(wf);

  // 若提供了开口/家具数据，则按 iOS 判据补上门宽 / 穿堂 / 门冲床
  const fd = doorWidthFinding(openings.doorWidth);
  if (fd) findings.push(fd);
  (openings.doors || []).forEach((door) => {
    const td = throughDraftFinding(door, openings.windows);
    if (td) findings.push(td);
    const bd = doorToBedFinding(door, openings.beds);
    if (bd) findings.push(bd);
  });

  if (!findings.length) {
    findings.push('平面几何未发现明显水火冲；门宽 / 穿堂 / 门冲床需在现场录入门窗与家具点位后再自动判定。');
  }
  return findings;
}

/**
 * 全屋空间形煞体检，移植自 iOS HouseSpatialSurveyEngine.analyzeSpatialHouse。
 * iOS 输入为 RoomPlan 3D（walls/openings/beams/objects 带法向），小程序无 3D，
 * 故按「凡 2D 户型矩形能推出的判据照搬」原则实现，其余 3D 项在说明中标注。
 * 返回 iOS HouseSpatialShaItem 同构条目 + 92 分起评的扣分链。
 */
const SPATIAL_SEVERITY = { auspicious: 'auspicious', warning: 'warning', critical: 'critical' };

function makeItem(title, severity, location, detail, lore, solution, scoreDelta) {
  return { title, severity, locationName: location, detail,
    fengshuiLore: lore, solution, scoreDelta };
}

function analyzeSpatialHouse2D(plan) {
  const items = [];
  if (!plan || !plan.rooms || !plan.rooms.length) {
    return { items, score: 92, note: '尚未录入户型房间，无法体检。' };
  }
  const rooms = plan.rooms;
  const widthMeters = Number(plan.widthMeters) > 0 ? Number(plan.widthMeters) : 10;
  const aspect = Number(plan.aspectRatio) > 0 ? Number(plan.aspectRatio) : 1;
  const sx = widthMeters / 100;
  const sy = (widthMeters / aspect) / 100;
  const center = (r) => ({ x: (r.x + r.w / 2) * sx, y: (r.y + r.h / 2) * sy });
  const isKitchen = (r) => /厨房|灶/.test(r.type || r.name || '');
  const isBath = (r) => /卫生间|卫浴|厕所/.test(r.type || r.name || '');
  let score = 92;

  // A. 中宫受污 / 火烧中宫：卫浴/厨房中心落入九宫中宫盒（中心 ±1/6 跨度）
  const allX = rooms.map((r) => r.x).concat(rooms.map((r) => r.x + r.w));
  const allY = rooms.map((r) => r.y).concat(rooms.map((r) => r.y + r.h));
  const minX = Math.min.apply(null, allX), maxX = Math.max.apply(null, allX);
  const minY = Math.min.apply(null, allY), maxY = Math.max.apply(null, allY);
  const ccx = (minX + maxX) / 2 * sx, ccy = (minY + maxY) / 2 * sy;
  const boxHalfX = (maxX - minX) * sx / 6, boxHalfY = (maxY - minY) * sy / 6;
  const inCenter = (p) => Math.abs(p.x - ccx) <= boxHalfX && Math.abs(p.y - ccy) <= boxHalfY;

  rooms.forEach((r) => {
    if (isBath(r) && inCenter(center(r))) {
      items.push(makeItem('中宫受污 (水浸太极)', SPATIAL_SEVERITY.critical, `房屋中宫·${r.name || r.type}`,
        '卫浴落在大宅中心，湿污之气浸染太极中宫，主家运起伏、健康受扰。',
        '中宫为全宅太极根节点，宜静宜洁，忌水浸火烤。',
        '保持中宫干燥通风、门常闭；若无法移位，以明亮暖光与阔叶绿植化解湿气。', -16));
      score -= 16;
    }
    if (isKitchen(r) && inCenter(center(r))) {
      items.push(makeItem('火烧中宫 (燥火焚心)', SPATIAL_SEVERITY.critical, `房屋中宫·${r.name || r.type}`,
        '厨灶位于中宫，燥火焚灼太极，主心绪不宁、口舌是非。',
        '中宫忌火，火性上扬扰动宅心。',
        '灶位尽量外移；无法移位则加强中宫散热与通风，避免明火正对宅心。', -14));
      score -= 14;
    }
  });

  // B. 水火相邻：厨房/灶 与 卫浴 中心距 ≤ 2.1m
  const kitchens = rooms.filter(isKitchen).map(center);
  const baths = rooms.filter(isBath).map(center);
  let waterFire = null;
  kitchens.forEach((k) => baths.forEach((t) => {
    const d = dist(k, t);
    if (d <= THRESHOLD.waterFireDist && (!waterFire || d < waterFire.d)) waterFire = { d };
  }));
  if (waterFire) {
    items.push(makeItem('水火相冲 (灶厕相邻)', SPATIAL_SEVERITY.warning,
      `灶台 ⟷ 卫浴 (间距 ${waterFire.d.toFixed(1)}m)`,
      '厨灶与卫浴紧邻，水火交战于宅内，主家人争执、健康损耗。',
      '水火不宜贴邻，尤忌灶台与马桶共墙正反两侧。',
      '以土黄色材质通关、保持两侧干燥洁净；改造涉及隔墙时咨询专业人员。', -7));
    score -= 7;
  }

  // C. 户型狭长：进深/开间 > 2.2
  const ratio = aspect > 0 ? aspect : 1;
  if (ratio > 2.2) {
    items.push(makeItem('户型狭长 (深长损明)', SPATIAL_SEVERITY.warning, '整体户型轮廓',
      `全屋进深是开间的 ${ratio.toFixed(1)} 倍，形如长巷，中段采光通风弱。`,
      '方正者气厚，狭长者气薄。',
      '中部走道采用明亮照明与镜面扩容，多设绿植增补生旺之气。', -6));
    score -= 6;
  }

  // D. 门宽鲁班尺：有实测门宽时纳入（与 iOS 门光尺一致）
  const openings = plan.openings || {};
  const dw = Number(openings.doorWidth);
  if (isFinite(dw) && dw > THRESHOLD.doorWidthMin) {
    const ev = LUBAN.evaluate(dw);
    if (ev.yangAuspicious) {
      items.push(makeItem('鲁班门光尺 · 大门得吉', SPATIAL_SEVERITY.auspicious,
        `入户大门 (宽 ${dw.toFixed(2)}m)`, `大门宽度落入鲁班门光尺【${ev.yangName}】吉字门。`,
        '门合吉度，气聚而入。', '保持玄关整洁明亮，门前不堆杂物。', 5));
      score += 5;
    } else {
      items.push(makeItem('鲁班门光尺 · 大门失度', SPATIAL_SEVERITY.warning,
        `入户大门 (宽 ${dw.toFixed(2)}m)`, `大门宽度落入鲁班门光尺【${ev.yangName}】凶度字门，门气略有亏耗。`,
        '门不合度，气散难聚。', '可优先确认门槛、地垫和通道尺寸，保持入口平整防滑。', -4));
      score -= 4;
    }
  }

  // E. 门对门 / 穿堂 / 门冲床：有开口法向数据时按 iOS 判据补判（阈值同前）
  (openings.doors || []).forEach((door) => {
    if (throughDraftFinding(door, openings.windows)) {
      items.push(makeItem('穿堂穿心煞 (一箭穿心)', SPATIAL_SEVERITY.critical, '大门 ⟷ 窗',
        '门窗对冲直通，气流一箭穿心，主财气不聚。', '气喜回旋，忌直冲直泄。',
        '设玄关屏风或矮柜缓冲，或挂门帘、摆阔叶绿植。', -15));
      score -= 15;
    }
    if (doorToBedFinding(door, openings.beds)) {
      items.push(makeItem('房门冲床 (冲撞身魂)', SPATIAL_SEVERITY.warning, '房门 ⟷ 卧床',
        '房门与床铺形成直线气流，影响安眠与隐私。', '门开气入直射人身，动静失衡。',
        '微调床头朝向或位置避开门冲直线，必要时设隔断或长帘。', -8));
      score -= 8;
    }
  });

  score = Math.max(0, Math.min(100, score));
  const note = '3D 专属项（横梁压顶、尖角冲射、镜面照床等需梁/物体法向）小程序无 RoomPlan 数据，未纳入自动扣分；请现场核对。';
  return { items, score, note };
}

module.exports = {
  THRESHOLD,
  doorWidthFinding,
  throughDraftFinding,
  doorToBedFinding,
  waterFireFinding,
  computeSpatialFindings,
  analyzeSpatialHouse2D
};
