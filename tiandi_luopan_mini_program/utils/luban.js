/**
 * luban.js —— 鲁班门光尺 / 丁兰尺吉凶评定
 * 对齐 iOS Views/ARVision/ARSpatialSurveyView.swift 的 LubanRulerEvaluation
 * （仅简体口径：门光尺 42.9cm 八格、丁兰尺 39.0cm 十格）
 */

const YANG_CYCLE_CM = 42.9;   // 门光尺（阳宅用）：财病离义官劫害本
const YIN_CYCLE_CM = 39.0;    // 丁兰尺（阴宅/神龛用）：财失兴死官义苦旺害丁

const YANG_NAMES = ['财', '病', '离', '义', '官', '劫', '害', '本'];
const YANG_FLAGS = [true, false, false, true, true, false, false, true];
const YIN_NAMES = ['财', '失', '兴', '死', '官', '义', '苦', '旺', '害', '丁'];
const YIN_FLAGS = [true, false, true, false, true, true, false, true, false, true];

const SOURCE = '出处：《鲁班经》尺法诀：“财、义、官、本为吉，病、离、劫、害为凶。”兼参《丁兰尺》传统尺法；‘病、失、财、旺’是文化象征标签，不是医疗、安全或财务判断。';

const YANG_MEANING = {
  财: '财：主进财、聚财，宜门、柜、床之尺寸。',
  病: '病：主疾病、耗损，古法列为凶度。',
  离: '离：主离散、口舌、人事不合。',
  义: '义：主仁义、人缘、贵人相助。',
  官: '官：主功名、事业、升迁。',
  劫: '劫：主破财、盗失、被人侵夺。',
  害: '害：主损害、是非、家宅不宁。',
  本: '本：主根本稳固、家宅安泰。'
};

const YIN_MEANING = {
  财: '财：主财禄。',
  失: '失：主耗失、漏财。',
  兴: '兴：主兴旺、家道渐盛。',
  死: '死：主衰败，古法列为大凶。',
  官: '官：主功名。',
  义: '义：主和顺。',
  苦: '苦：主劳苦、病困。',
  旺: '旺：主旺盛、人丁安。',
  害: '害：主妨害。',
  丁: '丁：主添丁、子嗣。'
};

function evaluate(meters) {
  const m = Number(meters);
  const cm = Math.max(0, (isFinite(m) ? m : 0) * 100);

  const yangStep = YANG_CYCLE_CM / 8;
  const yangRem = cm % YANG_CYCLE_CM;
  const yangIndex = Math.min(7, Math.max(0, Math.floor(yangRem / yangStep)));

  const yinStep = YIN_CYCLE_CM / 10;
  const yinRem = cm % YIN_CYCLE_CM;
  const yinIndex = Math.min(9, Math.max(0, Math.floor(yinRem / yinStep)));

  const yangName = YANG_NAMES[yangIndex];
  const yinName = YIN_NAMES[yinIndex];

  return {
    meters: cm / 100,
    centimeters: Math.round(cm * 10) / 10,
    yangIndex,
    yangName,
    yangAuspicious: YANG_FLAGS[yangIndex],
    yangMeaning: YANG_MEANING[yangName],
    yinIndex,
    yinName,
    yinAuspicious: YIN_FLAGS[yinIndex],
    yinMeaning: YIN_MEANING[yinName],
    summary: `${(Math.round(cm * 10) / 10)} cm · 门光尺【${yangName}】${YANG_FLAGS[yangIndex] ? '吉' : '凶'} · 丁兰尺【${yinName}】${YIN_FLAGS[yinIndex] ? '吉' : '凶'}`,
    source: SOURCE
  };
}

/** 门光尺八格刻度表（含起止厘米），用于页面展示 */
function yangScale() {
  const step = YANG_CYCLE_CM / 8;
  return YANG_NAMES.map((n, i) => ({
    name: n,
    auspicious: YANG_FLAGS[i],
    from: Math.round(i * step * 10) / 10,
    to: Math.round((i + 1) * step * 10) / 10
  }));
}

function yinScale() {
  const step = YIN_CYCLE_CM / 10;
  return YIN_NAMES.map((n, i) => ({
    name: n,
    auspicious: YIN_FLAGS[i],
    from: Math.round(i * step * 10) / 10,
    to: Math.round((i + 1) * step * 10) / 10
  }));
}

/** 依当前尺寸给出最近的吉度落点（用于「调门宽到吉度」建议） */
function nearestAuspicious(cm) {
  const c = Number(cm);
  const step = YANG_CYCLE_CM / 8;
  const base = Math.floor((isFinite(c) ? c : 0) / YANG_CYCLE_CM) * YANG_CYCLE_CM;
  let best = null;
  for (let k = -1; k <= 8; k += 1) {
    for (let i = 0; i < 8; i += 1) {
      if (!YANG_FLAGS[i]) continue;
      const mid = base + k * YANG_CYCLE_CM + (i + 0.5) * step;
      if (mid <= 30) continue;
      const d = Math.abs(mid - c);
      if (!best || d < best.diff) {
        best = { cm: Math.round(mid * 10) / 10, name: YANG_NAMES[i], diff: Math.round(d * 10) / 10 };
      }
    }
  }
  return best;
}

module.exports = {
  YANG_CYCLE_CM,
  YIN_CYCLE_CM,
  YANG_NAMES,
  YIN_NAMES,
  SOURCE,
  evaluate,
  yangScale,
  yinScale,
  nearestAuspicious
};
