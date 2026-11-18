/**
 * scroll-painter.js
 * 天机长卷绘制：宣纸底 + 朱丝栏 + 竖排卷首 + 双栏小楷 + 双印落款
 * 内容过长时自动分页，每页单独出图，避免单张画布超出平台尺寸上限。
 */

const CN_NUM = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八'];

const LAYOUT = {
  W: 750,
  pad: 46,
  fs: 20,          // 小楷字号
  lh: 32,          // 行距
  colGap: 34,      // 双栏间距
  secGap: 26,
  headH: 250,      // 首页卷首
  headCompactH: 130, // 续页页眉
  footH: 170,      // 卷尾
  maxPageH: 1900   // 单页版面高（dpr 2 时物理高 3800，留足平台余量）
};

/** 视觉宽度：中文 1，ASCII 0.55 */
function visWidth(str) {
  let w = 0;
  for (let i = 0; i < String(str).length; i++) {
    w += str.charCodeAt(i) < 128 ? 0.55 : 1;
  }
  return w;
}

/** 按列宽折行 */
function wrap(text, cols) {
  const out = [];
  let line = '';
  let w = 0;
  const t = String(text);
  for (let i = 0; i < t.length; i++) {
    const cw = t.charCodeAt(i) < 128 ? 0.55 : 1;
    if (w + cw > cols && line) {
      out.push(line);
      line = t[i];
      w = cw;
    } else {
      line += t[i];
      w += cw;
    }
  }
  if (line) out.push(line);
  return out.length ? out : [''];
}

/** 量版面：折行 → 双栏均分 → 章块高度 */
function measure(data) {
  const { W, pad, colGap, fs, lh, secGap, headH, footH } = LAYOUT;
  const colW = (W - pad * 2 - colGap) / 2;
  const cols = Math.floor(colW / fs);

  const guideLines = String((data && data.guidance) || '')
    .split('\n')
    .filter(Boolean)
    .reduce((arr, line) => arr.concat(wrap(line, cols * 2 + 2)), []);
  const guideH = guideLines.length ? guideLines.length * lh + 30 : 0;

  const blocks = ((data && data.sections) || []).map((sec, si) => {
    const lines = [];
    (sec.rows || []).forEach((row) => wrap(row, cols).forEach((l) => lines.push(l)));
    const half = Math.ceil(lines.length / 2);
    return {
      title: sec.title,
      no: CN_NUM[si] || String(si + 1),
      left: lines.slice(0, half),
      right: lines.slice(half),
      h: 56 + Math.max(half, lines.length - half) * lh + secGap
    };
  });

  const bodyH = blocks.reduce((s, b) => s + b.h, 0);
  return { W, H: headH + guideH + bodyH + footH, cols, colW, blocks, guideLines, guideH, headH, footH };
}

/** 分页：每页不超过 maxPageH，章块不拆开 */
function paginate(data) {
  const m = measure(data);
  const pages = [];
  let i = 0;
  while (i < m.blocks.length) {
    const isFirst = pages.length === 0;
    const headUsed = (isFirst ? LAYOUT.headH + m.guideH : LAYOUT.headCompactH);
    const avail = LAYOUT.maxPageH - headUsed - LAYOUT.footH;
    const blocks = [];
    let used = 0;
    while (i < m.blocks.length) {
      const b = m.blocks[i];
      if (blocks.length && used + b.h > avail) break;
      blocks.push(b);
      used += b.h;
      i++;
    }
    pages.push({
      blocks,
      guideLines: isFirst ? m.guideLines : [],
      isFirst,
      isLast: i >= m.blocks.length,
      H: headUsed + used + LAYOUT.footH,
      pageNo: pages.length + 1
    });
  }
  if (!pages.length) {
    pages.push({ blocks: [], guideLines: [], isFirst: true, isLast: true, H: LAYOUT.headH + LAYOUT.footH, pageNo: 1 });
  }
  return { pages, W: m.W, cols: m.cols, colW: m.colW, totalH: m.H };
}

function drawPaper(ctx, W, H) {
  const g = ctx.createLinearGradient(0, 0, 0, H);
  g.addColorStop(0, '#f9f4e6');
  g.addColorStop(0.55, '#f3ead6');
  g.addColorStop(1, '#eadfc7');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, W, H);

  let seed = 20261118;
  const rnd = () => {
    seed = (seed * 1103515245 + 12345) % 2147483648;
    return seed / 2147483648;
  };
  for (let i = 0; i < 1400; i++) {
    const x = rnd() * W;
    const y = rnd() * H;
    ctx.fillStyle = `rgba(140,120,80,${(0.03 + rnd() * 0.05).toFixed(3)})`;
    ctx.fillRect(x, y, 1 + rnd() * 2, 1 + rnd() * 1.4);
  }
  ctx.strokeStyle = 'rgba(150,130,90,0.05)';
  ctx.lineWidth = 0.6;
  for (let i = 0; i < 90; i++) {
    const y = rnd() * H;
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(W, y + (rnd() - 0.5) * 8);
    ctx.stroke();
  }
  const top = ctx.createLinearGradient(0, 0, 0, 80);
  top.addColorStop(0, 'rgba(120,96,60,0.10)');
  top.addColorStop(1, 'rgba(120,96,60,0)');
  ctx.fillStyle = top;
  ctx.fillRect(0, 0, W, 80);
  const bottom = ctx.createLinearGradient(0, H - 80, 0, H);
  bottom.addColorStop(0, 'rgba(120,96,60,0)');
  bottom.addColorStop(1, 'rgba(120,96,60,0.10)');
  ctx.fillStyle = bottom;
  ctx.fillRect(0, H - 80, W, 80);
}

function drawFrame(ctx, W, H, pad, colW, colGap) {
  ctx.save();
  ctx.strokeStyle = 'rgba(150,30,30,0.50)';
  ctx.lineWidth = 2.4;
  ctx.strokeRect(pad * 0.45, pad * 0.45, W - pad * 0.9, H - pad * 0.9);
  ctx.strokeStyle = 'rgba(150,30,30,0.26)';
  ctx.lineWidth = 1;
  ctx.strokeRect(pad * 0.45 + 9, pad * 0.45 + 9, W - pad * 0.9 - 18, H - pad * 0.9 - 18);
  ctx.strokeStyle = 'rgba(150,30,30,0.16)';
  ctx.beginPath();
  ctx.moveTo(pad + colW + colGap / 2, pad);
  ctx.lineTo(pad + colW + colGap / 2, H - pad);
  ctx.stroke();
  ctx.restore();
}

function drawVerticalText(ctx, text, x, y, size, gap, color) {
  ctx.save();
  ctx.fillStyle = color || '#8a1f1f';
  ctx.font = `bold ${size}px serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  for (let i = 0; i < text.length; i++) ctx.fillText(text[i], x, y + i * gap);
  ctx.restore();
}

function drawSeal(ctx, x, y, size, text, mode) {
  ctx.save();
  if (mode === 'bai') {
    ctx.fillStyle = 'rgba(176,38,32,0.92)';
    ctx.fillRect(x, y, size, size);
    ctx.strokeStyle = 'rgba(255,232,222,0.72)';
    ctx.lineWidth = 2;
    ctx.strokeRect(x + 7, y + 7, size - 14, size - 14);
    ctx.fillStyle = '#ffeee8';
  } else {
    ctx.strokeStyle = 'rgba(176,38,32,0.9)';
    ctx.lineWidth = 3;
    ctx.strokeRect(x + 2, y + 2, size - 4, size - 4);
    ctx.strokeRect(x + 8, y + 8, size - 16, size - 16);
    ctx.fillStyle = 'rgba(176,38,32,0.92)';
  }
  const t = text || '演象';
  ctx.font = `bold ${Math.round(size * 0.32)}px serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  if (t.length === 1) {
    ctx.fillText(t, x + size / 2, y + size / 2);
  } else if (t.length === 2) {
    ctx.fillText(t[0], x + size / 2, y + size * 0.31);
    ctx.fillText(t[1], x + size / 2, y + size * 0.69);
  } else if (t.length === 4) {
    ctx.fillText(t[0], x + size * 0.3, y + size * 0.3);
    ctx.fillText(t[1], x + size * 0.7, y + size * 0.3);
    ctx.fillText(t[2], x + size * 0.7, y + size * 0.7);
    ctx.fillText(t[3], x + size * 0.3, y + size * 0.7);
  } else {
    ctx.fillText(t, x + size / 2, y + size / 2);
  }
  ctx.restore();
}

/**
 * 绘制一页
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} page paginate() 返回的页
 * @param {object} info { W, title, dateText, grade, score, pageCount }
 */
function paint(ctx, page, info) {
  const W = (info && info.W) || LAYOUT.W;
  const H = page.H;
  const { pad, colGap, lh } = LAYOUT;
  const colW = (W - pad * 2 - colGap) / 2;
  const colX = [pad, pad + colW + colGap];

  drawPaper(ctx, W, H);
  drawFrame(ctx, W, H, pad, colW, colGap);

  const data = info || {};
  let y;

  if (page.isFirst) {
    // 卷首：右侧竖排卷名 + 副名
    drawVerticalText(ctx, '天机长卷', W - pad - 26, pad + 34, 40, 52);
    drawVerticalText(ctx, '演象时空', W - pad - 26, pad + 34 + 4 * 52 + 24, 17, 22, 'rgba(107,90,68,0.8)');

    ctx.save();
    ctx.textAlign = 'left';
    ctx.fillStyle = '#2b2118';
    ctx.font = 'bold 26px serif';
    ctx.fillText(data.title || '', pad, pad + 54);
    ctx.fillStyle = '#6b5a44';
    ctx.font = '20px serif';
    ctx.fillText(data.dateText || '', pad, pad + 90);
    ctx.fillStyle = '#8a1f1f';
    ctx.font = 'bold 24px serif';
    ctx.fillText(`总评 ${data.grade || ''} · ${data.score || 0} 分`, pad, pad + 132);
    ctx.restore();

    y = LAYOUT.headH;
    if (page.guideLines && page.guideLines.length) {
      ctx.save();
      ctx.fillStyle = 'rgba(150,30,30,0.16)';
      ctx.fillRect(pad, y - 4, W - pad * 2, page.guideLines.length * lh + 12);
      ctx.fillStyle = '#3a2f22';
      ctx.font = '20px serif';
      ctx.textAlign = 'left';
      page.guideLines.forEach((line, i) => ctx.fillText(line, pad + 10, y + 24 + i * lh));
      ctx.restore();
      y += page.guideLines.length * lh + 30;
    }
  } else {
    ctx.save();
    ctx.textAlign = 'left';
    ctx.fillStyle = '#8a1f1f';
    ctx.font = 'bold 20px serif';
    ctx.fillText('天机长卷 · 续', pad, pad + 40);
    ctx.fillStyle = 'rgba(107,90,68,0.85)';
    ctx.font = '16px serif';
    ctx.fillText(`第 ${page.pageNo} / ${data.pageCount || 1} 页`, pad, pad + 68);
    ctx.strokeStyle = 'rgba(150,30,30,0.30)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(pad, pad + 84);
    ctx.lineTo(W - pad, pad + 84);
    ctx.stroke();
    ctx.restore();
    y = LAYOUT.headCompactH;
  }

  // 章块：双栏
  page.blocks.forEach((b) => {
    ctx.save();
    ctx.textAlign = 'left';
    ctx.fillStyle = 'rgba(107,90,68,0.9)';
    ctx.font = '17px serif';
    ctx.fillText(`第 ${b.no} 章`, pad, y + 4);
    ctx.fillStyle = '#8a1f1f';
    ctx.font = 'bold 27px serif';
    ctx.fillText(b.title, pad + 74, y + 8);
    ctx.strokeStyle = 'rgba(150,30,30,0.34)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(pad, y + 20);
    ctx.lineTo(W - pad, y + 20);
    ctx.stroke();
    ctx.strokeStyle = 'rgba(150,30,30,0.16)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(pad, y + 24);
    ctx.lineTo(W - pad, y + 24);
    ctx.stroke();

    ctx.fillStyle = '#2b2118';
    ctx.font = '20px serif';
    const startY = y + 56;
    b.left.forEach((line, i) => ctx.fillText(line, colX[0], startY + i * lh));
    b.right.forEach((line, i) => ctx.fillText(line, colX[1], startY + i * lh));
    y += b.h;
    ctx.restore();
  });

  // 卷尾
  const footY = H - LAYOUT.footH + 24;
  ctx.save();
  ctx.strokeStyle = 'rgba(150,30,30,0.30)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(pad, footY);
  ctx.lineTo(W - pad, footY);
  ctx.stroke();
  ctx.textAlign = 'left';
  ctx.fillStyle = '#6b5a44';
  ctx.font = '18px serif';
  ctx.fillText('演象时空罗盘 · 天机长卷 · 依传统堪舆规则生成，仅作环境与空间参考', pad, footY + 32);
  ctx.fillText('古法象徵语句不作医疗、财务或法律依据；现场仍须复核坐向、排水与结构安全。', pad, footY + 58);

  drawSeal(ctx, pad, footY + 84, 58, '演象', 'zhu');
  drawSeal(ctx, pad + 74, footY + 84, 58, '时空', 'bai');

  ctx.textAlign = 'right';
  ctx.fillStyle = 'rgba(107,90,68,0.85)';
  ctx.font = '16px serif';
  ctx.fillText(`${data.dateText || ''}　第 ${page.pageNo} / ${data.pageCount || 1} 页`, W - pad, footY + 116);
  ctx.restore();

  return { W, H };
}

module.exports = { LAYOUT, measure, paginate, paint, wrap, visWidth };
