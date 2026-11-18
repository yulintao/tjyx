// utils/nav.js
// 统一的页面跳转封装。
// 背景：加了 tabBar 之后，tabBar 页面之间只能用 wx.switchTab 打开，
// 而 switchTab 不支持在 url 上带 query。所以这里的做法是：
//   1) 目标不是 tabBar 页 -> 老规矩 wx.navigateTo(url?query)
//   2) 目标是 tabBar 页   -> 参数先暂存到 app.globalData.tabParams，
//                            再 switchTab，目标页在 onShow 里用 take() 取走
// 调用方式统一为 nav.go('/pages/analysis/index', { sit: '子', heading: 180 })

const TAB_PAGES = [
  '/pages/index/index',
  '/pages/analysis/index',
  '/pages/zeri/index',
  '/pages/floorplan/index',
  '/pages/settings/index'
];

// 把 '../xxx/index'、'./index' 这类相对写法规范成 '/pages/xxx/index'
function norm(path) {
  if (!path) return '';
  let p = String(path).split('?')[0];
  if (p.charAt(0) !== '/') {
    p = p.replace(/^\.\.\//, '/pages/').replace(/^\.\//, '/pages/');
    if (p.charAt(0) !== '/') p = '/' + p;
  }
  return p;
}

function isTab(path) {
  return TAB_PAGES.indexOf(norm(path)) >= 0;
}

function toQuery(params) {
  if (!params) return '';
  const parts = [];
  Object.keys(params).forEach((k) => {
    const v = params[k];
    if (v === undefined || v === null || v === '') return;
    parts.push(k + '=' + encodeURIComponent(String(v)));
  });
  return parts.join('&');
}

function appInstance() {
  try {
    return getApp();
  } catch (e) {
    return null;
  }
}

function stash(path, params) {
  const app = appInstance();
  if (!app) return;
  app.globalData = app.globalData || {};
  app.globalData.tabParams = app.globalData.tabParams || {};
  app.globalData.tabParams[norm(path)] = params || null;
}

// 目标 tab 页在 onShow 里调用，取一次就删掉，避免重复应用旧参数
function take(path) {
  const app = appInstance();
  if (!app || !app.globalData || !app.globalData.tabParams) return null;
  const p = norm(path);
  const v = app.globalData.tabParams[p];
  if (v === undefined) return null;
  delete app.globalData.tabParams[p];
  return v || null;
}

function go(path, params) {
  const p = norm(path);
  if (!p) return;
  if (isTab(p)) {
    stash(p, params);
    // 记住来源 tab 页：tabBar 页之间是 switchTab，没有页面栈，
    // 返回时必须靠这条记录回到「刚才那个 tab」，否则只能掉回罗盘首页。
    const app = appInstance();
    const from = currentRoute();
    if (app && from && from !== p && isTab(from)) {
      app.globalData = app.globalData || {};
      app.globalData.tabFrom = from;
    }
    wx.switchTab({ url: p });
    return;
  }
  const qs = toQuery(params);
  wx.navigateTo({ url: p + (qs ? '?' + qs : '') });
}

/** 当前栈顶页面的绝对路由，如 '/pages/analysis/index' */
function currentRoute() {
  try {
    const stack = getCurrentPages() || [];
    const top = stack[stack.length - 1];
    if (top && top.route) return '/' + top.route;
  } catch (e) {
    return '';
  }
  return '';
}

// 返回上一页；已经在栈底（例如从盘解 switchTab 进入的 tabBar 页）就回到来源 tab，
// 没有来源再回罗盘首页，避免「点了没反应」或直接掉回首页。
function back() {
  let stack = [];
  try {
    stack = getCurrentPages() || [];
  } catch (e) {
    stack = [];
  }
  if (stack.length > 1) {
    wx.navigateBack({ delta: 1 });
    return;
  }
  const app = appInstance();
  const cur = currentRoute();
  let target = '';
  if (app && app.globalData && app.globalData.tabFrom) {
    target = app.globalData.tabFrom;
    delete app.globalData.tabFrom;
  }
  if (!target || target === cur || !isTab(target)) target = '/pages/index/index';
  wx.switchTab({ url: target });
}

module.exports = { TAB_PAGES, isTab, go, back, take, norm };
