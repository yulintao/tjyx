/**
 * floorplan.js
 * 户型九宫：房间矩形录入 → 归宫 → 按玄空山向星与房间功能审计 → 缺角 / 覆盖检查
 * 对应 iOS Models/FloorplanEngine.swift 的九宫投影与房间审计能力（AR 扫描部分改为手绘录入）
 */

const { PALACE_INFO } = require('./xuankong');

/** 二十四山（子居中 0°，顺时针 15° 一山），与 sitface 同一口径，此处内联避免循环依赖 */
const MOUNTAIN_24 = ['子', '癸', '丑', '艮', '寅', '甲', '卯', '乙', '辰', '巽', '巳', '丙', '午', '丁', '未', '坤', '申', '庚', '酉', '辛', '戌', '乾', '亥', '壬'];

/** 门窗开口：图上方为北（正北朝上），边法线角度按此换算 */
const OPENING_SIDE = {
  north: { label: '北（上）', normal: 0 },
  east: { label: '东（右）', normal: 90 },
  south: { label: '南（下）', normal: 180 },
  west: { label: '西（左）', normal: 270 }
};
const OPENING_TYPE = { door: '门', window: '窗' };

const PALACE_BY_CELL = {
  '0-0': 6, '1-0': 1, '2-0': 8,
  '0-1': 7, '1-1': 5, '2-1': 3,
  '0-2': 2, '1-2': 9, '2-2': 4
};

const ROOM_RULES = {
  主卧: { good: [1, 8, 9, 6], bad: [2, 5, 7], text: '主卧宜得生气、旺气；忌二黑五黄与七赤。' },
  卧室: { good: [1, 4, 6, 8], bad: [2, 5, 7], text: '卧室宜静宜吉，忌病符、关煞、破军。' },
  客厅: { good: [8, 9, 1, 6], bad: [2, 5], text: '客厅主门面，宜当旺之星，忌五黄二黑压中。' },
  厨房: { good: [8, 9, 1], bad: [5, 6, 2], text: '厨房属火，忌六白乾宫（火烧天门）、五黄与二黑。' },
  卫生间: { good: [2, 5, 7], bad: [1, 4, 6, 8, 9], text: '卫浴宜压凶方，忌占吉位；吉位设厕主泄气。' },
  书房: { good: [4, 1, 6, 9], bad: [2, 5, 7], text: '书房宜文昌四绿、一白、六白，忌病符与破军。' },
  储物: { good: [2, 5, 7], bad: [1, 4, 8, 9], text: '储物宜置凶方，化煞为用。' },
  餐厅: { good: [8, 9, 1], bad: [2, 5], text: '餐厅宜旺气，忌五黄二黑临门。' }
};

function palaceOfPoint(x, y) {
  const col = Math.min(2, Math.max(0, Math.floor(x / 33.34)));
  const row = Math.min(2, Math.max(0, Math.floor(y / 33.34)));
  return PALACE_BY_CELL[`${col}-${row}`];
}

function roomCenter(room) {
  return { x: room.x + room.w / 2, y: room.y + room.h / 2 };
}

/** 房间覆盖的宫位（按中心与四角采样） */
function palacesOfRoom(room) {
  const pts = [
    roomCenter(room),
    { x: room.x + 1, y: room.y + 1 },
    { x: room.x + room.w - 1, y: room.y + 1 },
    { x: room.x + 1, y: room.y + room.h - 1 },
    { x: room.x + room.w - 1, y: room.y + room.h - 1 }
  ];
  const set = [];
  pts.forEach((p) => {
    const pal = palaceOfPoint(p.x, p.y);
    if (set.indexOf(pal) < 0) set.push(pal);
  });
  return set;
}

/**
 * 审计
 * @param {Array} rooms [{name, type, x, y, w, h}] 坐标 0–100，x 自西向东，y 自北向南
 * @param {object} chart xuankong.calculateChart 的结果
 */
function audit(rooms, chart) {
  const cells = {};
  chart.cells.forEach((c) => { cells[c.palace] = c; });

  const results = rooms.map((room) => {
    const palaces = palacesOfRoom(room);
    const mainPalace = palaceOfPoint(roomCenter(room).x, roomCenter(room).y);
    const cell = cells[mainPalace];
    const rule = ROOM_RULES[room.type] || ROOM_RULES['卧室'];

    const stars = [cell.shan, cell.xiang];
    let level = 'ping';
    let score = 0;
    const notes = [];

    if (stars.some((s) => s === 5)) { score -= 3; notes.push('山向星见五黄，主关煞病灾，忌久居。'); }
    if (stars.some((s) => s === 2)) { score -= 2; notes.push('山向星见二黑，主脾胃、妇科隐患。'); }
    if (room.type === '厨房' && mainPalace === 6) { score -= 3; notes.push('厨房落乾宫，火烧天门，主老父心烦、头面之疾。'); }
    if (room.type === '卫生间' && rule.bad.indexOf(stars[0]) >= 0) { score -= 2; notes.push('卫浴占吉位，泄宅气，主财丁两退。'); }
    if (rule.good.indexOf(Math.min(stars[0], stars[1])) >= 0) { score += 2; notes.push('得吉星临宫，功能与星气相符。'); }
    if (room.type === '主卧' && (stars[0] === chart.period || stars[1] === chart.period)) { score += 3; notes.push('主卧得当期旺星，人丁安和、事业得力。'); }

    if (score >= 2) level = 'ji';
    else if (score <= -2) level = 'xiong';

    let advice = '可用，按常规布局即可。';
    if (level === 'xiong') advice = '建议调整：' + (room.type === '卧室' || room.type === '主卧' ? '更换房间或以铜葫芦、六帝钱化泄，床位避开五黄方。' : '可保留但减少使用频次，或以金属器物化泄土煞。');
    if (level === 'ji') advice = '房位得宜，可重点使用（' + (rule.text) + '）';

    return {
      name: room.name || room.type,
      type: room.type,
      palaces,
      mainPalace,
      palaceName: PALACE_INFO[mainPalace].name,
      dir: PALACE_INFO[mainPalace].dir,
      shan: cell.shan,
      xiang: cell.xiang,
      combo: `${cell.shan}${cell.xiang}`,
      level,
      score,
      notes,
      advice
    };
  });

  // 覆盖 / 缺角检查
  const covered = {};
  results.forEach((r) => r.palaces.forEach((p) => { covered[p] = true; }));
  const missing = [1, 2, 3, 4, 6, 7, 8, 9].filter((p) => !covered[p]);

  const area = rooms.reduce((s, r) => s + r.w * r.h, 0);
  const centerRoom = results.filter((r) => r.mainPalace === 5);

  const summary = [];
  if (missing.length) {
    summary.push(`缺角宫位：${missing.map((p) => PALACE_INFO[p].name + '（' + PALACE_INFO[p].dir + '）').join('、')}。缺角主该方人事不聚，可用摆件、屏风补气。`);
  } else {
    summary.push('九宫皆有所属，宅形完整，无明显缺角。');
  }
  if (centerRoom.length) {
    summary.push(`中宫被「${centerRoom.map((r) => r.name).join('、')}」占据：中宫宜空宜静，被功能房压中主宅气受制。`);
  }
  const xiongRooms = results.filter((r) => r.level === 'xiong');
  if (xiongRooms.length) {
    summary.push(`重点调整：${xiongRooms.map((r) => r.name + '（' + r.palaceName + '）').join('、')}。`);
  }

  return {
    rooms: results,
    missing,
    area: Math.round(area),
    summary,
    levelCount: {
      ji: results.filter((r) => r.level === 'ji').length,
      ping: results.filter((r) => r.level === 'ping').length,
      xiong: results.filter((r) => r.level === 'xiong').length
    }
  };
}

/** 面积加权重心（中宫立极用，返回 0–100 坐标） */
function centroidOf(rooms) {
  if (!rooms.length) return { x: 50, y: 50 };
  let sx = 0;
  let sy = 0;
  let sa = 0;
  rooms.forEach((r) => {
    const a = r.w * r.h;
    sx += (r.x + r.w / 2) * a;
    sy += (r.y + r.h / 2) * a;
    sa += a;
  });
  if (!sa) return { x: 50, y: 50 };
  return { x: sx / sa, y: sy / sa };
}

/** 单位换算：宅宽（米）→ 每个坐标单位对应米数；100 坐标单位 = 宅宽 */
function unitOf(widthMeters) {
  const w = Number(widthMeters);
  if (!w || w <= 0) return 0;
  return w / 100;
}

/** 实际面积（㎡） */
function areaSqm(rooms, widthMeters) {
  const u = unitOf(widthMeters);
  const area = rooms.reduce((s, r) => s + r.w * r.h, 0);
  return u ? Math.round(area * u * u * 10) / 10 : 0;
}

/**
 * 房间移动：把房间左上角落到 (x, y)，并夹在 0–100 网格内（不越出户型框）
 * 只改位置，不改尺寸与用途，供平面图拖拽使用
 * @param {Object} room {x,y,w,h,...}
 * @param {number} x 目标左上角横坐标（0–100）
 * @param {number} y 目标左上角纵坐标（0–100）
 */
function moveRoom(room, x, y) {
  if (!room) return null;
  const w = Number(room.w) || 0;
  const h = Number(room.h) || 0;
  const maxX = Math.max(0, 100 - w);
  const maxY = Math.max(0, 100 - h);
  const nx = Math.max(0, Math.min(maxX, Number(x) || 0));
  const ny = Math.max(0, Math.min(maxY, Number(y) || 0));
  return Object.assign({}, room, {
    x: Math.round(nx * 10) / 10,
    y: Math.round(ny * 10) / 10
  });
}

/**
 * 九宫覆盖率：逐宫取样，判断该宫被房间覆盖的比例，用于量化缺角程度
 * @param {Array} rooms
 * @param {number} n 每宫每边取样数
 */
function coverageByPalace(rooms, n) {
  const N = n || 12;
  const out = [];
  for (let row = 0; row < 3; row++) {
    for (let col = 0; col < 3; col++) {
      const palace = PALACE_BY_CELL[`${col}-${row}`];
      let hit = 0;
      let total = 0;
      for (let i = 0; i < N; i++) {
        for (let j = 0; j < N; j++) {
          const x = col * 33.34 + (i + 0.5) * (33.34 / N);
          const y = row * 33.34 + (j + 0.5) * (33.34 / N);
          total++;
          const inside = rooms.some((r) => x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h);
          if (inside) hit++;
        }
      }
      const ratio = total ? hit / total : 0;
      out.push({
        palace,
        name: PALACE_INFO[palace].name,
        dir: PALACE_INFO[palace].dir,
        ratio,
        percent: Math.round(ratio * 100),
        status: ratio >= 0.75 ? 'full' : (ratio >= 0.4 ? 'part' : 'missing')
      });
    }
  }
  return out;
}

/** 房间在九宫中的实际占比（用于「某宫被某房占据」判断） */
function roomFill(room) {
  const ratio = (room.w * room.h) / (33.34 * 33.34);
  return Math.round(ratio * 100) / 100;
}

// 各功能房体块高度（等轴测示意用，非真实层高）
const BLOCK_HEIGHT = {
  主卧: 26, 客厅: 26, 卧室: 22, 餐厅: 22, 书房: 20, 厨房: 18, 卫生间: 14, 储物: 14
};

/**
 * 等轴测体块：把 0–100 平面矩形投影成 3D 块，返回可直接落笔的多边形面
 * 说明：仅示意体量关系，不做真实尺寸渲染（小程序无 SceneKit，改用 Canvas 投影）
 */
function isoBlocks(rooms, opts) {
  const cos30 = 0.866;
  const sin30 = 0.5;
  const rot = ((opts && opts.rotDeg) || 0) * Math.PI / 180;
  const cr = Math.cos(rot);
  const sr = Math.sin(rot);
  const C = 50;
  // 平面绕户型中心旋转，再投影，用于拖动旋转查看（替代 RealityKit 浏览）
  const rotPt = (x, y) => {
    const dx = x - C;
    const dy = y - C;
    return [C + dx * cr - dy * sr, C + dx * sr + dy * cr];
  };
  const proj = (x, y, z) => ({
    x: (x - y) * cos30,
    y: (x + y) * sin30 - z
  });

  return rooms.map((r) => {
    const h = BLOCK_HEIGHT[r.type] || 20;
    const corners = [
      rotPt(r.x, r.y), rotPt(r.x + r.w, r.y), rotPt(r.x + r.w, r.y + r.h), rotPt(r.x, r.y + r.h)
    ];
    const bottom = corners.map((c) => proj(c[0], c[1], 0));
    const top = corners.map((c) => proj(c[0], c[1], h));
    const faces = [
      { key: 'south', poly: [bottom[3], bottom[2], top[2], top[3]], shade: '#2b3a55' },
      { key: 'east', poly: [bottom[2], bottom[1], top[1], top[2]], shade: 'rgba(120,145,190,0.55)' },
      { key: 'north', poly: [bottom[1], bottom[0], top[0], top[1]], shade: 'rgba(38,52,74,0.9)' },
      { key: 'west', poly: [bottom[0], bottom[3], top[3], top[0]], shade: 'rgba(90,110,150,0.45)' }
    ].sort((a, b) => {
      const da = a.poly.reduce((s, p) => s + p.y, 0) / a.poly.length;
      const db = b.poly.reduce((s, p) => s + p.y, 0) / b.poly.length;
      return da - db;
    });
    return {
      name: r.name || r.type,
      type: r.type,
      height: h,
      top,
      faces,
      south: faces.filter((f) => f.key === 'south')[0].poly,
      east: faces.filter((f) => f.key === 'east')[0].poly
    };
  });
}

/** 新建示例户型（三室两厅） */
function sampleRooms() {
  return [
    { name: '主卧', type: '主卧', x: 4, y: 4, w: 28, h: 27 },
    { name: '次卧', type: '卧室', x: 36, y: 4, w: 26, h: 27 },
    { name: '厨房', type: '厨房', x: 66, y: 4, w: 30, h: 20 },
    { name: '客厅', type: '客厅', x: 4, y: 35, w: 40, h: 30 },
    { name: '餐厅', type: '餐厅', x: 48, y: 38, w: 20, h: 22 },
    { name: '卫生间', type: '卫生间', x: 70, y: 24, w: 26, h: 42 },
    { name: '书房', type: '书房', x: 70, y: 66, w: 26, h: 30 },
    { name: '客卧', type: '卧室', x: 4, y: 69, w: 30, h: 27 },
    { name: '储物', type: '储物', x: 38, y: 69, w: 26, h: 27 }
  ];
}

/**
 * 户型模板库（替代 iOS RoomPlan 扫描的效率层：无扫描能力时，用常见户型一键铺底再微调）
 * 坐标口径与 sampleRooms 一致：0–100，x 自西向东，y 自北向南
 */
const TEMPLATES = {
  studio: {
    label: '一室一厅（约 55㎡）',
    widthMeters: '8',
    rooms: [
      { name: '主卧', type: '主卧', x: 4, y: 4, w: 52, h: 52 },
      { name: '客厅', type: '客厅', x: 4, y: 58, w: 52, h: 38 },
      { name: '厨房', type: '厨房', x: 58, y: 4, w: 38, h: 28 },
      { name: '卫生间', type: '卫生间', x: 58, y: 34, w: 38, h: 26 },
      { name: '书房', type: '书房', x: 58, y: 62, w: 38, h: 34 }
    ]
  },
  two: {
    label: '两室一厅（约 78㎡）',
    widthMeters: '10',
    rooms: [
      { name: '主卧', type: '主卧', x: 4, y: 4, w: 42, h: 46 },
      { name: '次卧', type: '卧室', x: 4, y: 54, w: 42, h: 42 },
      { name: '客厅', type: '客厅', x: 48, y: 4, w: 48, h: 40 },
      { name: '厨房', type: '厨房', x: 48, y: 46, w: 22, h: 22 },
      { name: '餐厅', type: '餐厅', x: 72, y: 46, w: 24, h: 22 },
      { name: '卫生间', type: '卫生间', x: 48, y: 70, w: 22, h: 26 },
      { name: '书房', type: '书房', x: 72, y: 70, w: 24, h: 26 }
    ]
  },
  three: {
    label: '三室两厅（约 120㎡）',
    widthMeters: '12',
    rooms: [
      { name: '主卧', type: '主卧', x: 4, y: 4, w: 32, h: 44 },
      { name: '次卧', type: '卧室', x: 38, y: 4, w: 26, h: 28 },
      { name: '厨房', type: '厨房', x: 66, y: 4, w: 30, h: 20 },
      { name: '客厅', type: '客厅', x: 4, y: 50, w: 40, h: 46 },
      { name: '餐厅', type: '餐厅', x: 46, y: 34, w: 22, h: 24 },
      { name: '卫生间', type: '卫生间', x: 70, y: 26, w: 26, h: 42 },
      { name: '书房', type: '书房', x: 46, y: 60, w: 22, h: 36 },
      { name: '客卧', type: '卧室', x: 70, y: 70, w: 26, h: 26 }
    ]
  },
  villa: {
    label: '大平层 / 四室（约 180㎡）',
    widthMeters: '15',
    rooms: [
      { name: '主卧', type: '主卧', x: 4, y: 4, w: 28, h: 40 },
      { name: '次卧', type: '卧室', x: 34, y: 4, w: 22, h: 24 },
      { name: '书房', type: '书房', x: 34, y: 30, w: 22, h: 26 },
      { name: '客厅', type: '客厅', x: 58, y: 4, w: 38, h: 44 },
      { name: '餐厅', type: '餐厅', x: 58, y: 50, w: 22, h: 22 },
      { name: '厨房', type: '厨房', x: 82, y: 50, w: 14, h: 22 },
      { name: '卫生间', type: '卫生间', x: 4, y: 46, w: 28, h: 22 },
      { name: '客卧', type: '卧室', x: 4, y: 70, w: 28, h: 26 },
      { name: '储物', type: '储物', x: 34, y: 58, w: 22, h: 38 }
    ]
  }
};

function templateRooms(key) {
  const t = TEMPLATES[key];
  if (!t) return null;
  return { label: t.label, widthMeters: t.widthMeters, rooms: t.rooms.map((r) => Object.assign({}, r)) };
}

function templateList() {
  return Object.keys(TEMPLATES).map((k) => ({ key: k, label: TEMPLATES[k].label, count: TEMPLATES[k].rooms.length }));
}

/**
 * 缺角专项断语（对齐 iOS FloorplanEngine.missingCornerAudits）
 * 每宫给出「缺则何伤 + 化解 + 出处」，均本于传统宅法诸书，非本程序臆造。
 */
const MISSING_CORNER_LORE = {
  1: {
    dir: '正北坎宫',
    hurt: '坎为水、为中男、主肾与泌尿。此方缺角，主中男不利、腰肾耳疾，事业多阻，智谋难展。',
    remedy: '以水生之：可置水养植物、深色水盘，或以金属圆器补其气；忌再放燥土重物压之。',
    source: '出典：《阳宅三要·论宅形缺角》《八宅明镜·九宫缺陷》，家宅九宫缺一，主本宫所应之人与事受亏。'
  },
  8: {
    dir: '东北艮宫',
    hurt: '艮为山、为少男、主脾胃与关节。此方缺角，主少男不旺、人丁稀少，脾胃虚弱，事多阻隔难成。',
    remedy: '以土石补之：可置黄玉、陶瓮、盆景点缀；艮为鬼门，尤忌此方空洞穿堂。',
    source: '出典：《阳宅三要·论宅形缺角》《相宅经·鬼门宜实》，艮位空虚主丁口不聚。'
  },
  3: {
    dir: '正东震宫',
    hurt: '震为雷、为长男、主肝胆与手足。此方缺角，主长男不利、贵人失位，肝胆手足之疾，功名难显。',
    remedy: '以木补之：可置高大绿植、青碧之色；震方忌见金器重压，金克木则贵气折。',
    source: '出典：《八宅明镜·九宫缺陷》《阳宅集成·震方宜高》，震位缺则长子与名位受损。'
  },
  4: {
    dir: '东南巽宫',
    hurt: '巽为风、为长女、主文昌与财源。此方缺角，主长女不安、文昌受损，财气不聚、进财多阻。',
    remedy: '以木火相生补之：可置文昌塔、绿植并开窗纳气；忌重物压塞、储物堆积。',
    source: '出典：《阳宅三要·论宅形缺角》《相宅经·巽为财位》，巽缺则文运财源两伤。'
  },
  9: {
    dir: '正南离宫',
    hurt: '离为火、为中女、主心血与眼目。此方缺角，主中女不安、心血眼疾，文采功名受阻，心气不宁。',
    remedy: '以火木补之：可置红紫暖色灯饰、向阳开窗；忌水器直冲此方，水火相激主心疾。',
    source: '出典：《八宅明镜·九宫缺陷》《阳宅集成·离方宜明》，离位缺则明堂失耀、名位不显。'
  },
  2: {
    dir: '西南坤宫',
    hurt: '坤为地、为老母、主脾胃与家宅安宁。此方缺角，主女主人多病、脾胃之疾，家宅不宁、田产有损。',
    remedy: '以土厚补之：可置陶器、黄石、方形厚重家具；坤为母位，忌此处空旷无靠。',
    source: '出典：《阳宅三要·论宅形缺角》《相宅经·坤位宜厚》，坤缺则母位失养、家宅少安。'
  },
  7: {
    dir: '正西兑宫',
    hurt: '兑为泽、为少女、主口舌与肺。此方缺角，主少女不安、口舌是非频生，肺与呼吸之疾，易招小人。',
    remedy: '以金水补之：可置金属圆器、白金色饰物；兑为口，忌此方凹陷如缺口，主是非不休。',
    source: '出典：《八宅明镜·九宫缺陷》《阳宅集成·兑方宜圆》，兑缺则口舌无端、少女受损。'
  },
  6: {
    dir: '西北乾宫',
    hurt: '乾为天、为老父、主男主寿元与官运。此方缺角，主男主人事业受阻、寿元有损，官运不显、贵人不来。',
    remedy: '以金土补之：可置铜器、白玉、圆形重器；乾为天门，忌此方空虚见水，主男主失势。',
    source: '出典：《阳宅三要·论宅形缺角》《相宅经·乾为天门》，乾缺则男主与官贵两亏。'
  },
  5: {
    dir: '中宫',
    hurt: '中宫为宅心、主全家气机。中宫受挤压或空缺，主全家运势停滞，诸事不顺，财禄不聚，人气涣散。',
    remedy: '以静守补之：中宫宜空明净洁，忌重物、油烟、杂物堆积；若被挤压，宜开敞或以吉器安镇。',
    source: '出典：《阳宅三要·论宅心》《八宅明镜·中宫宜静》，宅心受压则九宫气机俱滞。'
  }
};

/**
 * 缺角专项审计：按九宫覆盖率判定，逐宫给出断语、化解与出处
 * @param {Array} rooms
 */
function missingCornerAudits(rooms) {
  const coverage = coverageByPalace(rooms || []);
  return coverage.map((c) => {
    const lore = MISSING_CORNER_LORE[c.palace] || {};
    const missing = c.status === 'missing';
    return {
      palace: c.palace,
      name: c.name,
      dir: c.dir,
      ratio: c.ratio,
      percent: c.percent,
      status: c.status,
      level: missing ? 'xiong' : (c.status === 'part' ? 'ping' : 'ji'),
      title: missing
        ? `${c.name}（${c.dir}）缺角：覆盖仅 ${c.percent}%`
        : (c.status === 'part' ? `${c.name}（${c.dir}）气略偏：覆盖 ${c.percent}%` : `${c.name}（${c.dir}）完整`),
      hurt: missing ? lore.hurt : '',
      remedy: missing ? lore.remedy : '',
      source: missing ? lore.source : ''
    };
  });
}

/**
 * 导出 DXF（R12 ASCII）：按房间矩形逐边 LINE，中心注 TEXT
 * @param {Array} rooms 0–100 坐标
 * @param {object} opts { widthMeters, sit, face, title }
 * @returns {string} DXF 文本
 */
/** 规整门窗开口：room 为房间下标，side 取四边，pos 为边上起点占比，width 为占边比例 */
function normalizeOpenings(list, rooms) {
  const arr = Array.isArray(list) ? list : [];
  const roomArr = Array.isArray(rooms) ? rooms : [];
  const out = [];
  arr.forEach((o) => {
    const idx = Number(o && o.room);
    if (!(idx >= 0 && idx < roomArr.length)) return;
    const side = String((o && o.side) || '');
    if (!OPENING_SIDE[side]) return;
    const type = o && o.type === 'window' ? 'window' : 'door';
    const pos = Math.max(0, Math.min(0.95, Number(o.pos) || 0));
    const width = Math.max(0.05, Math.min(0.9, Number(o.width) || 0.3));
    out.push({ room: idx, side, type, pos, width });
  });
  return out;
}

/** 门窗计数 */
function openingSummary(list) {
  const arr = Array.isArray(list) ? list : [];
  return {
    doors: arr.filter((o) => o.type === 'door').length,
    windows: arr.filter((o) => o.type === 'window').length,
    total: arr.length
  };
}

/**
 * 开口落点：算出每扇门窗的中心坐标、朝外法线角度、所属九宫
 * 图上方为北（0°），右为东（90°），下为南（180°），左为西（270°）
 */
function openingSites(list, rooms) {
  const arr = normalizeOpenings(list, rooms);
  const roomArr = Array.isArray(rooms) ? rooms : [];
  return arr.map((o, i) => {
    const r = roomArr[o.room];
    const along = o.pos + o.width / 2;
    let x;
    let y;
    if (o.side === 'north') {
      x = r.x + r.w * along;
      y = r.y;
    } else if (o.side === 'south') {
      x = r.x + r.w * along;
      y = r.y + r.h;
    } else if (o.side === 'west') {
      x = r.x;
      y = r.y + r.h * along;
    } else {
      x = r.x + r.w;
      y = r.y + r.h * along;
    }
    const angle = OPENING_SIDE[o.side].normal;
    const palace = palaceOfPoint(x, y);
    return {
      key: `${o.room}-${o.side}-${i}`,
      room: o.room,
      roomName: r.name,
      type: o.type,
      typeText: OPENING_TYPE[o.type],
      side: o.side,
      sideText: OPENING_SIDE[o.side].label,
      x: Math.round(x * 10) / 10,
      y: Math.round(y * 10) / 10,
      angle,
      palace,
      palaceName: PALACE_INFO[palace] ? PALACE_INFO[palace].name.replace('宫', '') : '',
      dir: PALACE_INFO[palace] ? PALACE_INFO[palace].dir : ''
    };
  });
}

/**
 * 以入户门朝外法线判向首（图上方为北的前提下）
 * @returns {{angle:number, face:string, sit:string, roomName:string, note:string}|null}
 */
function facingFromDoor(list, rooms) {
  const sites = openingSites(list, rooms).filter((s) => s.type === 'door');
  if (!sites.length) return null;
  const door = sites[0];
  const idx = Math.round((((door.angle % 360) + 360) % 360) / 15) % 24;
  const faceM = MOUNTAIN_24[idx];
  const sitM = MOUNTAIN_24[(idx + 12) % 24];
  return {
    angle: door.angle,
    face: faceM,
    sit: sitM,
    roomName: door.roomName,
    note: `按「${door.roomName}」${door.sideText}侧入户门朝外法线判定：图上方为北，向首 ${faceM}、坐 ${sitM}；若底图上方不是正北，请以罗盘实测的坐向为准。`
  };
}

function toDXF(rooms, opts) {
  const o = opts || {};
  const wm = Number(o.widthMeters) > 0 ? Number(o.widthMeters) : 10;
  // 1 坐标单位 = 宅宽/100 米 = 10*wm 毫米
  const s = wm * 10;
  const lines = [];
  const push = (...vals) => lines.push(...vals);

  push('0', 'SECTION', '2', 'HEADER');
  push('9', '$INSBASE', '10', '0.0', '20', '0.0', '30', '0.0');
  push('9', '$INSUNITS', '70', '6'); // 毫米（对齐 iOS generateCAD_DXF）
  push('9', '$EXTMIN', '10', '0.0', '20', '0.0', '30', '0.0');
  push('9', '$EXTMAX', '10', String(100 * s), '20', String(100 * s), '30', '0.0');
  push('0', 'ENDSEC');

  // iOS 同源 8 图层定义
  const DXF_LAYERS = ['OUTLINE', 'WALLS_BEARING', 'WALLS_PARTITION', 'DOORS', 'WINDOWS',
    'BEAMS', 'ROOM_LABELS', 'TAIJI_CENTER', 'DIMENSIONS'];
  push('0', 'SECTION', '2', 'TABLES');
  push('0', 'TABLE', '2', 'LAYER', '70', String(DXF_LAYERS.length));
  DXF_LAYERS.forEach((name) => {
    push('0', 'LAYER', '2', name, '70', '0', '62', '7', '6', 'CONTINUOUS');
  });
  push('0', 'ENDTAB');
  push('0', 'ENDSEC');

  push('0', 'SECTION', '2', 'ENTITIES');

  // 宅基外框
  push('0', 'LWPOLYLINE');
  push('8', 'OUTLINE');
  push('90', '4');
  [[0, 0], [100, 0], [100, 100], [0, 100]].forEach((p) => {
    push('10', String(p[0] * s), '20', String(p[1] * s));
  });

  // 太极中宫立极：CIRCLE + 十字（iOS TAIJI_CENTER 图层）
  const tcx = Number(o.centerX) >= 0 ? Number(o.centerX) : 50;
  const tcy = Number(o.centerY) >= 0 ? Number(o.centerY) : 50;
  const r = Math.max(60, wm * 15);
  push('0', 'CIRCLE', '8', 'TAIJI_CENTER');
  push('10', (tcx * s).toFixed(2), '20', (tcy * s).toFixed(2), '30', '0.0', '40', r.toFixed(2));
  [[tcx * s - r * 2, tcy * s, tcx * s + r * 2, tcy * s],
   [tcx * s, tcy * s - r * 2, tcx * s, tcy * s + r * 2]].forEach((seg) => {
    push('0', 'LINE', '8', 'TAIJI_CENTER');
    push('10', seg[0].toFixed(2), '20', seg[1].toFixed(2), '30', '0.0');
    push('11', seg[2].toFixed(2), '21', seg[3].toFixed(2), '31', '0.0');
  });

  // 外框净距标注（iOS DIMENSIONS 图层）
  push('0', 'LINE', '8', 'DIMENSIONS');
  push('10', '0.0', '20', String(-r * 3), '30', '0.0');
  push('11', String(100 * s), '21', String(-r * 3), '31', '0.0');

  (rooms || []).forEach((r) => {
    const layer = (r.type || 'ROOM').replace(/[\r\n]/g, '');
    const x0 = r.x * s;
    const y0 = r.y * s;
    const x1 = (r.x + r.w) * s;
    const y1 = (r.y + r.h) * s;
    const pts = [[x0, y0], [x1, y0], [x1, y1], [x0, y1]];
    for (let i = 0; i < 4; i++) {
      const a = pts[i];
      const b = pts[(i + 1) % 4];
      push('0', 'LINE', '8', layer);
      push('10', a[0].toFixed(2), '20', a[1].toFixed(2), '30', '0.0');
      push('11', b[0].toFixed(2), '21', b[1].toFixed(2), '31', '0.0');
    }
    // 房间名
    push('0', 'TEXT', '8', layer);
    push('10', ((r.x + r.w / 2) * s).toFixed(2), '20', ((r.y + r.h / 2) * s).toFixed(2), '30', '0.0');
    push('40', String(Math.max(100, Math.round(wm * 30))));
    push('1', (r.name || r.type || 'ROOM').replace(/[\r\n]/g, ''));
    push('72', '1');
    push('11', ((r.x + r.w / 2) * s).toFixed(2), '21', ((r.y + r.h / 2) * s).toFixed(2), '31', '0.0');
  });

  // 门窗开口：DOORS / WINDOWS 图层，按房间边上的 pos/width 折算线段
  openingSites(o.openings, rooms).forEach((site) => {
    const layer = site.type === 'window' ? 'WINDOWS' : 'DOORS';
    const room = rooms[site.room];
    const half = (site.type === 'window' ? 0.18 : 0.12) / 2;
    let p1;
    let p2;
    if (site.side === 'north' || site.side === 'south') {
      const y = site.side === 'north' ? room.y : room.y + room.h;
      p1 = [(site.x - room.w * half) * s, y * s];
      p2 = [(site.x + room.w * half) * s, y * s];
    } else {
      const x = site.side === 'west' ? room.x : room.x + room.w;
      p1 = [x * s, (site.y - room.h * half) * s];
      p2 = [x * s, (site.y + room.h * half) * s];
    }
    push('0', 'LINE', '8', layer);
    push('10', p1[0].toFixed(2), '20', p1[1].toFixed(2), '30', '0.0');
    push('11', p2[0].toFixed(2), '21', p2[1].toFixed(2), '31', '0.0');
    push('0', 'TEXT', '8', layer);
    push('10', ((p1[0] + p2[0]) / 2).toFixed(2), '20', ((p1[1] + p2[1]) / 2).toFixed(2), '30', '0.0');
    push('40', String(Math.max(80, Math.round(wm * 20))));
    push('1', site.typeText);
    push('72', '1');
    push('11', ((p1[0] + p2[0]) / 2).toFixed(2), '21', ((p1[1] + p2[1]) / 2).toFixed(2), '31', '0.0');
  });

  // 坐向标注
  if (o.sit && o.face) {
    push('0', 'TEXT', '8', 'ORIENT');
    push('10', String(50 * s), '20', String(50 * s), '30', '0.0');
    push('40', String(Math.max(160, Math.round(wm * 60))));
    push('1', `坐${o.sit}向${o.face}`);
  }

  push('0', 'ENDSEC');
  push('0', 'EOF');
  return lines.join('\r\n') + '\r\n';
}

/** 宅谱 JSON 序列化（含坐向、宽度、房间、中宫立极点） */
function planToJSON(plan) {
  const p = plan || {};
  return JSON.stringify({
    app: 'yanxiang-luopan',
    kind: 'floorplan',
    version: 1,
    savedAt: new Date().toISOString(),
    label: p.label || '',
    sit: p.sit || '',
    face: p.face || '',
    widthMeters: p.widthMeters || '10',
    pivot: p.pivot || null,
    openings: normalizeOpenings(p.openings, p.rooms || []),
    rooms: p.rooms || []
  }, null, 2);
}

/**
 * 解析宅谱 JSON，返回规整后的宅谱对象；不合法返回 { error }
 */
function parsePlanJSON(text) {
  let obj;
  try {
    obj = JSON.parse(String(text || ''));
  } catch (e) {
    return { error: 'JSON 解析失败，请检查文件内容' };
  }
  if (!obj || !Array.isArray(obj.rooms)) return { error: '缺少 rooms 数组，非本程序导出的宅谱' };
  const rooms = obj.rooms.map((r) => ({
    name: String(r.name || r.type || '房间'),
    type: String(r.type || '卧室'),
    x: Math.max(0, Math.min(100, Number(r.x) || 0)),
    y: Math.max(0, Math.min(100, Number(r.y) || 0)),
    w: Math.max(2, Math.min(100, Number(r.w) || 10)),
    h: Math.max(2, Math.min(100, Number(r.h) || 10))
  })).filter((r) => r.x + r.w <= 101 && r.y + r.h <= 101);
  if (!rooms.length) return { error: 'rooms 内容为空或越界' };
  return {
    label: obj.label || '',
    sit: obj.sit || '',
    face: obj.face || '',
    widthMeters: String(obj.widthMeters || '10'),
    pivot: obj.pivot && typeof obj.pivot.x === 'number' ? obj.pivot : null,
    openings: normalizeOpenings(obj.openings, rooms),
    rooms
  };
}

/**
 * 空间测绘参数与空间得分
 * 对齐 iOS `HouseSpatialSurveyEngine.analyzeSpatialHouse` 的输出字段（尺寸 / 面积 / 比例 / 得分 / 形煞），
 * 但小程序只有 2D 矩形房间（无墙体线段、门窗开孔、LiDAR 净层高）：
 * 可测项照算，不可测项置 null 并由调用方显示「未采集」，不臆造数值。
 * @param {object} plan { sit, face, widthMeters, rooms, pivot }
 * @param {object} chart 玄空盘（可选，用于统计凶宫房间）
 */
function surveyMetrics(plan, chart) {
  const p = plan || {};
  const rooms = Array.isArray(p.rooms) ? p.rooms : [];
  const wm = Number(p.widthMeters) > 0 ? Number(p.widthMeters) : 10;
  const u = wm / 100;
  const round2 = (v) => Math.round(v * 100) / 100;
  const round1 = (v) => Math.round(v * 10) / 10;

  let minX = 100;
  let maxX = 0;
  let minY = 100;
  let maxY = 0;
  rooms.forEach((r) => {
    minX = Math.min(minX, r.x);
    maxX = Math.max(maxX, r.x + r.w);
    minY = Math.min(minY, r.y);
    maxY = Math.max(maxY, r.y + r.h);
  });
  if (!rooms.length || maxX <= minX || maxY <= minY) {
    minX = 0;
    minY = 0;
    maxX = 100;
    maxY = 100;
  }

  const totalWidth = round2((maxX - minX) * u); // 开间面宽（米）
  const totalDepth = round2((maxY - minY) * u); // 进深（米）
  // iOS usableArea = min(房间面积和, footprint包围盒面积)，防止重叠房间虚增面积
  const footprint = totalWidth * totalDepth;
  const rawUsable = areaSqm(rooms, wm);
  const usable = footprint > 0 ? Math.min(rawUsable, round2(footprint)) : rawUsable; // 套内净面积（㎡）
  // iOS：grossArea = max(usable × 1.22, 包围盒面积)
  const gross = Math.max(round1(usable * 1.22), round1(totalWidth * totalDepth));
  const aspectRatio = totalWidth > 0 ? round2(totalDepth / totalWidth) : 0;

  const coverage = coverageByPalace(rooms);
  const audits = missingCornerAudits(rooms);
  const missing = audits.filter((a) => a.status === 'missing');
  const partial = audits.filter((a) => a.status === 'part');
  const centerCell = coverage.filter((c) => c.palace === 5)[0] || null;
  const fullCount = coverage.filter((c) => c.status === 'full').length;

  // 门窗开口：手工录入即视为已采集（不再写「未采集」）
  const opens = normalizeOpenings(p.openings, rooms);
  const openSum = openingSummary(opens);

  let xiongRooms = [];
  if (chart && rooms.length) {
    try {
      xiongRooms = audit(rooms, chart).rooms.filter((r) => r.level === 'xiong');
    } catch (e) {
      xiongRooms = [];
    }
  }

  // 空间得分：基准 92 分（与 iOS 同基准），只按可测项扣分
  let score = 92;
  score -= Math.min(24, missing.filter((m) => m.palace !== 5).length * 6);
  if (centerCell) {
    if (centerCell.status === 'missing') score -= 10;
    else if (centerCell.status === 'part') score -= 5;
  }
  if (aspectRatio > 2.2) score -= 8;
  else if (aspectRatio > 1.8) score -= 4;
  score -= Math.min(16, xiongRooms.length * 4);
  if (fullCount < 6) score -= 6;
  score = Math.max(0, Math.min(100, Math.round(score)));

  return {
    sit: p.sit || '',
    face: p.face || '',
    label: p.label || `${p.sit || ''}山${p.face || ''}向 · ${rooms.length} 间 · ${usable}㎡`,
    roomCount: rooms.length,
    totalWidth,
    totalDepth,
    aspectRatio,
    usableFloorArea: usable,
    grossFloorArea: gross,
    ceilingHeight: null, // 未采集
    wallSegments: null, // 未采集
    openings: openSum.total ? openSum : null,
    openingSites: openingSites(p.openings, rooms),
    facingByDoor: facingFromDoor(p.openings, rooms),
    palacesFull: fullCount,
    palacesPart: partial.length,
    palacesMissing: missing.length,
    missingCorners: missing,
    partialCorners: partial,
    center: centerCell ? { name: centerCell.name, ratio: centerCell.ratio, status: centerCell.status } : null,
    xiongRooms,
    score,
    scoreNote:
      '基准 92 分，按缺角（每宫 −6，上限 −24）、中宫受压（缺 −10 / 气偏 −5）、进深面宽比（>1.8 −4，>2.2 −8）、凶宫房间（每间 −4，上限 −16）、九宫完整度（满宫 <6 再 −6）扣分；净层高、墙体段数小程序无 LiDAR 采集，标注「未采集」不计分；门窗开口为手工录入，录了才计入清单、不参与扣分。',
    measured: { ceiling: false, walls: false, openings: opens.length > 0 }
  };
}

/**
 * 多房源 PK 横向对比评分，1:1 移植自 iOS FloorplanView.evaluatePKMetric。
 * iOS: rawScore = 82 + 吉*4 - 中凶*5 - 极凶*11 + (命卦匹配 ? 8 : -4)，clamp(38,99)
 * 小程序 audit 只分 ji/ping/xiong 三档，故中凶取 ping、极凶取 xiong；命卦匹配由调用方传入。
 * @param {Array} rooms 房间
 * @param {object} chart 玄空盘（XK.calculateChart 结果）
 * @param {object} opts { kuaMatch: boolean|null } 命卦是否匹配，null 表示未设宅主不参与加减
 */
function evaluatePKMetric(rooms, chart, opts) {
  const o = opts || {};
  const a = audit(rooms || [], chart);
  const counts = a.levelCount || { ji: 0, ping: 0, xiong: 0 };
  const ausp = counts.ji || 0;
  const warn = counts.ping || 0;
  const sev = counts.xiong || 0;
  const hasKua = typeof o.kuaMatch === 'boolean';
  const raw = 82 + ausp * 4 - warn * 5 - sev * 11 + (hasKua ? (o.kuaMatch ? 8 : -4) : 0);
  const score = Math.max(38, Math.min(99, raw));
  return {
    score,
    rawScore: raw,
    auspiciousCount: ausp,
    warningCount: warn,
    severeCount: sev,
    kuaMatch: hasKua ? o.kuaMatch : null,
    level: score >= 80 ? '优' : (score >= 60 ? '良' : '待改善'),
    formula: `82 + 吉${ausp}×4 − 平${warn}×5 − 凶${sev}×11${hasKua ? (o.kuaMatch ? ' + 命卦相配8' : ' − 命卦不合4') : ''} = ${raw} → ${score}`
  };
}

module.exports = {
  evaluatePKMetric,
  PALACE_BY_CELL,
  ROOM_RULES,
  BLOCK_HEIGHT,
  MISSING_CORNER_LORE,
  palaceOfPoint,
  palacesOfRoom,
  centroidOf,
  areaSqm,
  moveRoom,
  surveyMetrics,
  coverageByPalace,
  missingCornerAudits,
  roomFill,
  isoBlocks,
  audit,
  sampleRooms,
  TEMPLATES,
  templateRooms,
  templateList,
  toDXF,
  normalizeOpenings,
  openingSummary,
  openingSites,
  facingFromDoor,
  OPENING_SIDE,
  OPENING_TYPE,
  planToJSON,
  parsePlanJSON
};
