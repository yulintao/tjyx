/**
 * orientation.js
 * 全局「当前坐向」唯一数据源。
 *
 * 背景：小程序 tabBar 页之间不能带 url 参数，nav.js 的一次性 tabParams
 * 只在「点击跳转那一瞬间」有效。盘解 / 择日 / 户型页从 tabBar 直接进入、
 * 或在 tab 间切换时，会退回默认「子山午向」，与罗盘实际方位脱节。
 *
 * 本模块把罗盘实时/锁定方位持久化，并允许业务页手动覆盖：
 *   - source = 'compass'：来自罗盘传感器或锁定角；
 *   - source = 'manual' ：用户在盘解/择日/户型页手选坐山，
 *                          此时罗盘实时值不再自动覆盖（回到罗盘页会清除该标记）。
 *
 * 所有页面在 onShow 调 current()，即可拿到最新方位并重算。
 */

const KEY = 'yj_current_orientation';
const SF = require('./sitface');

const api = typeof wx !== 'undefined' ? wx : {
  getStorageSync: () => '',
  setStorageSync: () => {}
};

let memory = null;

function read() {
  try {
    if (memory) return memory;
    const raw = api.getStorageSync(KEY);
    if (!raw) return null;
    const data = typeof raw === 'string' ? JSON.parse(raw) : raw;
    if (!data || SF.MOUNTAINS_24.indexOf(data.sit) < 0) return null;
    memory = data;
    return data;
  } catch (e) {
    return null;
  }
}

function write(sit, heading, source) {
  const idx = SF.MOUNTAINS_24.indexOf(sit);
  if (idx < 0) return null;
  const h = (heading !== null && heading !== undefined && !isNaN(Number(heading)))
    ? ((Number(heading) % 360) + 360) % 360
    : SF.azimuthOf(sit);
  memory = {
    sit,
    face: SF.opposite(sit),
    sitIdx: idx,
    heading: h,
    source: source || 'compass',
    updatedAt: Date.now()
  };
  try { api.setStorageSync(KEY, memory); } catch (e) {}
  return memory;
}

/** 罗盘方位变化时调用；手动覆盖期间不写入，避免传感器把用户选择冲掉。 */
function fromCompass(heading) {
  if (read() && memory && memory.source === 'manual') return memory;
  const d = SF.diagnoseHeading(heading);
  return write(d.sit, heading, 'compass');
}

/** 业务页手选坐山时调用，阻止罗盘实时值继续覆盖。 */
function fromManual(sit) {
  return write(sit, SF.azimuthOf(sit), 'manual');
}

/** 回到罗盘页：解除手动覆盖，恢复传感器驱动。 */
function releaseManual() {
  const cur = read();
  if (cur && cur.source === 'manual') {
    cur.source = 'compass';
    memory = cur;
    try { api.setStorageSync(KEY, cur); } catch (e) {}
  }
  return memory;
}

/** 取当前方位；无记录时返回默认的子山午向。 */
function current() {
  return read() || { sit: '子', face: '午', sitIdx: 0, heading: 0, source: 'default', updatedAt: 0 };
}

/** 给用户看的坐向来源文案：让「罗盘 / 手选」联动在页面上可见。 */
function sourceLabel(state) {
  const src = (state || current()).source;
  if (src === 'manual') return '手动选择';
  if (src === 'compass') return '罗盘方位';
  return '默认方位（未测向）';
}

/** 同一来源的补充说明，用于页面提示。 */
function sourceHint(state) {
  const src = (state || current()).source;
  if (src === 'manual') return '此坐山由本页手选，罗盘实时值暂不覆盖；回到罗盘页即恢复实时测向。';
  if (src === 'compass') return '当前坐山来自罗盘测向，盘解 / 择日 / 户型已同步联动。';
  return '尚未取罗盘方位，当前按默认子山午向；到罗盘页测向后会自动同步到这里。';
}

/** 供页面判断是否需要重算：坐山或来源变化才触发。 */
function differs(a, b) {
  if (!a || !b) return true;
  return a.sit !== b.sit || a.source !== b.source;
}

/** 页面展示用：来源 + 文案 + 当前坐向，一次取齐。 */
function display(state) {
  const s = state || current();
  return {
    source: s.source,
    sit: s.sit,
    heading: s.heading,
    label: sourceLabel(s),
    hint: sourceHint(s)
  };
}

/** 应用一次性跳转参数时写回全局，保持来源（compass/manual）不变，只更新坐向。 */
function applyPending(sit, heading) {
  const cur = current();
  const source = cur.source === 'default' ? 'compass' : cur.source;
  return write(sit, heading === null || heading === undefined ? undefined : heading, source);
}

module.exports = { KEY, current, fromCompass, fromManual, releaseManual, differs, write, sourceLabel, sourceHint, display, applyPending };
