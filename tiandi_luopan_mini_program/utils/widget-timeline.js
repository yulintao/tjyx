/**
 * widget-timeline.js
 * 日历时间线刷新时刻生成算法，1:1 移植自 iOS WidgetAlmanacBuilder：
 *   - refreshDates(from, days)：3 小时网格 + 每日 23:00 子初补点 + 节气交接点，去重排序
 *   - nextTermBoundary(after, before)：对 solarTermIndex 做时间域二分（精度 60s）定位节气桶跳变
 *   - upcomingSolarTerms(after, count)：连续 count 条交节时刻（对齐 SolarTimeCalculator.upcomingSolarTerms）
 * 小程序无 WidgetKit TimelineProvider，但纯计算可用于「日签/提醒」的刷新调度与节气列表。
 */

const ST = require('./solar-terms');

/** 当前时刻所属的节气桶索引（跨年连续编号，避免年界重复） */
function continuousTermIndex(date) {
  const d = new Date(date).getTime();
  const y = new Date(date).getFullYear();
  let best = null;
  [y - 1, y, y + 1].forEach((yy) => {
    for (let i = 0; i < 24; i++) {
      const at = ST.termDate(i, yy).getTime();
      if (at <= d && (!best || at > best.at)) best = { at, idx: yy * 24 + i };
    }
  });
  return best ? best.idx : y * 24;
}

/** iOS nextTermBoundary(after:before:)：二分定位 [after,before] 内节气桶变化点，精度 60s */
function nextTermBoundary(after, before) {
  const a = new Date(after).getTime();
  const b = new Date(before).getTime();
  if (!(b > a)) return null;
  const startIdx = continuousTermIndex(a);
  if (continuousTermIndex(b) === startIdx) return null;
  let low = a, high = b;
  while (high - low > 60000) {
    const mid = low + (high - low) / 2;
    if (continuousTermIndex(mid) === startIdx) low = mid;
    else high = mid;
  }
  return new Date(high);
}

/** iOS WidgetAlmanacBuilder.refreshDates(from:days:) */
function refreshDates(from, days) {
  const now = new Date(from || Date.now());
  const n = Number(days) > 0 ? Number(days) : 1;
  const y = now.getFullYear(), m = now.getMonth(), d = now.getDate();
  const startOfToday = new Date(y, m, d).getTime();
  const nowMs = now.getTime();
  const dates = [nowMs];

  for (let h = 0; h <= n * 24; h += 3) {
    const p = startOfToday + h * 3600000;
    if (p > nowMs) dates.push(p);
  }
  // 23:00 子初换日柱不属于 3 小时网格，显式补齐
  for (let day = 0; day < n; day++) {
    const p = startOfToday + day * 86400000 + 23 * 3600000;
    if (p > nowMs) dates.push(p);
  }
  // 节气交接（流月飞星同时切换）
  const horizonMs = nowMs + (n * 24 + 1) * 3600000;
  const boundary = nextTermBoundary(nowMs, horizonMs);
  if (boundary) dates.push(boundary.getTime());

  return Array.from(new Set(dates)).sort((x, z) => x - z).map((t) => new Date(t));
}

/** iOS SolarTimeCalculator.upcomingSolarTerms(after:count:)：连续交节时刻列表 */
function upcomingSolarTerms(after, count) {
  const d = new Date(after || Date.now());
  const n = Number(count) > 0 ? Number(count) : 24;
  const y = d.getFullYear();
  const marks = [];
  [y - 1, y, y + 1, y + 2].forEach((yy) => {
    for (let i = 0; i < 24; i++) {
      marks.push({ index: i, name: ST.SOLAR_TERM_NAMES[i], at: ST.termDate(i, yy) });
    }
  });
  return marks.filter((x) => x.at > d)
    .sort((a, b) => a.at - b.at)
    .slice(0, n)
    .map((x) => ({ index: x.index, name: x.name, at: x.at }));
}

module.exports = {
  continuousTermIndex,
  solarTermIndex: continuousTermIndex,
  nextTermBoundary,
  refreshDates,
  upcomingSolarTerms
};
