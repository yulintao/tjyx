// app.js
App({
  onLaunch() {
    console.log('演象时空罗盘小程序启动');
  },
  globalData: {
    systemInfo: null,
    // tabBar 页之间无法用 url 带参数，这里做一次性参数中转（见 utils/nav.js）
    tabParams: {}
  }
});
