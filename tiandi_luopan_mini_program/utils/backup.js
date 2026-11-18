/**
 * backup.js
 * 全量档案备份 / 恢复（替代 iOS 的 iCloud KVS 同步）
 * iOS 用 NSUbiquitousKeyValueStore 做跨设备同步；小程序改用「导出 JSON + 导入 JSON」，
 * 并预留云开发（wx.cloud）落库，用户自行开通环境即可。
 */

const store = require('./store');

const BACKUP_VERSION = 2;

/**
 * 除 store 的五个主数据段外，还要带走的「现场类」数据。
 * 这些以前散在各处（context / orientation / sha / report），换机后全丢，
 * 现在一起进备份，才谈得上「整机搬家」。
 */
const EXTRA = {
  place: 'yj_place',                       // 定位结果与自定义地点名
  orientation: 'yj_current_orientation',   // 上次坐向（手动或罗盘）
  shaCheck: 'yj_sha_check',                // 外煞勾选进度
  reportDraft: 'yj_report_draft'           // 最近一次测绘报告草稿
};

function collect() {
  const extra = {};
  Object.keys(EXTRA).forEach((name) => {
    extra[name] = store.read(EXTRA[name], null);
  });
  return Object.assign({
    v: BACKUP_VERSION,
    app: 'yanxiang-luopan-miniprogram',
    at: Date.now(),
    settings: store.getSettings(),
    profiles: store.getProfiles(),
    remedyTasks: store.getRemedyTasks(),
    floorplans: store.getFloorplans(),
    history: store.getHistory()
  }, extra);
}

function serialize() {
  return JSON.stringify(collect(), null, 2);
}

/** 只做结构校验，不做语义修正；校验失败返回 error 字段 */
function parse(text) {
  let obj;
  try {
    obj = JSON.parse(String(text || ''));
  } catch (e) {
    return { error: '不是合法的 JSON 文本' };
  }
  if (!obj || typeof obj !== 'object' || Array.isArray(obj)) return { error: '内容为空' };
  if (obj.app && obj.app !== 'yanxiang-luopan-miniprogram') {
    return { error: '不是本小程序的备份文件' };
  }
  if (obj.v !== undefined && Number(obj.v) > BACKUP_VERSION) {
    return { error: `备份版本 v${obj.v} 高于当前支持 v${BACKUP_VERSION}，请升级小程序后再导入` };
  }
  if (!obj.profiles && !obj.floorplans && !obj.settings && !obj.place) {
    return { error: '缺少可恢复的数据段' };
  }

  // 类型校验：整段写错的备份宁可拒绝，也不要把脏数据落进本机
  const bad = (msg) => ({ error: msg });
  if (obj.profiles && typeof obj.profiles !== 'object') return bad('家人档案格式不正确');
  if (obj.profiles && obj.profiles.members !== undefined && !Array.isArray(obj.profiles.members)) {
    return bad('家人档案 members 必须是数组');
  }
  for (let i = 0; i < ['floorplans', 'remedyTasks', 'history'].length; i++) {
    const k = ['floorplans', 'remedyTasks', 'history'][i];
    if (obj[k] !== undefined && !Array.isArray(obj[k])) return bad(`${k} 必须是数组`);
  }
  if (obj.settings !== undefined && (typeof obj.settings !== 'object' || Array.isArray(obj.settings))) {
    return bad('settings 格式不正确');
  }

  return { data: obj, summary: summaryOf(obj) };
}

function summaryOf(obj) {
  const p = obj.profiles || {};
  const place = obj.place || {};
  const members = (Array.isArray(p.members) ? p.members.length : 0) + (p.owner ? 1 : 0);
  return {
    at: obj.at ? new Date(obj.at).toLocaleString() : '未知时间',
    members,
    floorplans: (obj.floorplans || []).length,
    remedyTasks: (obj.remedyTasks || []).length,
    history: (obj.history || []).length,
    hasSettings: !!obj.settings,
    placeName: place.name || (place.lat !== undefined ? '有定位坐标' : ''),
    hasOrientation: !!obj.orientation,
    shaChecked: obj.shaCheck && Array.isArray(obj.shaCheck.checked) ? obj.shaCheck.checked.length : 0,
    hasReportDraft: !!obj.reportDraft
  };
}

function uniqBy(list, keyFn) {
  const map = {};
  const out = [];
  (list || []).forEach((x) => {
    const k = keyFn(x);
    if (k === undefined || k === null) return;
    if (map[k]) return;
    map[k] = true;
    out.push(x);
  });
  return out;
}

const MEMBER_KEY = (x) => `${x.name || ''}|${x.birthYear || ''}|${x.gender || ''}`;

const SETTING_LABEL = {
  lang: '语言',
  unit: '单位',
  notify: '提醒开关',
  showEvidence: '显示原诀',
  guideSeen: '引导已读',
  cloudEnv: '云环境',
  dialView: '盘面现场',
  compassLock: '立向锁定'
};

/**
 * 导入前差异：把「这份备份落到本机会变成什么样」算清楚，
 * 不含任何写操作，供页面在执行恢复之前展示。
 * @param {object} obj 备份对象
 * @param {string} mode 'merge' | 'replace'
 */
function diff(obj, mode) {
  const m = mode === 'replace' ? 'replace' : 'merge';
  const cur = collect();
  const o = obj || {};

  // 家人
  const curMembers = Array.isArray(cur.profiles.members) ? cur.profiles.members : [];
  const curKeys = {};
  curMembers.forEach((x) => { curKeys[MEMBER_KEY(x)] = true; });
  const incMembers = o.profiles && Array.isArray(o.profiles.members) ? o.profiles.members : [];
  const memberAdd = incMembers.filter((x) => !curKeys[MEMBER_KEY(x)]).length;
  const incMemberCount = incMembers.length + (o.profiles && o.profiles.owner ? 1 : 0);

  // 户型
  const curPlanIds = {};
  (cur.floorplans || []).forEach((p) => { if (p && p.id) curPlanIds[p.id] = true; });
  const incPlans = Array.isArray(o.floorplans) ? o.floorplans : [];
  const planAdd = incPlans.filter((p) => !(p && curPlanIds[p.id])).length;

  // 化解任务
  const curTaskById = {};
  (cur.remedyTasks || []).forEach((t) => { if (t && t.id) curTaskById[t.id] = t; });
  const incTasks = Array.isArray(o.remedyTasks) ? o.remedyTasks : [];
  const taskAdd = incTasks.filter((t) => !(t && curTaskById[t.id])).length;
  const taskDoneFlip = m === 'merge'
    ? incTasks.filter((t) => t && curTaskById[t.id] && !curTaskById[t.id].done && t.done).length
    : 0;

  // 历史
  const curHistIds = {};
  (cur.history || []).forEach((h) => { if (h && h.id) curHistIds[h.id] = true; });
  const incHist = Array.isArray(o.history) ? o.history : [];
  const histAdd = incHist.filter((h) => !(h && curHistIds[h.id])).length;

  // 设置：只报「会被改成什么」的键
  const changed = [];
  const curS = cur.settings || {};
  const incS = o.settings || {};
  Object.keys(incS).forEach((k) => {
    if (JSON.stringify(curS[k]) !== JSON.stringify(incS[k])) changed.push(k);
  });

  // 现场数据
  const extraAction = (name) => {
    const local = cur[name];
    const incoming = o[name];
    if (!incoming) return 'none';
    if (m === 'merge' && local) return 'keep';
    return local ? 'overwrite' : 'set';
  };
  const shaLocal = cur.shaCheck && Array.isArray(cur.shaCheck.checked) ? cur.shaCheck.checked.length : 0;
  const shaIncoming = o.shaCheck && Array.isArray(o.shaCheck.checked) ? o.shaCheck.checked.length : 0;

  return {
    mode: m,
    members: { incoming: incMemberCount, add: m === 'replace' ? incMemberCount : memberAdd, dup: m === 'replace' ? 0 : Math.max(0, incMemberCount - memberAdd) },
    floorplans: { incoming: incPlans.length, add: m === 'replace' ? incPlans.length : planAdd, dup: m === 'replace' ? 0 : incPlans.length - planAdd, dropped: m === 'replace' ? Math.max(0, (cur.floorplans || []).length - incPlans.length) : 0 },
    tasks: { incoming: incTasks.length, add: m === 'replace' ? incTasks.length : taskAdd, dup: m === 'replace' ? 0 : incTasks.length - taskAdd, newlyDone: taskDoneFlip },
    history: { incoming: incHist.length, add: m === 'replace' ? incHist.length : histAdd, dup: m === 'replace' ? 0 : incHist.length - histAdd, dropped: m === 'replace' ? Math.max(0, (cur.history || []).length - incHist.length) : 0 },
    settings: { changed: changed.length, keys: changed.map((k) => SETTING_LABEL[k] || k) },
    place: { action: extraAction('place'), placeName: (o.place && o.place.name) || '' },
    orientation: { action: extraAction('orientation') },
    shaCheck: { action: extraAction('shaCheck'), local: shaLocal, incoming: shaIncoming },
    reportDraft: { action: extraAction('reportDraft') }
  };
}

/**
 * 恢复：merge 合并（保留本机较新的设置项） / replace 覆盖
 * @returns {object} 恢复后的统计
 */
function commit(obj, mode) {
  const m = mode === 'replace' ? 'replace' : 'merge';
  const cur = collect();

  // 设置：合并时以本机为底，仅补齐缺失键
  let settings = cur.settings;
  if (obj.settings) {
    settings = m === 'replace' ? obj.settings : Object.assign({}, obj.settings, cur.settings || {});
  }

  // 家人档案：按「姓名+出生年+性别」去重
  let profiles = cur.profiles;
  if (obj.profiles) {
    if (m === 'replace') {
      profiles = obj.profiles;
    } else {
      const base = cur.profiles || { owner: null, members: [] };
      const keyOf = (x) => `${x.name || ''}|${x.birthYear || ''}|${x.gender || ''}`;
      const members = uniqBy((base.members || []).concat((obj.profiles.members || [])), keyOf);
      profiles = { owner: base.owner || obj.profiles.owner || null, members: members.slice(0, 12) };
    }
  }

  // 化解任务：按 id 合并，保留双方 done 状态（任一已完成即完成）
  let tasks = cur.remedyTasks;
  if (obj.remedyTasks) {
    if (m === 'replace') {
      tasks = obj.remedyTasks;
    } else {
      const map = {};
      (obj.remedyTasks || []).forEach((t) => { if (t && t.id) map[t.id] = t; });
      (cur.remedyTasks || []).forEach((t) => {
        if (!t || !t.id) return;
        map[t.id] = map[t.id] ? Object.assign({}, map[t.id], { done: !!(t.done || map[t.id].done) }) : t;
      });
      tasks = Object.keys(map).map((k) => map[k]);
    }
  }

  // 户型：按 id 合并，上限 20
  let plans = cur.floorplans;
  if (obj.floorplans) {
    plans = m === 'replace'
      ? obj.floorplans.slice(0, 20)
      : uniqBy((obj.floorplans || []).concat(cur.floorplans || []), (x) => x && x.id).slice(0, 20);
  }

  // 历史：按 id 合并，按时间倒序，上限 30
  let history = cur.history;
  if (obj.history) {
    const merged = uniqBy((obj.history || []).concat(cur.history || []), (x) => x && x.id);
    history = merged.sort((a, b) => (b.at || 0) - (a.at || 0)).slice(0, 30);
    if (m === 'replace') history = (obj.history || []).slice(0, 30);
  }

  // 现场类数据：位置 / 坐向 / 外煞勾选 / 报告草稿
  // replace 直接覆盖；merge 时本机已有就保留本机，避免把「当前现场」改成旧备份的
  const extras = {};
  Object.keys(EXTRA).forEach((name) => {
    if (!obj[name]) return;
    const curVal = store.read(EXTRA[name], null);
    extras[name] = (m === 'merge' && curVal) ? curVal : obj[name];
  });

  // 事务式提交：先排好全部写入目标，逐段写；任一段失败则整体回滚到写前快照
  const pairs = [
    { key: 'yj_settings', value: settings },
    { key: 'yj_profiles', value: profiles },
    { key: 'yj_floorplans', value: plans.slice(0, 20) },
    { key: 'yj_remedy_tasks', value: tasks },
    { key: 'yj_history', value: history }
  ];
  Object.keys(extras).forEach((name) => pairs.push({ key: EXTRA[name], value: extras[name] }));

  const snap = {
    yj_settings: cur.settings,
    yj_profiles: cur.profiles,
    yj_floorplans: cur.floorplans,
    yj_remedy_tasks: cur.remedyTasks,
    yj_history: cur.history
  };
  Object.keys(EXTRA).forEach((name) => { snap[EXTRA[name]] = store.read(EXTRA[name], null); });

  const failed = [];
  pairs.forEach((p) => {
    if (!store.write(p.key, p.value)) failed.push(p.key);
  });

  if (failed.length) {
    // 回滚：写回快照；原本不存在的键直接删掉，不留空壳
    pairs.forEach((p) => {
      const before = snap[p.key];
      if (before === undefined || before === null) store.remove(p.key);
      else store.write(p.key, before);
    });
    return {
      error: `写入失败（${failed.length} 段），已回滚到恢复前的数据`,
      failed,
      mode: m
    };
  }

  return {
    mode: m,
    members: (profiles.members || []).length + (profiles.owner ? 1 : 0),
    floorplans: plans.length,
    remedyTasks: tasks.length,
    history: history.length,
    place: extras.place ? 1 : 0,
    orientation: extras.orientation ? 1 : 0,
    shaCheck: extras.shaCheck && Array.isArray(extras.shaCheck.checked) ? extras.shaCheck.checked.length : 0
  };
}

/* ---------- 撤销点：恢复前自动留一份，7 天内可退回 ---------- */

const UNDO_KEY = 'yj_backup_undo';
const UNDO_TTL = 7 * 24 * 60 * 60 * 1000;

/* ---------- 恢复日志：谁在什么时候动过本机数据 ---------- */

const LOG_KEY = 'yj_restore_log';
const LOG_LIMIT = 20;

function getLog() {
  const list = store.read(LOG_KEY, []);
  if (!Array.isArray(list)) return [];
  return list.filter((x) => x && x.at);
}

function pushLog(entry) {
  const list = getLog();
  list.unshift(Object.assign({ id: 'rl_' + Date.now(), at: Date.now() }, entry));
  store.write(LOG_KEY, list.slice(0, LOG_LIMIT));
}

function clearLog() {
  store.remove(LOG_KEY);
}

/** 读取撤销点；超过 7 天标记 expired，不改数据 */
function getUndo() {
  const u = store.read(UNDO_KEY, null);
  if (!u || !u.data) return null;
  const age = Math.max(0, Date.now() - (u.at || 0));
  return {
    at: u.at,
    atText: u.at ? new Date(u.at).toLocaleString() : '未知时间',
    mode: u.mode === 'replace' ? 'replace' : 'merge',
    age,
    expired: age > UNDO_TTL,
    summary: summaryOf(u.data)
  };
}

/**
 * 恢复（带撤销点）：先留一份当前数据，再执行提交。
 * 提交失败（已回滚）时不写撤销点。
 */
function apply(obj, mode) {
  const m = mode === 'replace' ? 'replace' : 'merge';
  const before = collect();
  const res = commit(obj, m);
  if (!res.error) {
    store.write(UNDO_KEY, { at: Date.now(), mode: m, data: before });
    pushLog({ action: 'apply', mode: m, ok: true, members: res.members, floorplans: res.floorplans, remedyTasks: res.remedyTasks, history: res.history, place: res.place, shaCheck: res.shaCheck });
  } else {
    pushLog({ action: 'apply', mode: m, ok: false, error: res.error, failed: res.failed });
  }
  return res;
}

/**
 * 撤销上一次恢复：用撤销点整体覆盖当前数据，并把「撤销后的状态」写成新的撤销点，
 * 于是可以来回切；超过 7 天则清掉撤销点并报错。
 */
function restoreUndo() {
  const u = getUndo();
  if (!u) return { error: '没有可撤销的恢复记录' };
  if (u.expired) {
    store.remove(UNDO_KEY);
    pushLog({ action: 'undo', ok: false, error: '撤销点已超过 7 天' });
    return { error: '撤销点已超过 7 天，已清除' };
  }
  const raw = store.read(UNDO_KEY, null);
  if (!raw || !raw.data) return { error: '撤销点内容已损坏' };
  const nowState = collect();
  const res = commit(raw.data, 'replace');
  if (res.error) {
    pushLog({ action: 'undo', ok: false, error: res.error, failed: res.failed });
    return res;
  }
  store.write(UNDO_KEY, { at: Date.now(), mode: u.mode, data: nowState });
  pushLog({ action: 'undo', ok: true, members: res.members, floorplans: res.floorplans, remedyTasks: res.remedyTasks, history: res.history });
  return Object.assign({ restored: true }, res);
}

/* ---------- 云开发（可选，需用户自行开通环境） ---------- */

function cloudAvailable() {
  try {
    return typeof wx !== 'undefined' && wx.cloud && typeof wx.cloud.database === 'function';
  } catch (e) {
    return false;
  }
}

function cloudInit(env) {
  if (!cloudAvailable()) return { error: '未开通云开发' };
  try {
    wx.cloud.init({ env: env || undefined, traceUser: true });
    return { ok: true };
  } catch (e) {
    return { error: '云开发初始化失败：' + (e && e.message ? e.message : '未知错误') };
  }
}

function cloudSave() {
  if (!cloudAvailable()) return Promise.reject(new Error('未开通云开发'));
  const db = wx.cloud.database();
  const payload = collect();
  return db.collection('luopan_backup').add({
    data: Object.assign({}, payload, { _openidOwn: true, createdAt: Date.now() })
  });
}

function cloudLoad() {
  if (!cloudAvailable()) return Promise.reject(new Error('未开通云开发'));
  const db = wx.cloud.database();
  return db.collection('luopan_backup').orderBy('at', 'desc').limit(1).get()
    .then((res) => (res.data && res.data[0]) || null);
}

module.exports = {
  BACKUP_VERSION,
  UNDO_KEY,
  UNDO_TTL,
  LOG_KEY,
  LOG_LIMIT,
  collect,
  serialize,
  parse,
  summaryOf,
  diff,
  getLog,
  clearLog,
  getUndo,
  apply,
  restoreUndo,
  cloudAvailable,
  cloudInit,
  cloudSave,
  cloudLoad
};
