/**
 * pages/vip/index.js
 * 权益说明页（替代 iOS 的 VIPPaywallSheet / StoreKitIAPManager / sanHeVIPPreviewCard）
 * 小程序禁止 iOS 内购与虚拟支付，故本版不做付费墙：把 iOS 会员权益逐条列出并声明全部开放。
 */

const store = require('../../utils/store');
const nav = require('../../utils/nav');

const BENEFITS = [
  { name: '玄空飞星全盘', ios: '含替卦、三般卦、七星打劫、流年月叠加', now: '已开放，无需解锁' },
  { name: '紫白九星逐宫化解', ios: '年/月星同盘 + 组合煞 + 逐宫化解', now: '已开放' },
  { name: '三合水法原诀', ios: '黄泉歌、八煞歌、十二长生出处', now: '已开放' },
  { name: '奇门时家指南', ios: '八门断语 + 最利方位「背孤击虚」', now: '已开放' },
  { name: '家人配房', ios: '会员专属（FamilyRoomAllocation resolve 有门禁）', now: '已开放，需先填家庭档案' },
  { name: '天机长卷深盘', ios: '十三章汇总 + 评分与处置清单 + 高清导出', now: '已开放，导出含宣纸底纹与朱印' },
  { name: '多宅存档', ios: '会员可存多套户型', now: '已开放，上限 20 套' },
  { name: '实体罗盘 / 快捷指令', ios: 'StoreKit 商品与系统快捷指令', now: '不适用（小程序无内购与快捷指令）' }
];

Page({
  data: {
    benefits: BENEFITS,
    version: '',
    cloudEnv: ''
  },

  onLoad() {
    const s = store.getSettings() || {};
    this.setData({ version: 'v1.0', cloudEnv: s.cloudEnv || '' });
  },

  goBackup() {
    nav.go('/pages/backup/index');
  },

  goRemedy() {
    nav.go('/pages/remedy/index');
  },

  onClear() {
    wx.showModal({
      title: '清除本机数据？',
      content: '将删除家人档案、化解任务、户型存档、浏览历史与设置，操作不可撤销。建议先到「备份与恢复」导出备份。',
      confirmText: '先备份',
      cancelText: '仍要清除',
      success: (r) => {
        if (r.confirm) {
          this.goBackup();
          return;
        }
        store.clearAll();
        wx.showToast({ title: '已清除', icon: 'success' });
        setTimeout(() => nav.back(), 800);
      }
    });
  },

  back() { nav.back(); }
});
