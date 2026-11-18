/**
 * scroll-painter.js
 * 天机长卷：宣纸底 + 朱丝栏 + 竖排卷名 + 双栏小楷 + 双印落款
 * 内容过长时自动分页，每页单独出图，避免单张画布超出平台尺寸上限。
 * 纸墨皮肤统一取自 utils/paper-skin.js。
 */

const SK = require('./paper-skin');

const CN_NUM = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八'];

const LAYOUT = {
  W: 750,
  pad: 46,
  fs: 20,            // 小楷字号
  lh: 32,            // 行距
  colGap: 34,        // 双栏间距
  secGap: 26,
  headH: 250,        // 首页卷首
  headCompactH: 130, // 续页页眉
  footH: 170,        // 卷尾
  maxPageH: 1900     // 单页版面高（dpr 2 时物理高 3800，留足平台余量）
};

/** 视觉宽度：中文 1，ASCII 0.55 */
function visWidth(str) {
  let w = 0;
  const s = String(str);
  for (let i = 0; i < s.length; i++) w += s.charCodeAt(i) < 128 ? 0.55 : 1;
  return w;
}

/** 按列宽折行 */
function wrap(text, cols) {
  const out = [];
  const t = String(text);
  let line = '';
  let w = 0;
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
    const headUsed = isFirst ? LAYOUT.headH + m.guideH : LAYOUT.headCompactH;
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

  SK.paper(ctx, W, H);
  SK.frame(ctx, W, H, { pad });
  SK.divider(ctx, pad + colW + colGap / 2, pad, H - pad);

  const data = info || {};
  let y;

  if (page.isFirst) {
    // 卷首：右侧竖排卷名 + 副名
    SK.verticalText(ctx, '天机长卷', W - pad - 26, pad + 34, 40, 52);
    SK.verticalText(ctx, '演象时空', W - pad - 26, pad + 34 + 4 * 52 + 24, 17, 22, 'rgba(107,90,68,0.8)');

    ctx.save();
    ctx.textAlign = 'left';
    ctx.fillStyle = SK.INK.text;
    ctx.font = 'bold 26px serif';
    ctx.fillText(data.title || '', pad, pad + 54);
    ctx.fillStyle = SK.INK.textSoft;
    ctx.font = '20px serif';
    ctx.fillText(data.dateText || '', pad, pad + 90);
    ctx.fillStyle = SK.INK.zhu;
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
    ctx.fillStyle = SK.INK.zhu;
    ctx.font = 'bold 20px serif';
    ctx.fillText('天机长卷 · 续', pad, pad + 40);
    ctx.fillStyle = SK.INK.faint;
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
    y = SK.sectionHeader(ctx, { pad, right: W - pad, y, no: `第 ${b.no} 章`, title: b.title });
    ctx.save();
    ctx.textAlign = 'left';
    ctx.fillStyle = SK.INK.text;
    ctx.font = '20px serif';
    const startY = y;
    b.left.forEach((line, i) => ctx.fillText(line, colX[0], startY + i * lh));
    b.right.forEach((line, i) => ctx.fillText(line, colX[1], startY + i * lh));
    ctx.restore();
    y += Math.max(b.left.length, b.right.length) * lh + LAYOUT.secGap;
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
  ctx.fillStyle = SK.INK.textSoft;
  ctx.font = '18px serif';
  ctx.fillText('演象时空罗盘 · 天机长卷 · 依传统堪舆规则生成，仅作环境与空间参考', pad, footY + 32);
  ctx.fillText('古法象徵语句不作医疗、财务或法律依据；现场仍须复核坐向、排水与结构安全。', pad, footY + 58);

  SK.seal(ctx, pad, footY + 84, 58, '演象', 'zhu');
  SK.seal(ctx, pad + 74, footY + 84, 58, '时空', 'bai');

  ctx.textAlign = 'right';
  ctx.fillStyle = SK.INK.faint;
  ctx.font = '16px serif';
  ctx.fillText(`${data.dateText || ''}　第 ${page.pageNo} / ${data.pageCount || 1} 页`, W - pad, footY + 116);
  ctx.restore();

  return { W, H };
}

module.exports = { LAYOUT, measure, paginate, paint, wrap, visWidth };
