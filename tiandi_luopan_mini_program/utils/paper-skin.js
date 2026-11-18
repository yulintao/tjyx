/**
 * paper-skin.js
 * 纸墨皮肤：宣纸底、朱丝栏、朱/白文印、竖排卷名、章节抬头。
 * 长卷（scroll-painter）、存证报告（reportcard）、分享海报（poster）共用同一套纸墨，
 * 保证用户在「导出长卷 / 存证报告 / 分享海报」里看到的是同一家门面。
 */

const INK = {
  paperTop: '#f9f4e6',
  paperMid: '#f3ead6',
  paperBottom: '#eadfc7',
  text: '#2b2118',
  textSoft: '#6b5a44',
  textFaint: 'rgba(107,90,68,0.8)',
  zhu: '#8a1f1f',
  zhuLine: 'rgba(150,30,30,0.50)',
  zhuLineSoft: 'rgba(150,30,30,0.16)',
  seal: 'rgba(176,38,32,0.92)',
  sealText: '#ffeee8',
  good: '#2f6b45',      // 化解、可用（纸面上用深绿，不用荧光绿）
  bad: '#a3301f',       // 形煞、慎用
  faint: 'rgba(107,90,68,0.72)'
};

/** 宣纸底：渐变 + 确定性纸纹 + 上下暗角 */
function paper(ctx, W, H, seedBase) {
  const g = ctx.createLinearGradient(0, 0, 0, H);
  g.addColorStop(0, INK.paperTop);
  g.addColorStop(0.55, INK.paperMid);
  g.addColorStop(1, INK.paperBottom);
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, W, H);

  let seed = seedBase || 20261118;
  const rnd = () => {
    seed = (seed * 1103515245 + 12345) % 2147483648;
    return seed / 2147483648;
  };
  const dots = Math.round((W * H) / 5200);
  for (let i = 0; i < dots; i++) {
    const x = rnd() * W;
    const y = rnd() * H;
    ctx.fillStyle = `rgba(140,120,80,${(0.03 + rnd() * 0.05).toFixed(3)})`;
    ctx.fillRect(x, y, 1 + rnd() * 2, 1 + rnd() * 1.4);
  }
  ctx.strokeStyle = 'rgba(150,130,90,0.05)';
  ctx.lineWidth = 0.6;
  const fibers = Math.round(H / 55);
  for (let i = 0; i < fibers; i++) {
    const y = rnd() * H;
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(W, y + (rnd() - 0.5) * 8);
    ctx.stroke();
  }
  const band = Math.min(90, Math.round(H * 0.08));
  const top = ctx.createLinearGradient(0, 0, 0, band);
  top.addColorStop(0, 'rgba(120,96,60,0.10)');
  top.addColorStop(1, 'rgba(120,96,60,0)');
  ctx.fillStyle = top;
  ctx.fillRect(0, 0, W, band);
  const bottom = ctx.createLinearGradient(0, H - band, 0, H);
  bottom.addColorStop(0, 'rgba(120,96,60,0)');
  bottom.addColorStop(1, 'rgba(120,96,60,0.10)');
  ctx.fillStyle = bottom;
  ctx.fillRect(0, H - band, W, band);
}

/** 朱丝栏：外框双线 + 可选分栏竖线 */
function frame(ctx, W, H, opts) {
  const o = opts || {};
  const pad = o.pad || 46;
  const columns = o.columns || 0;
  ctx.save();
  ctx.strokeStyle = INK.zhuLine;
  ctx.lineWidth = 2.4;
  ctx.strokeRect(pad * 0.45, pad * 0.45, W - pad * 0.9, H - pad * 0.9);
  ctx.strokeStyle = 'rgba(150,30,30,0.26)';
  ctx.lineWidth = 1;
  ctx.strokeRect(pad * 0.45 + 9, pad * 0.45 + 9, W - pad * 0.9 - 18, H - pad * 0.9 - 18);
  if (columns) {
    ctx.strokeStyle = 'rgba(150,30,30,0.14)';
    for (let i = 1; i < columns; i++) {
      const x = pad + ((W - pad * 2) / columns) * i;
      ctx.beginPath();
      ctx.moveTo(x, pad);
      ctx.lineTo(x, H - pad);
      ctx.stroke();
    }
  }
  ctx.restore();
}

/** 单根竖线分栏（双栏长卷用） */
function divider(ctx, x, y1, y2) {
  ctx.save();
  ctx.strokeStyle = 'rgba(150,30,30,0.16)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(x, y1);
  ctx.lineTo(x, y2);
  ctx.stroke();
  ctx.restore();
}

/** 印：朱文（红框红字）/ 白文（红底白字），2 字竖排 */
function seal(ctx, x, y, size, text, mode, color) {
  ctx.save();
  const c = color || INK.seal;
  if (mode === 'bai') {
    ctx.fillStyle = c;
    ctx.fillRect(x, y, size, size);
    ctx.strokeStyle = 'rgba(255,232,222,0.72)';
    ctx.lineWidth = 2;
    ctx.strokeRect(x + 7, y + 7, size - 14, size - 14);
    ctx.fillStyle = INK.sealText;
  } else {
    ctx.strokeStyle = c;
    ctx.lineWidth = 3;
    ctx.strokeRect(x + 2, y + 2, size - 4, size - 4);
    ctx.strokeRect(x + 8, y + 8, size - 16, size - 16);
    ctx.fillStyle = c;
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

/** 竖排文字（每字一格） */
function verticalText(ctx, text, x, y, size, gap, color) {
  ctx.save();
  ctx.fillStyle = color || INK.zhu;
  ctx.font = `bold ${size}px serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  const t = String(text);
  for (let i = 0; i < t.length; i++) ctx.fillText(t[i], x, y + i * gap);
  ctx.restore();
}

/** 章节抬头：「第 N 章」小字 + 朱红标题 + 双横线，返回下一行 y */
function sectionHeader(ctx, opts) {
  const o = opts || {};
  const pad = o.pad || 46;
  const right = o.right || 750 - pad;
  const y = o.y || 0;
  ctx.save();
  ctx.textAlign = 'left';
  if (o.no) {
    ctx.fillStyle = 'rgba(107,90,68,0.9)';
    ctx.font = '17px serif';
    ctx.fillText(o.no, pad, y + 4);
  }
  ctx.fillStyle = INK.zhu;
  ctx.font = 'bold 27px serif';
  ctx.fillText(o.title || '', pad + (o.no ? 74 : 0), y + 8);
  ctx.strokeStyle = 'rgba(150,30,30,0.34)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(pad, y + 20);
  ctx.lineTo(right, y + 20);
  ctx.stroke();
  ctx.strokeStyle = 'rgba(150,30,30,0.16)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(pad, y + 24);
  ctx.lineTo(right, y + 24);
  ctx.stroke();
  ctx.restore();
  return y + 56;
}

module.exports = { INK, paper, frame, divider, seal, verticalText, sectionHeader };
