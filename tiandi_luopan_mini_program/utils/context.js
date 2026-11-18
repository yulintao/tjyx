/**
 * context.js
 * 全局上下文快照：当前方位 / 所处位置 / 时令 / 本人生辰。
 *
 * 首页与各结论页共用同一份来源，避免「罗盘页 30°、盘解页 270°」这类前后不一致：
 *   - 方位：orientation.current()（罗盘测向或手选，唯一数据源）
 *   - 位置：最近一次定位结果（本机缓存，不常驻监听，省电也省权限）
 *   - 时令：节气进度（当前节气 + 距下一节气天数）
 *   - 生辰：家庭档案里的宅主出生年与命卦
 */

const store = require('./store');
const orientation = require('./orientation');
const ST = require('./solar-terms');
const BZ = require('./bazhai');
const SF = require('./sitface');

const PLACE_KEY = 'yj_place';

const pad = (n) => String(n).padStart(2, '0');

function dateText(d) {
  const t = d || new Date();
  return `${t.getFullYear()}-${pad(t.getMonth() + 1)}-${pad(t.getDate())} ${pad(t.getHours())}:${pad(t.getMinutes())}`;
}

/** 坐向文本：山 + 向 + 度数 */
function sitFaceText(state) {
  const s = state || orientation.current();
  const deg = Math.round(s.heading) % 360;
  return `${s.sit}山${s.face}向 · ${deg}°`;
}

/** 位置文本：优先用户命名地点，否则坐标 */
function placeText() {
  const p = store.read(PLACE_KEY, null);
  if (!p || (p.lat === undefined && p.lng === undefined)) return { text: '未定位', at: 0, has: false };
  if (p.name) return { text: p.name, at: p.at || 0, has: true };
  return {
    text: `${Math.abs(p.lat).toFixed(2)}°${p.lat >= 0 ? 'N' : 'S'} ${Math.abs(p.lng).toFixed(2)}°${p.lng >= 0 ? 'E' : 'W'}`,
    at: p.at || 0,
    has: true
  };
}

/** 生辰文本：宅主出生年 + 命卦；没有档案时给引导文案 */
function personText() {
  const profiles = store.getProfiles() || {};
  const owner = profiles.owner;
  if (!owner || !owner.birthYear) return { text: '未设生辰', has: false };
  try {
    const g = BZ.lifeGua(owner.birthYear, owner.gender);
    const name = owner.name || '本人';
    return { text: `${name} · ${owner.birthYear} 年 · ${g.name}命`, has: true };
  } catch (e) {
    return { text: `${owner.name || '本人'} · ${owner.birthYear} 年`, has: true };
  }
}

/** 时令文本：节气 + 距下一节气天数 */
function termText() {
  const t = ST.solarTermProgress(new Date());
  return { text: `${t.name} · ${t.nextName}前 ${t.daysToNext} 天`, daysToNext: t.daysToNext, name: t.name };
}

/** 一次取齐四项，供页面/组件渲染 */
function snapshot() {
  const state = orientation.current();
  const place = placeText();
  const person = personText();
  const term = termText();
  return {
    sit: state.sit,
    face: state.face,
    heading: state.heading,
    sitFace: sitFaceText(state),
    source: state.source,
    sourceLabel: orientation.sourceLabel(state),
    place: place.text,
    placeAt: place.at,
    hasPlace: place.has,
    person: person.text,
    hasPerson: person.has,
    term: term.text,
    termName: term.name,
    daysToNext: term.daysToNext,
    dateText: dateText()
  };
}

/**
 * 刷新定位（只取一次，不常驻）。
 * 失败时保留旧值，并在回调里告知调用方，页面不必弹权限说明。
 */
function refreshPlace(callback) {
  const done = (payload) => {
    if (typeof callback === 'function') callback(payload);
  };
  if (typeof wx === 'undefined' || !wx.getLocation) {
    done(null);
    return;
  }
  wx.getLocation({
    type: 'gcj02',
    isHighAccuracy: true,
    highAccuracyExpireTime: 3000,
    success: (res) => {
      const p = {
        lat: Math.round(res.latitude * 10000) / 10000,
        lng: Math.round(res.longitude * 10000) / 10000,
        at: Date.now()
      };
      store.write(PLACE_KEY, p);
      done(p);
    },
    fail: () => done(null)
  });
}

/** 允许用户给当前点命名（如「自家客厅」），便于回来后一眼认位置 */
function namePlace(name) {
  const p = store.read(PLACE_KEY, null) || {};
  p.name = String(name || '').trim().slice(0, 16);
  p.at = Date.now();
  store.write(PLACE_KEY, p);
  return p;
}

module.exports = {
  PLACE_KEY,
  snapshot,
  sitFaceText,
  placeText,
  personText,
  termText,
  refreshPlace,
  namePlace,
  dateText
};
