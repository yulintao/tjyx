const context = require('../../utils/context');
const nav = require('../../utils/nav');

Component({
  properties: {
    // 罗盘页本身已显示方位，传 true 可只留 位置 / 时令 / 生辰 三格，避免重复
    hideDir: {
      type: Boolean,
      value: false
    }
  },

  data: {
    sitFace: '',
    place: '',
    term: '',
    person: '',
    hasPlace: false,
    hasPerson: false,
    refreshing: false
  },

  lifetimes: {
    attached() {
      this.refresh();
    }
  },

  methods: {
    refresh() {
      const s = context.snapshot();
      this.setData({
        sitFace: s.sitFace,
        place: s.place,
        term: s.term,
        person: s.person,
        hasPlace: s.hasPlace,
        hasPerson: s.hasPerson
      });
    },

    /** 方位：回罗盘测向（tab 页，走 switchTab） */
    onDirTap() {
      nav.go('/pages/index/index');
    },

    /** 位置：点一下刷新坐标；长按可命名（如「自家客厅」） */
    onPlaceTap() {
      if (this.data.refreshing) return;
      this.setData({ refreshing: true });
      context.refreshPlace((p) => {
        this.setData({ refreshing: false });
        this.refresh();
        if (!p) wx.showToast({ title: '未取得定位，请在设置中授权', icon: 'none' });
      });
    },

    onPlaceName() {
      const self = this;
      wx.showModal({
        title: '给这个位置起个名',
        editable: true,
        placeholderText: '如：自家客厅 / 办公室',
        success: (res) => {
          if (!res.confirm) return;
          const name = String(res.content || '').trim();
          if (!name) return;
          context.namePlace(name);
          self.refresh();
          wx.showToast({ title: '已命名', icon: 'success' });
        }
      });
    },

    /** 时令：去择日看节气与日课 */
    onTermTap() {
      nav.go('/pages/zeri/index');
    },

    /** 生辰：去家庭资料补出生年与性别 */
    onPersonTap() {
      if (!this.data.hasPerson) {
        nav.go('/pages/family/index');
        wx.showToast({ title: '填出生年后可算本命卦', icon: 'none' });
        return;
      }
      nav.go('/pages/family/index');
    }
  }
});
