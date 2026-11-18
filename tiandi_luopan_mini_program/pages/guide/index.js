const store = require('../../utils/store');
const nav = require('../../utils/nav');

const STEPS = [
  {
    title: '一、先把盘放平',
    body: '打开罗盘页，把手机水平持于胸前。画面上的「太极双轴水准仪气泡」居中即表示盘身水平；气泡偏出会直接影响二十四山的读数。',
    tip: '罗盘中「磁」字绿针指向磁北，「真」字金针指向真北，两者之差即当地磁偏角，由 GPS 与 WMM 本地计算。'
  },
  {
    title: '二、对准坐向',
    body: '点「🔄 盘随向转」，盘面会随手机朝向转动，红色十字天心线所指即当前向首。读数稳定后点「🔒 锁定」，盘面就固定下来便于察看。',
    tip: '若要立向记录，可先用「固定盘面」模式，再点二十四山环任一处，即弹出该山的坐向、分金与空亡诊断。'
  },
  {
    title: '三、看盘解与各派',
    body: '底部「盘解」页汇集玄空、八宅、紫白、三合、择日、奇门、户型、天机等模块。每一模块都会带上当前坐向，不需要重复输入。',
    tip: '玄空页可开「替卦」处理兼向，并叠加「流年月星」；三合与八宅页点宫位可看逐宫断语与化解。'
  },
  {
    title: '四、保存与分享',
    body: '所有推算都在手机本地完成，不上传。设置里的「家庭资料」可登记宅主与家人，用于择日冲本命与八宅分房；「分享海报」「今日日签」可存相册或转给朋友。',
    tip: '户型页支持手工录入房间、拖动中宫立极、罗盘叠透，以及宅谱 JSON / DXF 导出。'
  }
];

Page({
  data: {
    idx: 0,
    total: STEPS.length,
    step: STEPS[0],
    isLast: false
  },

  onLoad() {
    this.setData({ step: STEPS[0], total: STEPS.length, isLast: STEPS.length === 1 });
  },

  next() {
    const i = this.data.idx + 1;
    if (i >= STEPS.length) {
      this.finish();
      return;
    }
    this.setData({ idx: i, step: STEPS[i], isLast: i === STEPS.length - 1 });
  },

  prev() {
    const i = Math.max(0, this.data.idx - 1);
    this.setData({ idx: i, step: STEPS[i], isLast: i === STEPS.length - 1 });
  },

  skip() { this.finish(); },

  finish() {
    const s = store.getSettings() || {};
    s.guideSeen = true;
    store.saveSettings(s);
    wx.switchTab({
      url: '/pages/index/index',
      fail: () => nav.back()
    });
  },

  back() { nav.back(); },

  onShareAppMessage() {
    return { title: '演象时空罗盘 · 新手引导', path: '/pages/index/index' };
  }
});
