/**
 * poster.js
 * 分享海报绘制：盘面 + 坐向 + 分金 + 玄空格局 + 落款
 * 只用 Canvas 2D 基础能力，便于在真机与开发者工具一致渲染。
 */

const MOUNTAINS_24 = ['子', '癸', '丑', '艮', '寅', '甲', '卯', '乙', '辰', '巽', '巳', '丙', '午', '丁', '未', '坤', '申', '庚', '酉', '辛', '戌', '乾', '亥', '壬'];
const TRIGRAM_LABEL = ['坎', '艮', '震', '巽', '离', '坤', '兑', '乾'];
const SK = require('./paper-skin');

/**
 * 绘制海报
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} W 画布宽
 * @param {number} H 画布高
 * @param {object} data { sit, face, heading, jiazi, grade, nayin, period, shan, xiang, pattern, dateText }
 */
function draw(ctx, W, H, data) {
  const d = data || {};
  // 底色
  const bg = ctx.createLinearGradient(0, 0, 0, H);
  bg.addColorStop(0, '#141a26');
  bg.addColorStop(1, '#0b0e15');
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, W, H);

  // 金线边框
  ctx.strokeStyle = 'rgba(233,216,166,0.35)';
  ctx.lineWidth = 2;
  ctx.strokeRect(24, 24, W - 48, H - 48);

  // 标题
  ctx.textAlign = 'center';
  ctx.fillStyle = '#e9d8a6';
  ctx.font = 'bold 54px sans-serif';
  ctx.fillText('演象时空罗盘', W / 2, 132);
  ctx.fillStyle = 'rgba(207,216,234,0.75)';
  ctx.font = '26px sans-serif';
  ctx.fillText('二十四山 · 三元九运 · 玄空飞星', W / 2, 182);

  // 盘面
  const cx = W / 2;
  const cy = 470;
  const R = 250;
  const heading = d.heading || 0;

  ctx.beginPath();
  ctx.arc(cx, cy, R, 0, Math.PI * 2);
  ctx.strokeStyle = 'rgba(233,216,166,0.75)';
  ctx.lineWidth = 3;
  ctx.stroke();
  ctx.beginPath();
  ctx.arc(cx, cy, R - 42, 0, Math.PI * 2);
  ctx.strokeStyle = 'rgba(233,216,166,0.28)';
  ctx.lineWidth = 2;
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

    const lx = cx + (R - 78) * Math.sin(rad);
    const ly = cy - (R - 78) * Math.cos(rad);
    ctx.fillStyle = i % 3 === 0 ? '#e9d8a6' : 'rgba(226,232,244,0.82)';
    ctx.font = '26px sans-serif';
    ctx.fillText(MOUNTAINS_24[i], lx, ly + 8);
  }

  // 八卦方位名
  for (let i = 0; i < 8; i++) {
    const a = i * 45;
    const screen = ((a - heading) % 360 + 360) % 360;
    const rad = (screen * Math.PI) / 180;
    const lx = cx + (R + 58) * Math.sin(rad);
    const ly = cy - (R + 58) * Math.cos(rad);
    ctx.fillStyle = 'rgba(159,176,203,0.85)';
    ctx.font = '24px sans-serif';
    ctx.fillText(TRIGRAM_LABEL[i], lx, ly + 8);
  }

  // 中心读数
    ctx.fillStyle = '#e9d8a6';
  ctx.font = 'bold 46px sans-serif';
  ctx.fillText(`${d.sit || '—'}山${d.face || '—'}向`, cx, cy - 6);
  ctx.fillStyle = 'rgba(207,216,234,0.9)';
  ctx.font = '30px sans-serif';
  ctx.fillText(`${(heading || 0).toFixed(1)}°`, cx, cy + 44);

  // 十字
  ctx.strokeStyle = 'rgba(233,216,166,0.65)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(cx - 120, cy);
  ctx.lineTo(cx - 70, cy);
  ctx.moveTo(cx + 70, cy);
  ctx.lineTo(cx + 120, cy);
  ctx.moveTo(cx, cy - 120);
  ctx.lineTo(cx, cy - 70);
  ctx.moveTo(cx, cy + 70);
  ctx.lineTo(cx, cy + 120);
  ctx.stroke();

  // 数据行
  const rows = [
    ['坐　向', `${d.sit || '—'}山${d.face || '—'}向　${(heading || 0).toFixed(1)}°`],
    ['分　金', `${d.jiazi || '—'}　${d.grade || '—'}${d.nayin ? '　' + d.nayin : ''}`],
    ['元　运', `${d.period || '—'}运　山星${d.shan || '—'}　向星${d.xiang || '—'}`],
    ['格　局', d.pattern || '—']
  ];
  let ry = 810;
  rows.forEach(([k, v]) => {
    ctx.textAlign = 'left';
    ctx.fillStyle = 'rgba(143,155,179,0.95)';
    ctx.font = '26px sans-serif';
    ctx.fillText(k, 78, ry);
    ctx.fillStyle = '#dfe4ee';
    ctx.font = '28px sans-serif';
    ctx.fillText(v, 210, ry);
    ry += 62;
  });

  // 落款
  ctx.textAlign = 'center';
  ctx.fillStyle = 'rgba(233,216,166,0.9)';
  ctx.font = '30px sans-serif';
  ctx.fillText('微信搜索「演象时空罗盘」', W / 2, H - 118);
  ctx.fillStyle = 'rgba(143,155,179,0.8)';
  ctx.font = '22px sans-serif';
  ctx.fillText(`${d.dateText || ''}　仅供传统文化研究参考`, W / 2, H - 72);

  // 与长卷、存证报告同源的朱白双印（海报底色深，印色提亮一档）
  SK.seal(ctx, 56, H - 126, 50, '演象', 'zhu', 'rgba(214,80,64,0.95)');
  SK.seal(ctx, 118, H - 126, 50, '时空', 'bai', 'rgba(196,56,44,0.95)');

  return true;
}

module.exports = { MOUNTAINS_24, TRIGRAM_LABEL, draw };
