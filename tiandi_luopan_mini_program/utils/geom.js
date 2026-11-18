/**
 * geom.js
 * 几何测绘工具：1:1 移植自 iOS Models/GeometryUtils.swift（L155-309）。
 * 全部为纯数学，不依赖任何平台 API，可在 Node / 小程序中直接运行。
 *
 * 点统一用 {x, y}；矩形用 {x, y, width, height}；面积/距离单位与输入一致。
 */

function isFinitePoint(p) {
  return p && Number.isFinite(p.x) && Number.isFinite(p.y);
}

/** 鞋带公式有向面积的绝对值（Swift polygonArea L243-252） */
function polygonArea(points) {
  if (!points || points.length < 3) return 0;
  let sum = 0;
  for (let i = 0; i < points.length; i++) {
    const p = points[i];
    const q = points[(i + 1) % points.length];
    sum += p.x * q.y - q.x * p.y;
  }
  return Math.abs(sum) * 0.5;
}

/** 面积加权重心；退化时回退顶点均值（Swift polygonCentroid L255-278） */
function polygonCentroid(points) {
  if (!points || points.length === 0) return { x: 0, y: 0 };
  if (points.length < 3) {
    const sum = points.reduce((acc, p) => ({ x: acc.x + p.x / points.length, y: acc.y + p.y / points.length }), { x: 0, y: 0 });
    return sum;
  }
  let areaSum = 0;
  let cx = 0;
  let cy = 0;
  for (let i = 0; i < points.length; i++) {
    const p = points[i];
    const q = points[(i + 1) % points.length];
    const cross = p.x * q.y - q.x * p.y;
    areaSum += cross;
    cx += (p.x + q.x) * cross;
    cy += (p.y + q.y) * cross;
  }
  if (Math.abs(areaSum) <= 1e-6) {
    return points.reduce((acc, p) => ({ x: acc.x + p.x / points.length, y: acc.y + p.y / points.length }), { x: 0, y: 0 });
  }
  return { x: cx / (3 * areaSum), y: cy / (3 * areaSum) };
}

/** 射线法判点在多边形内，边界算在内（Swift polygonContains L158-174） */
function polygonContains(point, points) {
  if (!isFinitePoint(point) || !points || points.length < 3 ||
      !points.every(isFinitePoint) || polygonArea(points) <= 1e-12) return false;
  let inside = false;
  for (let i = 0; i < points.length; i++) {
    const a = points[i];
    const b = points[(i + 1) % points.length];
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const cross = (point.x - a.x) * dy - (point.y - a.y) * dx;
    if (Math.abs(cross) <= 1e-9 * Math.max(1, Math.hypot(dx, dy)) &&
        point.x >= Math.min(a.x, b.x) - 1e-9 && point.x <= Math.max(a.x, b.x) + 1e-9 &&
        point.y >= Math.min(a.y, b.y) - 1e-9 && point.y <= Math.max(a.y, b.y) + 1e-9) return true;
    if ((a.y > point.y) !== (b.y > point.y) &&
        point.x < a.x + (point.y - a.y) * dx / dy) inside = !inside;
  }
  return inside;
}

/** Andrew 单调链凸包（Swift convexHull L203-221） */
function convexHull(points) {
  if (!points || !points.length) return [];
  const sorted = points.filter(isFinitePoint).slice().sort((a, b) => (a.x === b.x ? a.y - b.y : a.x - b.x));
  const unique = [];
  sorted.forEach((p) => { if (!unique.length || unique[unique.length - 1].x !== p.x || unique[unique.length - 1].y !== p.y) unique.push(p); });
  if (unique.length < 3) return unique;
  const cross = (a, b, c) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
  const lower = [];
  for (const p of unique) {
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], p) <= 0) lower.pop();
    lower.push(p);
  }
  const upper = [];
  for (let i = unique.length - 1; i >= 0; i--) {
    const p = unique[i];
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], p) <= 0) upper.pop();
    upper.push(p);
  }
  return lower.slice(0, -1).concat(upper.slice(0, -1));
}

/** 最小包围盒；不足三点或零面积返回 null（Swift polygonBounds L281-296） */
function polygonBounds(points) {
  if (!points || points.length < 3) return null;
  let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
  for (const p of points) {
    if (!isFinitePoint(p)) return null;
    minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x);
    minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y);
  }
  const width = Math.max(0, maxX - minX);
  const height = Math.max(0, maxY - minY);
  return width > 0 && height > 0 ? { x: minX, y: minY, width, height } : null;
}

/** 点到线段最短距离（Swift HouseSpatialSurveyModel L2502-2513 同口径） */
function distancePointToSegment(p, a, b) {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const len2 = dx * dx + dy * dy;
  const t = len2 > 0 ? Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2)) : 0;
  return Math.hypot(p.x - a.x - t * dx, p.y - a.y - t * dy);
}

/** 到凸包边界的最小距离（Swift entranceDoorID 内 boundaryDistance L184-194） */
function distanceToHullBoundary(p, points) {
  const hull = convexHull(points);
  if (hull.length < 3) return 0;
  let min = Infinity;
  for (let i = 0; i < hull.length; i++) {
    min = Math.min(min, distancePointToSegment(p, hull[i], hull[(i + 1) % hull.length]));
  }
  return min === Infinity ? 0 : min;
}

/** 入口门判定：取离凸包边界最近且最宽的候选（Swift entranceDoorID L178-201） */
function entranceDoorID(wallEndpoints, doors) {
  const pts = wallEndpoints.filter(isFinitePoint);
  const candidates = doors.filter((d) => d && Number.isFinite(d.width) && isFinitePoint(d.position));
  if (!candidates.length) return null;
  const scored = candidates.map((d) => ({ door: d, distance: distanceToHullBoundary(d.position, pts) }));
  const nearest = Math.min.apply(null, scored.map((s) => s.distance));
  const nearBoundary = scored.filter((s) => s.distance <= nearest + 0.05).map((s) => s.door);
  const widest = Math.max.apply(null, nearBoundary.map((d) => d.width));
  const winners = nearBoundary.filter((d) => d.width >= widest - 0.001).map((d) => String(d.id));
  winners.sort();
  return winners.length ? winners[0] : null;
}

/** 恢复宽高比后的顺时针方位角（Swift bearing L225-231） */
function bearing(from, to, aspectRatio) {
  const ratio = Number.isFinite(aspectRatio) && aspectRatio > 0 ? aspectRatio : 1;
  const dx = (to.x - from.x) * ratio;
  const dy = to.y - from.y;
  const angle = Math.atan2(dx, -dy) * 180 / Math.PI;
  return ((angle + 360) % 360 + 360) % 360;
}

/** 等比适配矩形（Swift aspectFitRect L233-240） */
function aspectFitRect(aspectRatio, bounds) {
  if (!bounds || bounds.width <= 0 || bounds.height <= 0) return { x: 0, y: 0, width: 0, height: 0 };
  const ratio = Number.isFinite(aspectRatio) && aspectRatio > 0 ? aspectRatio : 1;
  const width = Math.min(bounds.width, bounds.height * ratio);
  const height = width / ratio;
  return {
    x: bounds.x + bounds.width / 2 - width / 2,
    y: bounds.y + bounds.height / 2 - height / 2,
    width, height
  };
}

function normalizeRect(r) {
  const x = Math.min(r.x, r.x + r.width);
  const y = Math.min(r.y, r.y + r.height);
  return { x, y, width: Math.abs(r.width), height: Math.abs(r.height) };
}

/** 多边形 AABB 与矩形的 IoU（Swift polygonRectIOU L299-308，注意 iOS 用 AABB 而非精确多边形交） */
function polygonRectIOU(polygon, rect) {
  const bounds = polygonBounds(polygon);
  if (!bounds) return 0;
  const a = normalizeRect(bounds);
  const b = normalizeRect(rect);
  const ix = Math.max(a.x, b.x);
  const iy = Math.max(a.y, b.y);
  const iw = Math.min(a.x + a.width, b.x + b.width) - ix;
  const ih = Math.min(a.y + a.height, b.y + b.height) - iy;
  if (iw <= 0 || ih <= 0) return 0;
  const pa = polygonArea(polygon);
  const ra = b.width * b.height;
  const union = pa + ra - iw * ih;
  return union > 0 ? (iw * ih) / union : 0;
}

/** 线段相交判定（Swift HouseSpatialSurveyModel lineSegmentIntersection L2455-2463） */
function segmentsIntersect(p1, p2, q1, q2) {
  const ccw = (a, b, c) => (c.y - a.y) * (b.x - a.x) > (b.y - a.y) * (c.x - a.x);
  return ccw(p1, q1, q2) !== ccw(p2, q1, q2) && ccw(p1, p2, q1) !== ccw(p1, p2, q2);
}

/** 交点参数 t（Swift lineIntersectionParam L2467-2482），平行返回 null */
function lineIntersectionParam(p1, p2, q1, q2) {
  const r = { x: p2.x - p1.x, y: p2.y - p1.y };
  const s = { x: q2.x - q1.x, y: q2.y - q1.y };
  const denom = r.x * s.y - r.y * s.x;
  if (Math.abs(denom) < 1e-12) return null;
  const qp = { x: q1.x - p1.x, y: q1.y - p1.y };
  return (qp.x * s.y - qp.y * s.x) / denom;
}

/** 最长墙主轴角（Swift primaryAxisAngle L2486-2500 同口径：最长边相对 X 轴夹角） */
function primaryAxisAngle(polygon) {
  if (!polygon || polygon.length < 2) return 0;
  let best = null;
  for (let i = 0; i < polygon.length; i++) {
    const a = polygon[i];
    const b = polygon[(i + 1) % polygon.length];
    const len = Math.hypot(b.x - a.x, b.y - a.y);
    if (!best || len > best.len) best = { len, angle: Math.atan2(b.y - a.y, b.x - a.x) * 180 / Math.PI };
  }
  return best ? best.angle : 0;
}

/** 度数 → 八卦（Swift guaForAngle L2439-2451 同口径：以正北为坎） */
function guaForAngle(deg) {
  const names = ['坎', '艮', '震', '巽', '离', '坤', '兑', '乾'];
  const h = ((Number(deg) % 360) + 360) % 360;
  return names[Math.floor(((h + 22.5) % 360) / 45)];
}

module.exports = {
  isFinitePoint,
  polygonArea,
  polygonCentroid,
  polygonContains,
  convexHull,
  polygonBounds,
  distancePointToSegment,
  distanceToHullBoundary,
  entranceDoorID,
  bearing,
  aspectFitRect,
  polygonRectIOU,
  segmentsIntersect,
  lineIntersectionParam,
  primaryAxisAngle,
  guaForAngle
};
