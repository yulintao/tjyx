/**
 * poster.js
 * 分享海报绘制：盘面 + 坐向 + 分金 + 玄空格局 + 落款
 * 只用 Canvas 2D 基础能力，便于在真机与开发者工具一致渲染。
 */

const MOUNTAINS_24 = ['子', '癸', '丑', '艮', '寅', '甲', '卯', '乙', '辰', '巽', '巳', '丙', '午', '丁', '未', '坤', '申', '庚', '酉', '辛', '戌', '乾', '亥', '壬'];
const TRIGRAM_LABEL = ['坎', '艮', '震', '巽', '离', '坤', '兑', '乾'];
const SK = require('./paper-skin');

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

/**
 * 绘制海报
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} W 画布宽
 * @param {number} H 画布高
 * @param {object} data { sit, face, heading, jiazi, grade, nayin, period, shan, xiang, pattern, dateText }
 */
function draw(ctx, W, H, data) {
  const d = data || {};
  // 底色渐变
  const bg = ctx.createLinearGradient(0, 0, 0, H);
  bg.addColorStop(0, '#161c2c');
  bg.addColorStop(0.5, '#0f131f');
  bg.addColorStop(1, '#090b11');
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, W, H);

  // 中心罗盘暗金光晕
  const cx = W / 2;
  const cy = 468;
  const R = 246;
  const halo = ctx.createRadialGradient(cx, cy, 20, cx, cy, R + 90);
  halo.addColorStop(0, 'rgba(212,175,55,0.16)');
  halo.addColorStop(0.65, 'rgba(212,175,55,0.04)');
  halo.addColorStop(1, 'rgba(212,175,55,0)');
  ctx.fillStyle = halo;
  ctx.fillRect(0, 120, W, R * 2 + 180);

  // 双层金线外框
  ctx.strokeStyle = 'rgba(233,216,166,0.42)';
  ctx.lineWidth = 2.5;
  ctx.strokeRect(24, 24, W - 48, H - 48);
  ctx.strokeStyle = 'rgba(233,216,166,0.16)';
  ctx.lineWidth = 1;
  ctx.strokeRect(34, 34, W - 68, H - 68);

  // 四角古典回纹角饰
  const cLen = 36;
  const cOff = 28;
  ctx.strokeStyle = 'rgba(233,216,166,0.6)';
  ctx.lineWidth = 2;
  const corners = [[cOff, cOff, 1, 1], [W - cOff, cOff, -1, 1], [cOff, H - cOff, 1, -1], [W - cOff, H - cOff, -1, -1]];
  for (let i = 0; i < corners.length; i++) {
    const x0 = corners[i][0];
    const y0 = corners[i][1];
    const sx = corners[i][2];
    const sy = corners[i][3];
    ctx.beginPath();
    ctx.moveTo(x0, y0 + sy * cLen);
    ctx.lineTo(x0, y0);
    ctx.lineTo(x0 + sx * cLen, y0);
    ctx.stroke();
  }

  // 标题
  ctx.textAlign = 'center';
  ctx.fillStyle = '#f2dfb0';
  ctx.font = 'bold 52px sans-serif';
  ctx.fillText('演象时空罗盘', W / 2, 118);
  ctx.fillStyle = 'rgba(207,216,234,0.75)';
  ctx.font = '24px sans-serif';
  ctx.fillText('二十四山 · 三元九运 · 玄空飞星', W / 2, 162);

  // 盘面
  const heading = d.heading || 0;

  ctx.beginPath();
  ctx.arc(cx, cy, R, 0, Math.PI * 2);
  ctx.strokeStyle = 'rgba(233,216,166,0.82)';
  ctx.lineWidth = 3;
  ctx.stroke();
  ctx.beginPath();
  ctx.arc(cx, cy, R - 42, 0, Math.PI * 2);
  ctx.strokeStyle = 'rgba(233,216,166,0.32)';
  ctx.lineWidth = 1.5;
  ctx.stroke();
  ctx.beginPath();
  ctx.arc(cx, cy, R - 110, 0, Math.PI * 2);
  ctx.strokeStyle = 'rgba(233,216,166,0.16)';
  ctx.lineWidth = 1;
  ctx.stroke();

  for (let i = 0; i < 24; i++) {
    const a = i * 15;
    const screen = ((a - heading) % 360 + 360) % 360;
    const rad = (screen * Math.PI) / 180;
    const x1 = cx + (R - 42) * Math.sin(rad);
    const y1 = cy - (R - 42) * Math.cos(rad);
    const x2 = cx + R * Math.sin(rad);
    const y2 = cy - R * Math.cos(rad);
    ctx.beginPath();
    ctx.moveTo(x1, y1);
    ctx.lineTo(x2, y2);
    ctx.strokeStyle = 'rgba(233,216,166,0.5)';
    ctx.lineWidth = 2;
    ctx.stroke();

    const lx = cx + (R - 76) * Math.sin(rad);
    const ly = cy - (R - 76) * Math.cos(rad);
    ctx.fillStyle = i % 3 === 0 ? '#f2dfb0' : 'rgba(226,232,244,0.84)';
    ctx.font = '25px sans-serif';
    ctx.fillText(MOUNTAINS_24[i], lx, ly + 8);
  }

  // 八卦方位名
  for (let i = 0; i < 8; i++) {
    const a = i * 45;
    const screen = ((a - heading) % 360 + 360) % 360;
    const rad = (screen * Math.PI) / 180;
    const lx = cx + (R + 48) * Math.sin(rad);
    const ly = cy - (R + 48) * Math.cos(rad);
    ctx.fillStyle = 'rgba(176,192,220,0.9)';
    ctx.font = '24px sans-serif';
    ctx.fillText(TRIGRAM_LABEL[i], lx, ly + 8);
  }

  // 中心读数
  ctx.fillStyle = '#f6e7be';
  ctx.font = 'bold 46px sans-serif';
  ctx.fillText(`${d.sit || '—'}山${d.face || '—'}向`, cx, cy - 6);
  ctx.fillStyle = 'rgba(207,216,234,0.92)';
  ctx.font = '30px sans-serif';
  ctx.fillText(`${(heading || 0).toFixed(1)}°`, cx, cy + 44);

  // 十字准星
  ctx.strokeStyle = 'rgba(233,216,166,0.7)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(cx - 122, cy);
  ctx.lineTo(cx - 72, cy);
  ctx.moveTo(cx + 72, cy);
  ctx.lineTo(cx + 122, cy);
  ctx.moveTo(cx, cy - 122);
  ctx.lineTo(cx, cy - 72);
  ctx.moveTo(cx, cy + 72);
  ctx.lineTo(cx, cy + 122);
  ctx.stroke();

  // 数据卡片底衬
  const boxX = 56;
  const boxY = 768;
  const boxW = W - 112;
  const boxH = 268;
  ctx.fillStyle = 'rgba(255,255,255,0.035)';
  roundRect(ctx, boxX, boxY, boxW, boxH, 16);
  ctx.fill();
  ctx.strokeStyle = 'rgba(233,216,166,0.22)';
  ctx.lineWidth = 1;
  roundRect(ctx, boxX, boxY, boxW, boxH, 16);
  ctx.stroke();

  // 数据行
  const rows = [
    ['坐　向', `${d.sit || '—'}山${d.face || '—'}向　${(heading || 0).toFixed(1)}°`],
    ['分　金', `${d.jiazi || '—'}　${d.grade || '—'}${d.nayin ? '　' + d.nayin : ''}`],
    ['元　运', `${d.period || '—'}运　山星${d.shan || '—'}　向星${d.xiang || '—'}`],
    ['格　局', d.pattern || '—']
  ];
  let ry = boxY + 56;
  rows.forEach(([k, v], idx) => {
    ctx.textAlign = 'left';
    ctx.fillStyle = 'rgba(154,166,189,0.95)';
    ctx.font = '25px sans-serif';
    ctx.fillText(k, boxX + 28, ry);
    ctx.fillStyle = idx === 0 ? '#f2dfb0' : '#e6ebf4';
    ctx.font = '26px sans-serif';
    ctx.fillText(v, boxX + 150, ry);
    if (idx < rows.length - 1) {
      ctx.strokeStyle = 'rgba(130,152,196,0.12)';
      ctx.beginPath();
      ctx.moveTo(boxX + 24, ry + 20);
      ctx.lineTo(boxX + boxW - 24, ry + 20);
      ctx.stroke();
    }
    ry += 58;
  });

  // 落款
  ctx.textAlign = 'center';
  ctx.fillStyle = 'rgba(242,223,176,0.92)';
  ctx.font = '30px sans-serif';
  ctx.fillText('微信搜索「演象时空罗盘」', W / 2, H - 114);
  ctx.fillStyle = 'rgba(143,155,179,0.82)';
  ctx.font = '22px sans-serif';
  ctx.fillText(`${d.dateText || ''}　仅供传统文化研究参考`, W / 2, H - 68);

  // 与长卷、存证报告同源的朱白双印（海报底色深，印色提亮一档）
  SK.seal(ctx, 56, H - 126, 50, '演象', 'zhu', 'rgba(214,80,64,0.95)');
  SK.seal(ctx, 118, H - 126, 50, '时空', 'bai', 'rgba(196,56,44,0.95)');

  return true;
}

module.exports = { MOUNTAINS_24, TRIGRAM_LABEL, draw };
