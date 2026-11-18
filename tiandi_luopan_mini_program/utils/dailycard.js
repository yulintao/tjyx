/**
 * dailycard.js
 * 今日吉方日签海报：黑金风格的当日日课卡
 * 内容对齐 iOS BaZhaiEngine.DailyAuspiciousCardSheet：
 * 干支四柱、建除十二神、十二值神、宜忌、冲煞、财神喜神方位、当令节气、落款。
 * 只用 Canvas 2D 基础能力，保证开发者工具与真机渲染一致。
 */

const C = {
  bgTop: '#141a26',
  bgBottom: '#080a10',
  gold: '#e9d8a6',
  goldDim: 'rgba(233,216,166,0.45)',
  goldLine: 'rgba(233,216,166,0.25)',
  paper: '#12151f',
  text: '#e5e9f0',
  sub: '#9aa4b8',
  yi: '#7fd3a0',
  ji: '#e88b8b',
  wealth: '#f1c40f',
  joy: '#2ec4b6'
};

const WEEK = ['日', '一', '二', '三', '四', '五', '六'];

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.arcTo(x + w, y, x + w, y + r, r);
  ctx.lineTo(x + w, y + h - r);
  ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
  ctx.lineTo(x + r, y + h);
  ctx.arcTo(x, y + h, x, y + h - r, r);
  ctx.lineTo(x, y + r);
  ctx.arcTo(x, y, x + r, y, r);
  ctx.closePath();
}

/** 文本自动折行，返回实际绘制行数 */
function wrapText(ctx, text, x, y, maxW, lineH, maxLines) {
  const s = String(text || '');
  const lines = [];
  let cur = '';
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (ctx.measureText(cur + ch).width > maxW && cur) {
      lines.push(cur);
      cur = ch;
    } else {
      cur += ch;
    }
  }
  if (cur) lines.push(cur);
  const n = maxLines ? Math.min(lines.length, maxLines) : lines.length;
  for (let i = 0; i < n; i++) {
    let line = lines[i];
    if (maxLines && i === maxLines - 1 && lines.length > maxLines) {
      while (line.length > 1 && ctx.measureText(line + '…').width > maxW) line = line.slice(0, -1);
      line += '…';
    }
    ctx.fillText(line, x, y + i * lineH);
  }
  return n;
}

/**
 * 绘制日签
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} W
 * @param {number} H
 * @param {object} data {
 *   dateText, weekText, lunarText, pillars:{yearPillar,monthPillar,dayPillar,fullStr},
 *   jianChu:{name, info:{yi,ji,summary}}, godName, solarName,
 *   wealth:{dir,name,angle}, joy:{dir,name,angle}, chong:{zhi,zodiac,text},
 *   yi:string, ji:string, bestHours:string[], warnings:string[]
 * }
 */
function draw(ctx, W, H, data) {
  const d = data || {};
  const pad = 56;
  const innerW = W - pad * 2;

  // ---------- 底 ----------
  const bg = ctx.createLinearGradient(0, 0, 0, H);
  bg.addColorStop(0, C.bgTop);
  bg.addColorStop(1, C.bgBottom);
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, W, H);

  // 细密暗纹（横线）
  ctx.strokeStyle = 'rgba(255,255,255,0.022)';
  ctx.lineWidth = 1;
  for (let y = 0; y < H; y += 8) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(W, y);
    ctx.stroke();
  }

  // 双层金边
  ctx.strokeStyle = C.goldDim;
  ctx.lineWidth = 3;
  ctx.strokeRect(pad * 0.55, pad * 0.55, W - pad * 1.1, H - pad * 1.1);
  ctx.strokeStyle = C.goldLine;
  ctx.lineWidth = 1;
  ctx.strokeRect(pad * 0.55 + 10, pad * 0.55 + 10, W - pad * 1.1 - 20, H - pad * 1.1 - 20);

  // 四角回纹装饰
  const corner = 40;
  const c0 = pad * 0.55 + 4;
  ctx.strokeStyle = C.goldDim;
  ctx.lineWidth = 2;
  const corners = [[c0, c0, 1, 1], [W - c0, c0, -1, 1], [c0, H - c0, 1, -1], [W - c0, H - c0, -1, -1]];
  for (let i = 0; i < corners.length; i++) {
    const cx = corners[i][0];
    const cy = corners[i][1];
    const sx = corners[i][2];
    const sy = corners[i][3];
    ctx.beginPath();
    ctx.moveTo(cx, cy + sy * corner);
    ctx.lineTo(cx, cy);
    ctx.lineTo(cx + sx * corner, cy);
    ctx.stroke();
  }

  // ---------- 头 ----------
  ctx.textAlign = 'center';
  ctx.textBaseline = 'alphabetic';
  ctx.fillStyle = C.gold;
  ctx.font = 'bold 52px sans-serif';
  ctx.fillText('演象时空罗盘', W / 2, pad * 0.55 + 110);

  ctx.fillStyle = 'rgba(207,216,234,0.7)';
  ctx.font = '26px sans-serif';
  ctx.fillText('今 日 日 签', W / 2, pad * 0.55 + 160);

  // 分隔线 + 菱形
  const sepY = pad * 0.55 + 196;
  ctx.strokeStyle = C.goldLine;
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(W / 2 - 150, sepY);
  ctx.lineTo(W / 2 - 16, sepY);
  ctx.moveTo(W / 2 + 16, sepY);
  ctx.lineTo(W / 2 + 150, sepY);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(W / 2, sepY - 8);
  ctx.lineTo(W / 2 + 8, sepY);
  ctx.lineTo(W / 2, sepY + 8);
  ctx.lineTo(W / 2 - 8, sepY);
  ctx.closePath();
  ctx.fillStyle = C.gold;
  ctx.fill();

  // ---------- 日期块 ----------
  let y = sepY + 44;
  ctx.fillStyle = C.text;
  ctx.font = 'bold 40px sans-serif';
  ctx.fillText(d.dateText || '', W / 2, y + 34);
  ctx.fillStyle = C.sub;
  ctx.font = '24px sans-serif';
  ctx.fillText(`星期${d.weekText || ''}${d.lunarText ? ' · ' + d.lunarText : ''}`, W / 2, y + 72);

  y += 108;
  // 干支三柱
  const gp = d.pillars || {};
  const pillars = [gp.yearPillar, gp.monthPillar, gp.dayPillar].filter(Boolean);
  if (pillars.length) {
    const boxW = innerW;
    ctx.fillStyle = 'rgba(255,255,255,0.035)';
    roundRect(ctx, pad, y, boxW, 96, 14);
    ctx.fill();
    ctx.strokeStyle = C.goldLine;
    ctx.lineWidth = 1;
    roundRect(ctx, pad, y, boxW, 96, 14);
    ctx.stroke();

    const cellW = boxW / pillars.length;
    ctx.font = 'bold 34px sans-serif';
    for (let i = 0; i < pillars.length; i++) {
      const cx = pad + cellW * (i + 0.5);
      if (i > 0) {
        ctx.strokeStyle = C.goldLine;
        ctx.beginPath();
        ctx.moveTo(pad + cellW * i, y + 20);
        ctx.lineTo(pad + cellW * i, y + 76);
        ctx.stroke();
      }
      ctx.fillStyle = i === 2 ? C.gold : C.text;
      ctx.fillText(pillars[i], cx, y + 62);
    }
    ctx.fillStyle = C.sub;
    ctx.font = '20px sans-serif';
    ctx.fillText(['年', '月', '日'].slice(0, pillars.length).join('     '), W / 2, y + 120);
    y += 150;
  }

  // ---------- 建除 + 值神 ----------
  ctx.textAlign = 'left';
  const jc = d.jianChu || {};
  ctx.fillStyle = C.sub;
  ctx.font = '24px sans-serif';
  ctx.fillText('建除', pad, y + 24);
  ctx.fillStyle = C.gold;
  ctx.font = 'bold 46px sans-serif';
  ctx.fillText(`${jc.name || '—'}日`, pad, y + 76);
  ctx.fillStyle = C.text;
  ctx.font = '26px sans-serif';
  if (d.godName) ctx.fillText(`${d.godName}值日`, pad, y + 112);
  if (d.solarName) {
    ctx.fillStyle = C.sub;
    ctx.font = '22px sans-serif';
    ctx.fillText(`当令节气 · ${d.solarName}`, pad, y + 146);
  }
  y += 186;

  // ---------- 宜 ----------
  const blockH = 210;
  ctx.fillStyle = 'rgba(94,170,120,0.10)';
  roundRect(ctx, pad, y, innerW, blockH, 14);
  ctx.fill();
  ctx.strokeStyle = 'rgba(127,211,160,0.35)';
  ctx.lineWidth = 1;
  roundRect(ctx, pad, y, innerW, blockH, 14);
  ctx.stroke();

  ctx.fillStyle = C.yi;
  ctx.font = 'bold 34px sans-serif';
  ctx.textAlign = 'left';
  ctx.fillText('宜', pad + 24, y + 46);
  ctx.fillStyle = '#d7f5e4';
  ctx.font = '24px sans-serif';
  const yiLines = wrapText(ctx, d.yi || '', pad + 24, y + 86, innerW - 48, 36, 3);
  y += blockH + 22;

  // ---------- 忌 ----------
  ctx.fillStyle = 'rgba(214,94,94,0.10)';
  roundRect(ctx, pad, y, innerW, blockH, 14);
  ctx.fill();
  ctx.strokeStyle = 'rgba(232,139,139,0.35)';
  ctx.lineWidth = 1;
  roundRect(ctx, pad, y, innerW, blockH, 14);
  ctx.stroke();

  ctx.fillStyle = C.ji;
  ctx.font = 'bold 34px sans-serif';
  ctx.fillText('忌', pad + 24, y + 46);
  ctx.fillStyle = '#f7dede';
  ctx.font = '24px sans-serif';
  wrapText(ctx, d.ji || '', pad + 24, y + 86, innerW - 48, 36, 3);
  y += blockH + 26;

  // ---------- 财神 / 喜神 ----------
  const w = d.wealth || {};
  const j = d.joy || {};
  const halfW = (innerW - 20) / 2;
  const godBoxH = 132;

  ctx.fillStyle = 'rgba(241,196,15,0.08)';
  roundRect(ctx, pad, y, halfW, godBoxH, 14);
  ctx.fill();
  ctx.strokeStyle = 'rgba(241,196,15,0.4)';
  ctx.lineWidth = 1;
  roundRect(ctx, pad, y, halfW, godBoxH, 14);
  ctx.stroke();
  ctx.fillStyle = C.wealth;
  ctx.font = '22px sans-serif';
  ctx.fillText('财神方位', pad + 20, y + 36);
  ctx.fillStyle = '#fff3c4';
  ctx.font = 'bold 40px sans-serif';
  ctx.fillText(`${w.dir || '—'}`, pad + 20, y + 88);
  ctx.fillStyle = C.sub;
  ctx.font = '20px sans-serif';
  ctx.fillText(`${w.angle !== undefined ? w.angle + '°' : ''} ${w.name || ''}`, pad + 20, y + 118);

  const x2 = pad + halfW + 20;
  ctx.fillStyle = 'rgba(46,196,182,0.08)';
  roundRect(ctx, x2, y, halfW, godBoxH, 14);
  ctx.fill();
  ctx.strokeStyle = 'rgba(46,196,182,0.4)';
  ctx.lineWidth = 1;
  roundRect(ctx, x2, y, halfW, godBoxH, 14);
  ctx.stroke();
  ctx.fillStyle = C.joy;
  ctx.font = '22px sans-serif';
  ctx.fillText('喜神方位', x2 + 20, y + 36);
  ctx.fillStyle = '#d3fbf6';
  ctx.font = 'bold 40px sans-serif';
  ctx.fillText(`${j.dir || '—'}`, x2 + 20, y + 88);
  ctx.fillStyle = C.sub;
  ctx.font = '20px sans-serif';
  ctx.fillText(`${j.angle !== undefined ? j.angle + '°' : ''} ${j.name || ''}`, x2 + 20, y + 118);
  y += godBoxH + 26;

  // ---------- 冲煞 ----------
  const ch = d.chong || {};
  ctx.fillStyle = 'rgba(255,255,255,0.035)';
  roundRect(ctx, pad, y, innerW, 92, 14);
  ctx.fill();
  ctx.strokeStyle = C.goldLine;
  ctx.lineWidth = 1;
  roundRect(ctx, pad, y, innerW, 92, 14);
  ctx.stroke();
  ctx.textAlign = 'left';
  ctx.fillStyle = C.ji;
  ctx.font = 'bold 24px sans-serif';
  ctx.fillText('冲煞', pad + 20, y + 36);
  ctx.fillStyle = '#f2d6d6';
  ctx.font = '22px sans-serif';
  wrapText(ctx, `日冲${ch.zhi || '—'}（属${ch.zodiac || '—'}），该属相宜静，忌远行签约`, pad + 20, y + 66, innerW - 40, 30, 1);
  y += 92 + 26;

  // ---------- 吉时 ----------
  if (d.bestHours && d.bestHours.length) {
    ctx.fillStyle = C.sub;
    ctx.font = '22px sans-serif';
    ctx.fillText('今日吉时', pad, y + 26);
    const arr = d.bestHours.slice(0, 4);
    ctx.font = 'bold 24px sans-serif';
    for (let i = 0; i < arr.length; i++) {
      const bw = (innerW - 18 * (arr.length - 1)) / arr.length;
      const bx = pad + (bw + 18) * i;
      ctx.fillStyle = 'rgba(233,216,166,0.10)';
      roundRect(ctx, bx, y + 42, bw, 52, 10);
      ctx.fill();
      ctx.strokeStyle = C.goldLine;
      ctx.lineWidth = 1;
      roundRect(ctx, bx, y + 42, bw, 52, 10);
      ctx.stroke();
      ctx.fillStyle = C.gold;
      ctx.textAlign = 'center';
      ctx.fillText(arr[i], bx + bw / 2, y + 76);
    }
    ctx.textAlign = 'left';
    y += 118;
  }

  // ---------- 落款 ----------
  const footerY = H - pad * 0.55 - 96;
  ctx.strokeStyle = C.goldLine;
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(pad, footerY);
  ctx.lineTo(W - pad, footerY);
  ctx.stroke();

  ctx.textAlign = 'left';
  ctx.fillStyle = C.goldDim;
  ctx.font = '22px sans-serif';
  ctx.fillText('演象时空罗盘 · 天机物舍', pad, footerY + 40);
  ctx.fillStyle = 'rgba(154,164,184,0.75)';
  ctx.font = '19px sans-serif';
  ctx.fillText('日课仅供传统文化参考', pad, footerY + 70);

  // 印章
  const seal = 74;
  const sx = W - pad - seal;
  const sy = footerY + 8;
  ctx.fillStyle = 'rgba(180,52,44,0.88)';
  roundRect(ctx, sx, sy, seal, seal, 10);
  ctx.fill();
  ctx.strokeStyle = 'rgba(255,220,214,0.55)';
  ctx.lineWidth = 1.5;
  roundRect(ctx, sx + 6, sy + 6, seal - 12, seal - 12, 8);
  ctx.stroke();
  ctx.fillStyle = '#ffe7e2';
  ctx.font = 'bold 24px sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText('演', sx + seal / 2 - 0.5, sy + 32);
  ctx.fillText('象', sx + seal / 2 - 0.5, sy + 60);

  // 底部细金线收口
  ctx.strokeStyle = C.goldDim;
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(W / 2 - 90, H - pad * 0.55 - 26);
  ctx.lineTo(W / 2 + 90, H - pad * 0.55 - 26);
  ctx.stroke();
}

module.exports = { draw, wrapText };
