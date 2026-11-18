/**
 * sha.js
 * 外部形煞／峦头库：辨识、影响、化解、严重度
 * 对齐 iOS Models/ExteriorShaEngine.swift 的煞型分级（极凶 / 中凶 / 轻微 / 吉象）。
 */

const SEVERITY = {
  critical: { key: 'critical', name: '极凶（大煞破局）', level: 3 },
  warning: { key: 'warning', name: '中凶（损丁耗财）', level: 2 },
  minor: { key: 'minor', name: '轻微（气场受扰）', level: 1 },
  notice: { key: 'notice', name: '吉象（明堂清秀）', level: 0 }
};

const ITEMS = [
  {
    id: 'tianzhan', name: '天斩煞', severity: 'critical',
    identify: '窗前或门前正对两栋高楼之间的狭窄缝隙，缝隙越窄越长越凶。',
    effect: '主血光、手术、官非，宅运骤退，尤忌正对卧室与大门。',
    remedy: '缝隙方向加屏风或厚窗帘；门口置泰山石敢当；阳台种高大阔叶植物遮挡视线。'
  },
  {
    id: 'luchong', name: '路冲煞', severity: 'critical',
    identify: '道路、巷口、地下车库出口直冲大门或窗前。',
    effect: '主意外、破财、口舌，气场直冲不聚。',
    remedy: '门前设矮墙、花坛或台阶错位化解；门内加玄关转折；避免正对开门。'
  },
  {
    id: 'fangong', name: '反弓煞', severity: 'warning',
    identify: '道路、河流呈弓形，弓背朝宅（弯月外弧对着房子）。',
    effect: '主失财、人丁不安、感情反复。',
    remedy: '弓背方向种树或立石化解；门向微调避开弓心；院内堆假山挡气。'
  },
  {
    id: 'tantou', name: '探头煞', severity: 'warning',
    identify: '邻栋建筑从自家屋顶或侧面探出，如人探头窥视。',
    effect: '主盗损、小人、隐私外泄，易招是非。',
    remedy: '探出处加高围墙或绿篱；相应方位置铜葫芦；窗侧加纱帘。'
  },
  {
    id: 'chuanxin', name: '穿心煞', severity: 'critical',
    identify: '大门直通后门、长廊贯穿宅心，或地铁、隧道从宅下穿过。',
    effect: '主财来财去、家人离散、健康受损。',
    remedy: '中宫设屏风或玄关阻断直通；穿心方向挂五帝钱；避免前后门对开。'
  },
  {
    id: 'huoxing', name: '火形煞', severity: 'warning',
    identify: '邻近加油站、变电所、烟囱、三角尖顶建筑，呈火形尖射。',
    effect: '主火灾、炎症、急躁、血光。',
    remedy: '相应方位避免红色与尖角装饰；置黑曜石或水景制火；远离尖射正对。'
  },
  {
    id: 'liandao', name: '镰刀煞', severity: 'warning',
    identify: '高架桥、天桥呈弧形绕宅，如镰刀割向宅身。',
    effect: '主伤灾、破财、手术。',
    remedy: '弧心一侧种树缓冲；门向避开弧口；桥下忌久居。'
  },
  {
    id: 'gejiao', name: '割脚煞', severity: 'warning',
    identify: '住宅紧贴马路、河流，地基外侧无缓冲，车流或水流贴脚而过。',
    effect: '主财不聚、脚疾、奔波劳碌。',
    remedy: '外侧设花台或围栏形成缓冲区；室内靠外侧少作卧室。'
  },
  {
    id: 'baihu', name: '白虎抬头', severity: 'critical',
    identify: '宅右（西侧）建筑、山体、塔楼明显高于左侧。',
    effect: '主女强男弱、官非、伤灾，白虎宜低伏不宜高昂。',
    remedy: '左侧补高（绿植、灯柱）；右侧忌红色尖物；白虎方置铜器压之。'
  },
  {
    id: 'qinglong', name: '青龙折腰', severity: 'warning',
    identify: '宅左（东侧）建筑低陷、断折或有缺口，青龙位不完整。',
    effect: '主男丁不旺、事业受阻、贵人少助。',
    remedy: '左侧补种高大乔木或立灯；缺口处置泰山石；避免左侧开门泄气。'
  },
  {
    id: 'wuji', name: '屋脊煞', severity: 'warning',
    identify: '正对邻栋屋脊、屋檐尖角，形成一条线直指门窗。',
    effect: '主手术、血光、精神紧张。',
    remedy: '尖指方向挂八卦凸镜反射；门内加屏风；窗侧置绿植软化。'
  },
  {
    id: 'jianjiao', name: '尖角煞', severity: 'warning',
    identify: '邻栋建筑锐角、广告牌尖角、三角形屋顶正对门窗。',
    effect: '主急躁、伤灾、口舌。',
    remedy: '正对处置圆形摆件或绿植化解；避免在尖角延长线上安床。'
  },
  {
    id: 'fanguang', name: '镜面反光煞', severity: 'minor',
    identify: '对面玻璃幕墙、水面、广告灯箱将强光反射入宅。',
    effect: '主心神不宁、失眠、口舌，光煞扰气。',
    remedy: '窗贴防眩膜或纱帘；反光面朝向处置磨砂贴；夜间减少直射。'
  },
  {
    id: 'shengsha', name: '声煞', severity: 'minor',
    identify: '临街、临工地、临 KTV 或风机房，噪音持续侵入。',
    effect: '主睡眠差、血压波动、情绪焦躁。',
    remedy: '加装隔音窗与密封条；卧室远离声源侧；白噪音机辅助。'
  },
  {
    id: 'dianTi', name: '电梯开口煞', severity: 'warning',
    identify: '大门正对电梯门，开合如口，气流一进一出。',
    effect: '主财气外泄、人口不安、突发变动。',
    remedy: '门内设玄关转折；电梯方向置屏风；门口地毯下压五帝钱。'
  },
  {
    id: 'menchong', name: '门冲煞', severity: 'warning',
    identify: '大门正对邻居大门、厕所门、厨房门。',
    effect: '主口舌、肠胃病、家宅不宁。',
    remedy: '常闭门或加门帘；厕所门挂长帘；两门之间置绿植缓冲。'
  },
  {
    id: 'guyin', name: '孤阴煞', severity: 'warning',
    identify: '四周低矮、独栋孤立，或宅周多阴湿、少人烟。',
    effect: '主孤寡、抑郁、人丁不旺。',
    remedy: '增加照明与人气活动；宅前种向阳花木；避免全屋冷色调。'
  },
  {
    id: 'duyang', name: '独阳煞', severity: 'minor',
    identify: '四周高楼逼压、无遮无挡而日晒过强，或独高无护。',
    effect: '主急躁、血压、官非。',
    remedy: '西晒侧加遮阳；室内用柔和色；适当引水景调候。'
  },
  {
    id: 'quesun', name: '缺角煞', severity: 'warning',
    identify: '户型某一宫位明显凹陷缺失（超过该宫 1/3）。',
    effect: '缺哪宫，该宫人事不聚：西北缺伤男主、西南缺伤女主人、东北缺伤少男。',
    remedy: '缺角处置对应五行摆件；以家具或屏风补形；该方少开窗泄气。'
  },
  {
    id: 'zhonggong', name: '中宫受污', severity: 'critical',
    identify: '厕所、厨房或重物压在中宫（宅心）。',
    effect: '主宅气受制、全家运势起伏、健康受损。',
    remedy: '中宫保持空净；厕所中宫加铜葫芦；忌重物长置。'
  },
  {
    id: 'fanju', name: '反光水煞', severity: 'minor',
    identify: '宅前水池、鱼缸过大过近，水面反光直射入室。',
    effect: '主财来财去、心神不宁。',
    remedy: '水面控制面积；夜间关灯；加浮萍或石台破反光。'
  },
  {
    id: 'duanbi', name: '断壁煞', severity: 'warning',
    identify: '邻近有废弃建筑、断墙、烂尾楼，长期无人。',
    effect: '主衰败、疾病、阴气聚。',
    remedy: '正对方向置凸镜或屏风；加强宅内采光；避免窗户常对。'
  },
  {
    id: 'mingtang', name: '明堂清秀（吉象）', severity: 'notice',
    identify: '宅前开阔平整、有水有情、无遮挡逼压。',
    effect: '主聚气、进财、贵人扶持。',
    remedy: '保持整洁通透，勿堆杂物；可置矮景或水景催旺。'
  },
  // 室内形煞：对齐 iOS HouseSpatialSurveyModel 中由空间几何判定的一组（小程序改为人工勾选）
  {
    id: 'hengliang', name: '横梁压顶', severity: 'warning',
    identify: '床头、沙发、书桌、灶台正上方有横梁，或吊顶下压低于 2.2 米。',
    effect: '受压者久坐久卧，主精神压抑、睡眠不宁、事业受制，古谓「梁压当身，气不舒展」。',
    remedy: '移床移座避开梁下；不能移则做弧形吊顶包梁、或用五帝钱与铜葫芦于梁两端化之。'
  },
  {
    id: 'chuangchong', name: '房门冲床', severity: 'warning',
    identify: '卧室门正对床头或床侧，开门即见床身。',
    effect: '主睡眠不安、易受惊、夫妻口角，气场直冲卧者。',
    remedy: '床位转向使门不见床；门内加帘或屏风；门常闭，门后挂门帘缓冲。'
  },
  {
    id: 'shuihuo', name: '水火未济（厨厕相邻）', severity: 'warning',
    identify: '厨房与卫生间同壁、相邻开门，或灶台与马桶仅一墙之隔。',
    effect: '水火相战，主肠胃与妇科不适、家人口舌、财气耗散。',
    remedy: '两门错开、常闭；灶台不与马桶同侧；以绿植或木器中隔，取水生木、木生火之意。'
  },
  {
    id: 'kaimentzao', name: '开门见灶', severity: 'minor',
    identify: '入户门一开即见灶台或炉火。',
    effect: '古谓「开门见灶，钱财多耗」，主财气外泄、家中不和。',
    remedy: '厨房门常闭或改推拉门；门口加玄关转折；灶台移位使门外不可直视。'
  },
  {
    id: 'kaimence', name: '开门见厕', severity: 'warning',
    identify: '入户门正对卫生间门，或客厅中央直见厕门。',
    effect: '秽气迎门，主健康受损、贵人不来、财气受污。',
    remedy: '厕门常闭并加门帘；门口置屏风错位；厕内保持干燥通风、置香或绿植。'
  },
  {
    id: 'chuangtou', name: '床头悬空', severity: 'minor',
    identify: '床头无实墙可靠，或床头正对窗、走廊、动线。',
    effect: '靠山虚浮，主心神不宁、事业无援、睡眠浅。',
    remedy: '床头靠实墙；实在无墙则加厚床头板并置床头柜「补靠」；避免床头正对窗。'
  },
  {
    id: 'anshi', name: '暗室无窗', severity: 'minor',
    identify: '房间长期无自然采光或通风（含地下、夹层、封闭隔间）。',
    effect: '孤阴凝滞，主精神抑郁、湿气病痛，久居人气不振。',
    remedy: '增开气窗或装排气扇、长明暖光灯；常开窗换气；以明亮色与阔叶植物补阳。'
  },
  {
    id: 'jihuo', name: '吉位落水（厕占吉方）', severity: 'warning',
    identify: '卫生间压在玄空生气方、八宅生气/天医位，或宅心（中宫）位置。',
    effect: '吉星受污，主该方所应之财丁两损，中宫受污尤忌。',
    remedy: '厕内保持干燥、常闭门、置盐灯或绿植化湿；吉方另置催旺物补偿。'
  },
  {
    id: 'xiachang', name: '户型狭长', severity: 'minor',
    identify: '进深明显大于面宽（超过 2:1），或呈长条走廊式。',
    effect: '深长损明，采光通风难及深处，主气脉不畅、人口不安。',
    remedy: '分区设置玄关与转折；深处增补光与植物；避免一条直线贯通首尾（穿堂）。'
  },
  {
    id: 'wuhuangmen', name: '五黄到门', severity: 'critical',
    identify: '当年五黄星飞临入户门所居之宫（按流年紫白推算）。',
    effect: '五黄为土煞之最，主重病、意外、破财，门为其入口尤忌。',
    remedy: '门内挂六帝钱或铜铃（金泄土气）；此方忌动土、忌红色；可置灰色地毯缓冲。'
  },
  {
    id: 'erheiwo', name: '二黑临卧', severity: 'warning',
    identify: '当年二黑病符星飞临卧室所在之宫。',
    effect: '主宿疾、妇科与肠胃之患，病符所临久卧者尤应。',
    remedy: '此方悬铜葫芦或六帝钱泄土；卧室保持干燥通风，勿堆杂物。'
  },
  {
    id: 'wode', name: '卧房得位（吉象）', severity: 'notice',
    identify: '卧室落在玄空生旺方或八宅生气、延年、天医位。',
    effect: '吉星拱照，主安眠、健康、人丁和顺、事有所成。',
    remedy: '保持整洁明亮即可，不必改动；可置暖光与圆叶植物助旺。'
  }
];

// 形煞出典（统一口径，避免逐条虚构精确引文）
const CLASSIC_SOURCE = '出典：形法峦头通例（《阳宅十书》《相宅经》一系，传本互有出入）。解释：煞名与吉凶语为古法象徵，结构安全、法务与健康问题须以现场勘验和专业意见为准。';

ITEMS.forEach((item) => {
  if (!item.source) item.source = CLASSIC_SOURCE;
  if (!item.steps) {
    item.steps = [
      `辨识：${item.identify}`,
      `影响：${item.effect}`,
      `化解：${item.remedy}`,
      `出处：${item.source}`
    ];
  }
});

function bySeverity(level) {
  return ITEMS.filter((i) => SEVERITY[i.severity].level >= level);
}

function search(keyword) {
  const k = String(keyword || '').trim();
  if (!k) return ITEMS;
  return ITEMS.filter((i) => i.name.indexOf(k) >= 0 || i.identify.indexOf(k) >= 0 || i.effect.indexOf(k) >= 0);
}

/** 自查清单：按外部环境逐项勾选，返回严重度汇总 */
function audit(checkIds, sitPalace) {
  const hits = ITEMS.filter((i) => checkIds.indexOf(i.id) >= 0);
  const score = hits.reduce((sum, i) => sum - SEVERITY[i.severity].level, 0);
  const critical = hits.filter((i) => i.severity === 'critical');
  const summary = [];
  if (critical.length) summary.push(`存在 ${critical.length} 项极凶大煞，建议优先处理：${critical.map((i) => i.name).join('、')}。`);
  if (!hits.length) summary.push('未勾选任何形煞，外部环境暂判清吉；仍建议实地复看门窗朝向与明堂。');
  if (sitPalace) summary.push(`复核时请以坐${sitPalace}宫为主，形煞落在向首与坐山两方者影响最重。`);
  return { hits, score, summary };
}

/**
 * 八宫方位 → 主应形煞 自动联动（1:1 移植自 iOS ARVisionView.resolvedShaIndex）
 * 入参 heading 为罗盘实测方位角（度，正北 0）。返回对应形煞 id 与主应宫位。
 * 八段区间与 iOS 完全一致：337.5~22.5 正北 / 22.5~67.5 东北 / ... 每 45° 一段。
 */
const SHA_BY_DIRECTION = [
  { key: 'chuanxin', palace: '坎', dir: '正北', range: '337.5–22.5' },
  { key: 'gejiao',   palace: '艮', dir: '东北', range: '22.5–67.5' },
  { key: 'luchong',  palace: '震', dir: '正东', range: '67.5–112.5' },
  { key: 'fangong',  palace: '巽', dir: '东南', range: '112.5–157.5' },
  { key: 'huoxing',  palace: '离', dir: '正南', range: '157.5–202.5' },
  { key: 'tianzhan', palace: '坤', dir: '西南', range: '202.5–247.5' },
  { key: 'baihu',    palace: '兑', dir: '正西', range: '247.5–292.5' },
  { key: 'tantou',   palace: '乾', dir: '西北', range: '292.5–337.5' }
];

function resolveShaByHeading(heading) {
  const norm = ((Number(heading) || 0) % 360 + 360) % 360;
  let idx;
  if (norm >= 337.5 || norm < 22.5) idx = 0;
  else if (norm < 67.5) idx = 1;
  else if (norm < 112.5) idx = 2;
  else if (norm < 157.5) idx = 3;
  else if (norm < 202.5) idx = 4;
  else if (norm < 247.5) idx = 5;
  else if (norm < 292.5) idx = 6;
  else idx = 7;
  const seg = SHA_BY_DIRECTION[idx];
  const item = ITEMS.filter((i) => i.id === seg.key)[0] || null;
  return {
    heading: norm,
    index: idx,
    id: seg.key,
    palace: seg.palace,
    dir: seg.dir,
    range: seg.range,
    name: item ? item.name : '',
    severity: item ? item.severity : '',
    identify: item ? item.identify : '',
    effect: item ? item.effect : '',
    remedy: item ? item.remedy : ''
  };
}

/** 返回全 8 方位主应形煞表，供页面列表展示 */
function allDirectionSha() {
  return SHA_BY_DIRECTION.map((seg) => {
    const item = ITEMS.filter((i) => i.id === seg.key)[0] || {};
    return {
      palace: seg.palace, dir: seg.dir, range: seg.range,
      id: seg.key, name: item.name || '', severity: item.severity || '',
      remedy: item.remedy || ''
    };
  });
}

// ===== 距离加权判级 + 八宫全景聚合，1:1 移植自 iOS ShaSurveyModels.swift =====

const SHA_DISTANCE_GRADE = {
  criticalNear: { key: 'criticalNear', name: '近距加重', note: '< 30m：加重一级' },
  staticLevel: { key: 'staticLevel', name: '静态等级', note: '30–100m：保持原级' },
  mitigatedFar: { key: 'mitigatedFar', name: '远距减轻', note: '> 100m：减轻一级' }
};

/** iOS ExteriorShaSeverityResolver.grade(for:) */
function distanceGrade(distanceMeters) {
  const d = Number(distanceMeters);
  if (!isFinite(d) || d <= 0) return 'staticLevel';
  if (d < 30) return 'criticalNear';
  if (d > 100) return 'mitigatedFar';
  return 'staticLevel';
}

// level: notice=0, minor=1, warning=2, critical=3
const SEVERITY_ORDER = ['notice', 'minor', 'warning', 'critical'];

/** iOS ExteriorShaSeverityResolver.effectiveSeverity(staticSeverity:distanceMeters:) */
function effectiveSeverity(staticSeverity, distanceMeters) {
  const cur = SEVERITY_ORDER.indexOf(staticSeverity);
  const base = cur < 0 ? 0 : cur;
  const grade = distanceGrade(distanceMeters);
  let idx;
  if (grade === 'criticalNear') idx = Math.min(3, base + 1);
  else if (grade === 'mitigatedFar') idx = Math.max(0, base - 1);
  else idx = base;
  return SEVERITY_ORDER[idx];
}

/** iOS ExteriorShaRecord.absolutePalaceIndex：0=正北，每 45° 一格 */
function absolutePalaceIndex(bearing) {
  const b = Number(bearing);
  if (!isFinite(b)) return 0;
  const norm = ((b % 360) + 360) % 360;
  return Math.floor(norm / 45) % 8;
}

/** 相对采集基准朝向的八宫索引 iOS palaceIndex(relativeTo:) */
function palaceIndexRelative(bearing, headingDegrees) {
  return absolutePalaceIndex(Number(bearing) - Number(headingDegrees));
}

/**
 * iOS ShaPanoramaReport.palacesByIndex + severityCounts：
 * 环绕采集的多条标注按方位归宫，并按距离加权后的最终等级统计。
 * @param {Array} records [{shaID, bearingDegrees, distanceMeters}]
 * @param {number} headingDegrees 采集基准朝向
 * @param {function} staticSeverityLookup shaID → 'notice'|'minor'|'warning'|'critical'
 */
function panoramaReport(records, headingDegrees, staticSeverityLookup) {
  const list = records || [];
  const lookup = typeof staticSeverityLookup === 'function'
    ? staticSeverityLookup
    : (id) => { const it = ITEMS.filter((i) => i.id === id)[0]; return it ? it.severity : 'minor'; };
  const palacesByIndex = Array.from({ length: 8 }, () => []);
  const severityCounts = { notice: 0, minor: 0, warning: 0, critical: 0 };
  list.forEach((r) => {
    const idx = palaceIndexRelative(r.bearingDegrees, headingDegrees || 0);
    const base = lookup(r.shaID);
    const eff = effectiveSeverity(base, r.distanceMeters);
    palacesByIndex[idx].push(Object.assign({}, r, {
      palaceIndex: idx,
      baseSeverity: base,
      effectiveSeverity: eff,
      distanceGrade: distanceGrade(r.distanceMeters)
    }));
    severityCounts[eff] += 1;
  });
  return {
    headingDegrees: headingDegrees || 0,
    palacesByIndex,
    scannedPalaceCount: palacesByIndex.filter((a) => a.length).length,
    severityCounts
  };
}

module.exports = {
  SEVERITY, ITEMS, CLASSIC_SOURCE, bySeverity, search, audit,
  SHA_BY_DIRECTION, resolveShaByHeading, allDirectionSha,
  SHA_DISTANCE_GRADE, distanceGrade, effectiveSeverity,
  absolutePalaceIndex, palaceIndexRelative, panoramaReport
};
