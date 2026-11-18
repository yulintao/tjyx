/**
 * store.js
 * 本地持久化：档案、化解任务、户型、历史、设置
 * 统一版本号，避免结构升级后旧数据解析失败。
 */

const VERSION = 2;

/**
 * 本机所有持久化键（备份 / 清空 / 迁移都以这张表为准）
 * 新增 key 时必须同时登记，否则「备份整机」会漏、清空会残留。
 */
const KEYS = [
  'yj_profiles',
  'yj_remedy_tasks',
  'yj_floorplans',
  'yj_history',
  'yj_settings',
  'yj_place',
  'yj_current_orientation',
  'yj_sha_check',
  'yj_report_draft',
  'yj_backup_undo',
  'yj_restore_log'
];

// 单元测试与降级兼容：非小程序环境提供空实现
const api = typeof wx !== 'undefined' ? wx : {
  getStorageSync: () => '',
  setStorageSync: () => {},
  removeStorageSync: () => {}
};

function read(key, fallback) {
  try {
    const raw = api.getStorageSync(key);
    if (!raw) return fallback;
    const data = typeof raw === 'string' ? JSON.parse(raw) : raw;
    if (data && data.__v !== undefined && data.__v !== VERSION) {
      // 结构升级：保留可读字段，版本不符时回退默认，避免脏数据
      return fallback;
    }
    return data && data.data !== undefined ? data.data : fallback;
  } catch (e) {
    return fallback;
  }
}

function write(key, value) {
  try {
    api.setStorageSync(key, { __v: VERSION, data: value });
    return true;
  } catch (e) {
    return false;
  }
}

function remove(key) {
  try { api.removeStorageSync(key); } catch (e) {}
}

/* ---------- 家人档案 ---------- */
function getProfiles() {
  return read('yj_profiles', { owner: null, members: [] });
}

function saveProfiles(profiles) {
  return write('yj_profiles', profiles);
}

/* ---------- 化解任务 ---------- */
function getRemedyTasks() {
  return read('yj_remedy_tasks', []);
}

function toggleRemedyTask(task) {
  const list = getRemedyTasks();
  const idx = list.findIndex((t) => t.id === task.id);
  if (idx >= 0) {
    list[idx].done = !list[idx].done;
    list[idx].updatedAt = Date.now();
  } else {
    list.push({ ...task, done: false, createdAt: Date.now() });
  }
  write('yj_remedy_tasks', list);
  return list;
}

function removeRemedyTask(id) {
  const list = getRemedyTasks().filter((t) => t.id !== id);
  write('yj_remedy_tasks', list);
  return list;
}

/* ---------- 户型 ---------- */
function getFloorplans() {
  return read('yj_floorplans', []);
}

function saveFloorplan(plan) {
  const list = getFloorplans();
  const idx = list.findIndex((p) => p.id === plan.id);
  if (idx >= 0) list[idx] = plan;
  else list.unshift(plan);
  write('yj_floorplans', list.slice(0, 20));
  return list.slice(0, 20);
}

function removeFloorplan(id) {
  const list = getFloorplans().filter((p) => p.id !== id);
  write('yj_floorplans', list);
  return list;
}

/* ---------- 历史记录 ---------- */
function getHistory() {
  return read('yj_history', []);
}

function pushHistory(entry) {
  const list = getHistory();
  const rec = Object.assign({}, entry, { id: 'h_' + Date.now(), at: Date.now() });
  list.unshift(rec);
  write('yj_history', list.slice(0, 30));
  return list.slice(0, 30);
}

function clearHistory() {
  write('yj_history', []);
}

function removeHistory(id) {
  const list = getHistory().filter((h) => h.id !== id);
  write('yj_history', list);
  return list;
}

/** 自动留痕：同标题 10 分钟内只记一条，避免拨盘时刷屏 */
function track(entry) {
  const list = getHistory();
  const last = list[0];
  if (last && last.title === entry.title && Date.now() - last.at < 10 * 60 * 1000) {
    return list;
  }
  return pushHistory(entry);
}

/* ---------- 设置 ---------- */
function getSettings() {
  return read('yj_settings', {
    lang: 'zh-Hans', unit: 'metric', notify: false, showEvidence: false, guideSeen: false
  });
}

function saveSettings(s) {
  return write('yj_settings', s);
}

function clearAll() {
  KEYS.forEach(remove);
}

module.exports = {
  VERSION,
  KEYS,
  read,
  write,
  remove,
  getProfiles,
  saveProfiles,
  getRemedyTasks,
  toggleRemedyTask,
  removeRemedyTask,
  getFloorplans,
  saveFloorplan,
  removeFloorplan,
  getHistory,
  pushHistory,
  clearHistory,
  removeHistory,
  track,
  getSettings,
  saveSettings,
  clearAll,
  KEYS
};
