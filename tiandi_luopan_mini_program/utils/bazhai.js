/**
 * bazhai.js
 * 八宅明镜：命卦、东西四命、大游年八星、宅卦配星、家人配房
 * 对齐 iOS Models/BaZhaiEngine.swift 的命卦与游年推导。
 */

const GUA_INFO = {
  1: { name: '坎', full: '坎水', elem: '水', group: '东四命', symbol: '☵' },
  2: { name: '坤', full: '坤土', elem: '土', group: '西四命', symbol: '☷' },
  3: { name: '震', full: '震木', elem: '木', group: '东四命', symbol: '☳' },
  4: { name: '巽', full: '巽木', elem: '木', group: '东四命', symbol: '☴' },
  6: { name: '乾', full: '乾金', elem: '金', group: '西四命', symbol: '☰' },
  7: { name: '兑', full: '兑金', elem: '金', group: '西四命', symbol: '☱' },
  8: { name: '艮', full: '艮土', elem: '土', group: '西四命', symbol: '☶' },
  9: { name: '离', full: '离火', elem: '火', group: '东四命', symbol: '☲' }
};

// 后天八卦顺时针次序：乾 → 坎 → 艮 → 震 → 巽 → 离 → 坤 → 兑
const CLOCKWISE_PALACES = ['乾', '坎', '艮', '震', '巽', '离', '坤', '兑'];

const GUA_NUM_BY_NAME = { 坎: 1, 坤: 2, 震: 3, 巽: 4, 乾: 6, 兑: 7, 艮: 8, 离: 9 };

// 大游年歌：卦名为伏位，其后 7 字依次对应该卦顺时针方向的 7 个宫
const ROAM_SONGS = {
  乾: '六天五祸绝延生',
  坎: '五天生延绝祸六',
  艮: '六绝祸生延天五',
  震: '延生祸绝五天六',
  巽: '天五六祸生绝延',
  离: '六五绝延祸生天',
  坤: '天延绝生祸五六',
  兑: '生祸延绝六五天'
};

const STAR_INFO = {
  生: {
    name: '生气',
    star: '贪狼',
    type: 'ji',
    rank: 1,
    use: '第一吉位：主卧、书房、客厅、文昌位',
    desc: '生气贪狼木，主生机、贵人、进财、添丁。宜作主卧与客厅，忌堆放杂物。'
  },
  天: {
    name: '天医',
    star: '巨门',
    type: 'ji',
    rank: 2,
    use: '卧室、厨房、养病静室',
    desc: '天医巨门土，主健康、医药、贵人扶持。宜作卧室与厨房，病中休养最宜。'
  },
  延: {
    name: '延年',
    star: '武曲',
    type: 'ji',
    rank: 3,
    use: '夫妻房、长辈房、会客',
    desc: '延年武曲金，主和睦、寿元、婚恋。宜作夫妻房与长辈房，主感情长久。'
  },
  伏: {
    name: '伏位',
    star: '辅弼',
    type: 'ji',
    rank: 4,
    use: '静室、书房、神位',
    desc: '伏位辅弼木，主安稳守成。宜静不宜动，作书房或静室最稳。'
  },
  绝: {
    name: '绝命',
    star: '破军',
    type: 'xiong',
    rank: 8,
    use: '储物、卫浴、少用房间',
    desc: '绝命破军金，主破财、损丁。宜置储物间或卫浴，忌作主卧；可置铜葫芦化解。'
  },
  五: {
    name: '五鬼',
    star: '廉贞',
    type: 'xiong',
    rank: 6,
    use: '厕所、储物、杂物间',
    desc: '五鬼廉贞火，主口舌、火灾、官非。宜作卫浴或杂物间，忌作卧室；宜黑曜石、安忍水。'
  },
  祸: {
    name: '祸害',
    star: '禄存',
    type: 'xiong',
    rank: 7,
    use: '储物、辅助用房',
    desc: '祸害禄存土，主小病、口舌、小人。宜少用，忌作主卧；可置白玉葫芦化解。'
  },
  六: {
    name: '六煞',
    star: '文曲',
    type: 'xiong',
    rank: 5,
    use: '卫浴、洗衣房',
    desc: '六煞文曲水，主桃花、是非、泌尿之疾。宜作卫浴，忌作卧室；宜铜葫芦、绿植化解。'
  }
};

// 八宫方位名（用于逐宫断语的落点描述）
const PALACE_DIR = { 坎: '正北', 坤: '西南', 震: '正东', 巽: '东南', 乾: '西北', 兑: '正西', 艮: '东北', 离: '正南' };

// 逐宫断语：每星的「做法 → 影响」（对齐 iOS BaZhaiEngine 每宫每星的叙事结构）
const BAZHAI_LORE = {
  生: {
    plan: '宜作主卧、客厅或书房，放常绿阔叶植物，保持通透不积杂物。',
    effect: '主生机、贵人、进财、添丁；若此处堆放杂物或设卫浴，吉气反被压住。'
  },
  天: {
    plan: '宜作卧室、厨房或养病静室，用黄、米色系，忌污秽潮湿。',
    effect: '主健康、医药、贵人扶持；病中休养最宜，忌设厕所污损药气。'
  },
  延: {
    plan: '宜作夫妻房、长辈房或会客处，用白、金色系，宜成双成对布置。',
    effect: '主和睦、寿元、婚恋长久；此处空置或单身布置，延年之气不聚。'
  },
  伏: {
    plan: '宜静守，作书房、静室或神位，不宜频繁改动、不宜开大门。',
    effect: '主安稳守成、久守得福；动则泄气，主人易生倦怠、事业停滞。'
  },
  绝: {
    plan: '宜作储物、卫浴或极少使用的房间；以水景、黑蓝器物泄金，此方不可作卧室。',
    effect: '主破财、损丁、意外血光；作主卧或久留，主重病与人事纠纷。'
  },
  五: {
    plan: '宜置铜葫芦、黑曜石或六帝钱；忌红色电器长置、忌作主卧、忌动土。',
    effect: '主口舌、盗损、官非与火灾；此方动土，煞气立应，易生争执与耗财。'
  },
  祸: {
    plan: '宜挂六帝钱或铜铃化土，忌堆放杂物、忌长期阴暗。',
    effect: '主小人暗耗、慢病缠身；此处杂乱，主贵人不来、做事多阻。'
  },
  六: {
    plan: '宜置绿植或木器泄水；忌积水、忌镜面相对、忌作卧室。',
    effect: '主桃花是非、暗破财与泌尿之疾；设镜或积水，主感情纠葛与失眠。'
  }
};

// 八宫人物与主应（用于逐宫断语落到「谁受影响」）
const PALACE_ROLE = {
  坎: { role: '中男（次子）', focus: '事业官运、肾与泌尿' },
  坤: { role: '母亲（女主人）', focus: '脾胃、家宅安稳' },
  震: { role: '长男（长子）', focus: '肝胆、功名与冲动' },
  巽: { role: '长女（长媳）', focus: '感情人缘、胆与股' },
  乾: { role: '父亲（长辈）', focus: '头脑、权威与官非' },
  兑: { role: '少女（幼女）', focus: '肺与口舌、桃花' },
  艮: { role: '少男（幼子）', focus: '脾胃、学业与阻隔' },
  离: { role: '中女（次女）', focus: '心与眼目、文书名声' }
};

/**
 * 单宫断语：宫位角色 + 星曜性质 + 做法 + 影响 + 家人主应
 * 逐宫不再只给一句通用说法，而是落到「哪个家人、哪类事」。
 */
function loreOf(key, palace) {
  const lore = BAZHAI_LORE[key];
  const dir = PALACE_DIR[palace] || '';
  const role = PALACE_ROLE[palace];
  if (!lore) return '';
  const star = STAR_INFO[key];
  const who = role ? `${role.role}，${role.focus}` : '';
  const starLine = star ? `${star.name}${star.type === 'ji' ? '吉' : '凶'}星` : '';
  return `${palace}宫（${dir}${role ? '·' + role.role + '位' : ''}）· ${starLine}｜做法：${lore.plan} 影响：${lore.effect}${who ? ` 家人主应：${who}受此方影响最直接。` : ''}`;
}

/**
 * 命卦推算（1900–2099，男寄坤二、女寄艮八）
 */
function lifeGua(birthYear, gender) {
  const yr = parseInt(birthYear, 10);
  if (!yr || yr < 1900 || yr > 2099) throw new Error('年份需在 1900–2099');
  const male = gender === 'male' || gender === '男' || gender === true;
  let num;
  if (yr >= 2000) {
    const last2 = yr % 100;
    num = male ? 9 - (last2 % 9 || 9) : 6 + (last2 % 9 || 9);
  } else {
    const last2 = yr % 100;
    num = male ? (100 - last2) % 9 : (last2 - 4) % 9;
  }
  num = (num % 9) || 9;
  if (num === 5) num = male ? 2 : 8;
  const info = GUA_INFO[num];
  return {
    year: yr,
    gender: male ? '男' : '女',
    num,
    name: info.name,
    full: info.full,
    elem: info.elem,
    group: info.group,
    symbol: info.symbol
  };
}

/** 由坐山所属宫取宅卦 */
function houseGuaByPalace(palaceKey) {
  const num = GUA_NUM_BY_NAME[palaceKey];
  if (!num) throw new Error('无效宫位：' + palaceKey);
  const info = GUA_INFO[num];
  return { num, name: info.name, full: info.full, elem: info.elem, group: info.group, symbol: info.symbol };
}

/**
 * 大游年八星分布
 * @param {number|string} gua 卦数（1/2/3/4/6/7/8/9）或卦名
 */
function roamStars(gua) {
  const num = typeof gua === 'number' ? gua : GUA_NUM_BY_NAME[gua];
  const info = GUA_INFO[num];
  if (!info) throw new Error('无效卦：' + gua);
  const song = ROAM_SONGS[info.name];
  const startIdx = CLOCKWISE_PALACES.indexOf(info.name);
  const cells = [{
    palace: info.name,
    num,
    starKey: '伏',
    star: '伏位',
    starName: '辅弼',
    type: 'ji',
    use: STAR_INFO['伏'].use,
    desc: STAR_INFO['伏'].desc,
    lore: loreOf('伏', info.name)
  }];

  for (let i = 0; i < 7; i++) {
    const palace = CLOCKWISE_PALACES[(startIdx + 1 + i) % 8];
    const key = song[i];
    const s = STAR_INFO[key];
    cells.push({
      palace,
      num: GUA_NUM_BY_NAME[palace],
      starKey: key,
      star: s.name,
      starName: s.star,
      type: s.type,
      use: s.use,
      desc: s.desc,
      lore: loreOf(key, palace)
    });
  }

  const lucky = cells.filter((c) => c.type === 'ji' && c.starKey !== '伏');
  const unlucky = cells.filter((c) => c.type === 'xiong');
  return {
    gua: info.name,
    guaNum: num,
    group: info.group,
    cells,
    best: lucky.slice().sort((a, b) => STAR_INFO[a.starKey].rank - STAR_INFO[b.starKey].rank)[0] || cells[0],
    worst: unlucky.slice().sort((a, b) => STAR_INFO[b.starKey].rank - STAR_INFO[a.starKey].rank)[0] || null
  };
}

const ZODIAC = ['鼠', '牛', '虎', '兔', '龙', '蛇', '马', '羊', '猴', '鸡', '狗', '猪'];

// 四凶星化解动作（供「化解任务」勾选用）
const REMEDY = {
  五: { title: '五鬼化解', level: 3, detail: '五鬼廉贞火，主口舌、盗损、官非。宜此方置铜葫芦或黑曜石，忌红色电器长置、忌作主卧。' },
  六: { title: '六煞化解', level: 2, detail: '六煞文曲水，主桃花是非、暗破财。宜置绿植或木器泄水，忌积水、忌镜面相对。' },
  祸: { title: '祸害化解', level: 2, detail: '祸害禄存土，主小人暗耗、慢病缠身。宜挂六帝钱或铜铃化土，忌堆放杂物。' },
  绝: { title: '绝命化解', level: 3, detail: '绝命破军金，主重病损丁、意外血光。宜以水景或黑蓝器物泄金，此方不可作卧室。' }
};

/** 出生年 → 生肖（立春分界从简，按公历年干支） */
function zodiacOf(year) {
  const y = Number(year);
  if (!y) return '';
  return ZODIAC[((y - 4) % 12 + 12) % 12];
}

/** 由宅卦大游年结果生成化解任务清单 */
function remediesOf(roam) {
  return roam.cells
    .filter((c) => c.type === 'xiong' && REMEDY[c.starKey])
    .map((c) => ({
      id: `bz_${c.num}_${c.starKey}`,
      palace: c.palace,
      palaceNum: c.num,
      starKey: c.starKey,
      star: c.star,
      starName: c.starName,
      level: REMEDY[c.starKey].level,
      title: `${c.palace}宫 · ${c.star}（${c.starName}）${REMEDY[c.starKey].title}`,
      detail: REMEDY[c.starKey].detail
    }));
}

/** 宅卦与命卦合配（四级细分：同卦 / 同组 / 异组借吉 / 异组相冲） */
function compatibility(houseGuaName, lifeGuaNum) {
  const house = GUA_INFO[GUA_NUM_BY_NAME[houseGuaName]];
  const life = GUA_INFO[lifeGuaNum];
  const sameGua = house.name === life.name;
  const sameGroup = house.group === life.group;
  const houseDir = house.group === '东四命' ? '东四宅（坎、震、巽、离）' : '西四宅（乾、坤、艮、兑）';

  // 命卦的大游年落到「宅卦所在宫」，看这一宫对本人是吉是凶
  const roam = roamStars(lifeGuaNum);
  const cell = roam.cells.filter((c) => c.palace === house.name)[0] || roam.cells[0];
  const star = STAR_INFO[cell.starKey];

  let levelKey;
  let grade;
  let levelText;
  let note;
  let advice;
  if (sameGua) {
    levelKey = 'same';
    grade = 4;
    levelText = '同卦伏位';
    note = `宅与命同为${life.name}卦，伏位重叠，气最纯，主安稳守成、人丁和顺。`;
    advice = '可直接按本宅大游年吉方安排主卧与客厅；伏位宜静，作书房或静室最稳。';
  } else if (sameGroup) {
    levelKey = 'group';
    grade = 3;
    levelText = '同组相配';
    note = `宅属${house.group}、命属${life.group}，同气；命卦的${cell.star}（${star.name}）正落宅方，主气场相合。`;
    advice = '按本宅大游年吉方安排主卧与客厅，居住安稳。';
  } else if (star.type === 'ji') {
    levelKey = 'borrow';
    grade = 2;
    levelText = `异组借吉·${cell.star}`;
    note = `宅属${house.group}、命属${life.group}，本不同气，但命卦的${cell.star}（${star.name}）落宅方，可借吉气，属「宅克命而有救」。`;
    advice = `主卧优先取本命生气、天医、延年方；宅方既得${star.name}，可作客厅或书房，用床位与门向调和。`;
  } else {
    levelKey = 'clash';
    grade = 1;
    levelText = `异组相冲·${cell.star}`;
    note = `宅属${house.group}、命属${life.group}，且命卦的${cell.star}（${star.name}）落宅方，主气场相冲。`;
    advice = '优先住本命卦的生气、天医、延年方位；若无法调整，主卧宜避开本命绝命、五鬼方。';
  }

  return {
    same: sameGua || sameGroup,
    level: levelText,
    levelKey,
    grade,
    starKey: cell.starKey,
    star: cell.star,
    starType: cell.type,
    housePalace: house.name,
    houseDir,
    note,
    text: sameGua || sameGroup
      ? `${life.name}命属${life.group}，与${house.name}宅${houseDir}${sameGua ? '同卦' : '同组'}，${note}`
      : `${life.name}命属${life.group}，与${house.name}宅${houseDir}不同组，${note}`,
    advice
  };
}

const SHENG = { 木: '火', 火: '土', 土: '金', 金: '水', 水: '木' };
const KE = { 木: '土', 土: '水', 水: '火', 火: '金', 金: '木' };

/** 两五行关系（以 a 为我） */
function elemRelation(a, b) {
  if (!a || !b) return { key: 'none', text: '' };
  if (a === b) return { key: 'same', text: `同为${a}，比和` };
  if (SHENG[a] === b) return { key: 'wo_sheng', text: `${a}生${b}（我生，泄气）` };
  if (SHENG[b] === a) return { key: 'sheng_wo', text: `${b}生${a}（生我，得助）` };
  if (KE[a] === b) return { key: 'wo_ke', text: `${a}克${b}（我克，受制）` };
  return { key: 'ke_wo', text: `${b}克${a}（克我，受压）` };
}

/** 坐山正中分金的纳音（借 fenjin 的 120 分金表，避免另造一套） */
function sitNayin(sitMountain) {
  const FJ = require('./fenjin');
  const idx = FJ.MOUNTAINS_24.indexOf(sitMountain);
  if (idx < 0) return null;
  const r = FJ.degreeReading((idx * 15) % 360);
  const elem = String(r.nayin || '').replace(/[^金木水火土]/g, '');
  return {
    mountain: sitMountain,
    deg: r.deg,
    jiazi: r.jiazi,
    nayin: r.nayin,
    elem: elem || '',
    grade: r.grade,
    usable: r.usable
  };
}

/**
 * 纳音合配：坐山纳音五行 vs 宅卦五行、命卦五行
 * 只作合配的加减参考（同宅命合配并列显示），不单独定吉凶。
 * @param {string} houseGuaName 宅卦名（坎 / 坤 / 震 / 巽 / 乾 / 兑 / 艮 / 离）
 * @param {number} lifeGuaNum 命卦数
 * @param {string} sitMountain 坐山（二十四山之一）
 */
function nayinCompat(houseGuaName, lifeGuaNum, sitMountain) {
  const ny = sitNayin(sitMountain);
  if (!ny) return null;
  const house = GUA_INFO[GUA_NUM_BY_NAME[houseGuaName]];
  const life = GUA_INFO[lifeGuaNum] || null;

  const houseRel = elemRelation(house.elem, ny.elem);
  const lifeRel = life ? elemRelation(life.elem, ny.elem) : { key: 'none', text: '' };

  // 吉凶：纳音生宅卦或比和 → 山气助宅；宅卦克纳音 → 宅压山气
  let level = 'ping';
  let levelText = '纳音平和';
  if (houseRel.key === 'sheng_wo' || houseRel.key === 'same') {
    level = 'ji';
    levelText = '山气助宅';
  } else if (houseRel.key === 'ke_wo' || houseRel.key === 'wo_sheng') {
    level = 'xiong';
    levelText = '宅压山气';
  }

  const text = `坐${ny.mountain}山正中分金 ${ny.jiazi}（${ny.nayin}·${ny.elem}），与${house.name}宅（${house.elem}）为「${houseRel.text}」；${life ? `与${life.name}命（${life.elem}）为「${lifeRel.text}」。` : ''}`;
  const advice = level === 'ji'
    ? '宅纳音相生，坐山之气可助宅；主卧与门向按大游年吉方取用即可。'
    : (level === 'xiong'
      ? '宅卦克坐山纳音，主宅压山气；宜在坐山方少动土、少开门，以泄化之（如坐山属火被水克，忌此方积水）。'
      : '纳音比和平顺，合配以宅命大游年为主，纳音只作参考。');

  return {
    mountain: ny.mountain,
    jiazi: ny.jiazi,
    nayin: ny.nayin,
    elem: ny.elem,
    grade: ny.grade,
    house: { name: house.name, elem: house.elem, rel: houseRel },
    life: life ? { name: life.name, elem: life.elem, rel: lifeRel } : null,
    level,
    levelText,
    text,
    advice
  };
}

/**
 * 家人配房：按命卦吉方给每个成员推荐方位
 */
function assignRooms(members, houseGuaName) {
  return members.map((m) => {
    const gua = lifeGua(m.birthYear, m.gender);
    const roam = roamStars(gua.num);
    const bestCells = roam.cells
      .filter((c) => c.type === 'ji')
      .sort((a, b) => STAR_INFO[a.starKey].rank - STAR_INFO[b.starKey].rank)
      .slice(0, 3);
    return {
      role: m.role,
      name: m.name || m.role,
      birthYear: m.birthYear,
      gender: gua.gender,
      gua,
      bestCells,
      avoidCells: roam.cells.filter((c) => c.type === 'xiong'),
      text: `${m.name || m.role}（${m.birthYear}年·${gua.gender}）${gua.full}命，宜住 ${bestCells.map((c) => c.palace + '（' + c.star + '）').join('、')}；忌 ${roam.cells.filter((c) => c.type === 'xiong').map((c) => c.palace + '（' + c.star + '）').join('、')}。`
    };
  });
}

module.exports = {
  GUA_INFO,
  CLOCKWISE_PALACES,
  GUA_NUM_BY_NAME,
  ROAM_SONGS,
  STAR_INFO,
  BAZHAI_LORE,
  PALACE_DIR,
  PALACE_ROLE,
  loreOf,
  REMEDY,
  ZODIAC,
  lifeGua,
  houseGuaByPalace,
  roamStars,
  remediesOf,
  zodiacOf,
  compatibility,
  elemRelation,
  sitNayin,
  nayinCompat,
  assignRooms
};
