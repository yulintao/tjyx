const FP = require('./floorplan');
const XK = require('./xuankong');

/**
 * 空间测绘报告长图（对齐 iOS `SurveyReportRenderer.renderReportImage`）
 *
 * iOS 侧报告图由 `HouseSpatialSurveyEngine.analyzeSpatialHouse` 产出：
 * 物理参数（面宽/进深/净层高/面积/进深面宽比/墙段数/开孔数）+ 空间得分 + 形煞清单与化解。
 * 小程序只有 2D 矩形房间数据（无墙体、门窗开孔、LiDAR 净层高），因此：
 *   - 可测项（面宽、进深、套内面积、建筑估算面积、进深面宽比、房间数、九宫完整度、缺角、凶宫）照算；
 *   - 不可测项（净层高、墙体段数、开孔数）显式写「未采集」，不编数、不计分。
 * 画布高度按条目数动态增长（iOS 修 bug 时同样改为「不丢条目」）。
 */

const PAD = 44;
const W = 750;

function pad2(n) {
  return n < 10 ? '0' + n : String(n);
}

function dateText(d) {
  const t = d || new Date();
  return `${t.getFullYear()}-${pad2(t.getMonth() + 1)}-${pad2(t.getDate())} ${pad2(t.getHours())}:${pad2(t.getMinutes())}`;
}

/** 按字数折行（中文按 1 字 ≈ 1 em，混排时略有误差，仅用于排版留白） */
function wrapByChars(text, maxChars, maxLines) {
  const src = String(text || '').replace(/\s+/g, ' ').trim();
  if (!src) return [];
  const chars = Array.from(src);
  const lines = [];
  for (let i = 0; i < chars.length; i += maxChars) {
    lines.push(chars.slice(i, i + maxChars).join(''));
    if (maxLines && lines.length >= maxLines) {
      if (i + maxChars < chars.length) lines[lines.length - 1] += '…';
      break;
    }
  }
  return lines;
}

/**
 * 组装报告内容（不依赖 wx，可在 Node 下直接测）
 * @param {object} plan { sit, face, widthMeters, rooms, pivot, label }
 * @param {object} opts { period, now }
 */
function build(plan, opts) {
  const o = opts || {};
  const p = plan || {};
  const rooms = Array.isArray(p.rooms) ? p.rooms : [];
  const sit = p.sit || '子';
  const face = p.face || '午';

  let chart = null;
  let period = o.period;
  try {
    if (!period) period = XK.periodForYear((o.now || new Date()).getFullYear());
    chart = XK.calculateChart({ sitMountain: sit, faceMountain: face, period });
  } catch (e) {
    chart = null;
  }

  const m = FP.surveyMetrics(Object.assign({}, p, { sit, face }), chart);

  const title = '演象时空 · 全屋空间测绘与形煞存证';
  const subtitle = `基准坐向 ${sit}山${face}向 · 空间得分 ${m.score} 分 · ${dateText(o.now)} · ${period ? '三元九运·' + period + '运' : ''}`.replace(/·\s*$/, '');

  const dims = [
    `开间面宽 ${m.totalWidth.toFixed(2)} m　·　进深 ${m.totalDepth.toFixed(2)} m`,
    `室内净层高 未采集　·　进深面宽比 ${m.aspectRatio.toFixed(2)}`,
    `套内净面积 ${m.usableFloorArea.toFixed(1)} ㎡　·　建筑估算 ${m.grossFloorArea.toFixed(1)} ㎡`,
    `房间 ${m.roomCount} 间　·　九宫满宫 ${m.palacesFull}/9　·　缺角 ${m.palacesMissing} 宫　·　气偏 ${m.palacesPart} 宫`,
    '墙体段数 未采集　·　门窗开孔 未采集（小程序无 LiDAR / RoomPlan 采集）'
  ];

  const corners = (m.missingCorners || []).slice(0, 6).map((a) => ({
    title: `${a.name}（${a.dir}）缺角 · 覆盖 ${Math.round((a.ratio || 0) * 100)}%`,
    hurt: wrapByChars(a.hurt, 30, 3),
    remedy: wrapByChars('化解：' + (a.remedy || ''), 30, 3),
    source: wrapByChars(a.source || '', 32, 2)
  }));

  const xiong = (m.xiongRooms || []).slice(0, 8).map((r) => {
    const head = `${r.palaceName || r.palace || ''}·${r.name || ''} 山${r.shan || ''}向${r.xiang || ''}`;
    return wrapByChars(`${head}：${r.advice || ''}`, 26, 2);
  });

  const footer = [
    '本报告由手工录入户型 + 九宫几何算法生成，缺「净层高 / 墙体 / 门窗」三项实测数据，',
    '需现场复核后再作决策依据。仅供传统文化研究与参考，不构成决策依据。'
  ];

  // 高度估算：标题区 + 参数区 + 缺角区 + 凶宫区 + 页脚
  let h = 300;
  h += 60; // 参数区标题
  dims.forEach(() => (h += 34));
  h += 70; // 缺角区标题
  if (!corners.length) h += 36;
  corners.forEach((c) => {
    h += 38 + c.hurt.length * 30 + c.remedy.length * 30 + c.source.length * 26 + 18;
  });
  h += 70; // 凶宫区标题
  if (!xiong.length) h += 36;
  xiong.forEach((lines) => (h += lines.length * 30 + 8));
  h += 120 + footer.length * 28 + 40;
  if (h < 1334) h = 1334;

  return {
    width: W,
    height: h,
    title,
    subtitle,
    dims,
    corners,
    xiong,
    footer,
    metrics: m,
    sit,
    face,
    period: period || null,
    scoreNote: m.scoreNote
  };
}

/** 文本换行绘制 */
function drawLines(ctx, lines, x, y, size, color, lineHeight) {
  ctx.fillStyle = color;
  ctx.font = `${size}px "PingFang SC", "Noto Sans SC", sans-serif`;
  let cur = y;
  lines.forEach((ln) => {
    ctx.fillText(ln, x, cur);
    cur += lineHeight || size + 8;
  });
  return cur;
}

function sectionHeader(ctx, text, x, y) {
  ctx.fillStyle = '#e9d8a6';
  ctx.font = 'bold 26px "PingFang SC", "Noto Sans SC", sans-serif';
  ctx.fillText(text, x, y);
  ctx.strokeStyle = 'rgba(233,216,166,0.35)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(x, y + 12);
  ctx.lineTo(W - PAD, y + 12);
  ctx.stroke();
  return y + 44;
}

/**
 * 绘制报告长图
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} W 逻辑宽（750）
 * @param {number} H 逻辑高（payload.height）
 * @param {object} payload build() 的返回
 */
function draw(ctx, W_, H, payload) {
  const P = payload || build(null, {});
  const width = W_ || W;

  // 底：墨色 + 顶部金线
  ctx.fillStyle = '#0a0c11';
  ctx.fillRect(0, 0, width, H);
  ctx.fillStyle = 'rgba(233,216,166,0.10)';
  ctx.fillRect(0, 0, width, 6);

  ctx.textAlign = 'left';
  ctx.textBaseline = 'alphabetic';

  let y = 88;
  ctx.fillStyle = '#e9d8a6';
  ctx.font = 'bold 34px "PingFang SC", "Noto Sans SC", sans-serif';
  ctx.fillText(P.title, PAD, y);
  y += 42;
  ctx.fillStyle = '#8f9bb3';
  ctx.font = '20px "PingFang SC", "Noto Sans SC", sans-serif';
  ctx.fillText(P.subtitle, PAD, y);
  y += 26;
  // 得分条
  const barW = width - PAD * 2;
  ctx.fillStyle = 'rgba(255,255,255,0.08)';
  ctx.fillRect(PAD, y, barW, 8);
  ctx.fillStyle = P.score >= 80 ? '#7fd3a0' : (P.metrics.score >= 60 ? '#e9d8a6' : '#e88b8b');
  ctx.fillRect(PAD, y, Math.max(6, barW * Math.min(1, Math.max(0, P.metrics.score) / 100)), 8);
  y += 40;

  y = sectionHeader(ctx, '【房屋全维物理测绘参数】', PAD, y);
  ctx.fillStyle = '#c9d1e0';
  ctx.font = '22px "PingFang SC", "Noto Sans SC", sans-serif';
  P.dims.forEach((ln) => {
    ctx.fillText(ln, PAD, y);
    y += 34;
  });
  y += 26;

  y = sectionHeader(ctx, '【九宫完整度与缺角断语】', PAD, y);
  if (!P.corners.length) {
    ctx.fillStyle = '#7fd3a0';
    ctx.font = '22px "PingFang SC", "Noto Sans SC", sans-serif';
    ctx.fillText('九宫无缺角，宅形完整。', PAD, y);
    y += 40;
  }
  P.corners.forEach((c) => {
    ctx.fillStyle = '#e88b8b';
    ctx.font = 'bold 22px "PingFang SC", "Noto Sans SC", sans-serif';
    ctx.fillText(c.title, PAD, y);
    y += 32;
    y = drawLines(ctx, c.hurt, PAD, y, 20, '#c9d1e0', 30);
    y = drawLines(ctx, c.remedy, PAD, y, 20, '#7fd3a0', 30);
    if (c.source && c.source.length) y = drawLines(ctx, c.source, PAD, y, 18, '#6f7a8f', 26);
    y += 14;
  });
  y += 20;

  y = sectionHeader(ctx, '【玄空九宫凶星与化解】', PAD, y);
  if (!P.xiong.length) {
    ctx.fillStyle = '#8f9bb3';
    ctx.font = '22px "PingFang SC", "Noto Sans SC", sans-serif';
    ctx.fillText('当前坐向元运下无凶宫房间，或未录入房间。', PAD, y);
    y += 40;
  }
  P.xiong.forEach((lines) => {
    y = drawLines(ctx, lines, PAD, y, 20, '#c9d1e0', 30);
    y += 6;
  });
  y += 24;

  y = sectionHeader(ctx, '【评分口径与免责】', PAD, y);
  y = drawLines(ctx, wrapByChars(P.scoreNote, 34, 5), PAD, y, 18, '#8f9bb3', 28);
  y += 10;
  y = drawLines(ctx, P.footer, PAD, y, 18, '#8f9bb3', 28);

  // 页脚印章
  ctx.save();
  ctx.strokeStyle = 'rgba(200,60,50,0.9)';
  ctx.fillStyle = 'rgba(200,60,50,0.9)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(width - PAD - 44, H - 84, 42, 0, Math.PI * 2);
  ctx.stroke();
  ctx.font = 'bold 22px "PingFang SC", serif';
  ctx.textAlign = 'center';
  ctx.fillText('演', width - PAD - 44, H - 92);
  ctx.fillText('象', width - PAD - 44, H - 62);
  ctx.restore();
  ctx.textAlign = 'left';

  // 底部金线
  ctx.fillStyle = 'rgba(233,216,166,0.10)';
  ctx.fillRect(0, H - 6, width, 6);
}

/** 报告纯文本（复制/分享兜底） */
function toText(payload) {
  const P = payload || build(null, {});
  const out = [];
  out.push(P.title);
  out.push(P.subtitle);
  out.push('');
  out.push('【房屋全维物理测绘参数】');
  P.dims.forEach((d) => out.push('· ' + d));
  out.push('');
  out.push('【九宫完整度与缺角断语】');
  if (!P.corners.length) out.push('九宫无缺角，宅形完整。');
  P.corners.forEach((c) => {
    out.push('· ' + c.title);
    c.hurt.forEach((l) => out.push('  ' + l));
    c.remedy.forEach((l) => out.push('  ' + l));
    (c.source || []).forEach((l) => out.push('  ' + l));
  });
  out.push('');
  out.push('【玄空九宫凶星与化解】');
  if (!P.xiong.length) out.push('无凶宫房间或未录入房间。');
  P.xiong.forEach((lines) => out.push('· ' + lines.join('')));
  out.push('');
  out.push('【评分口径】' + P.scoreNote);
  P.footer.forEach((f) => out.push(f));
  return out.join('\n');
}

module.exports = { build, draw, toText, wrapByChars, dateText, W, PAD };
