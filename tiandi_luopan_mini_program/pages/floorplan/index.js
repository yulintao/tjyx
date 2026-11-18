const FP = require('../../utils/floorplan');
const RF = require('../../utils/roomfit');
const XK = require('../../utils/xuankong');
const SF = require('../../utils/sitface');
const store = require('../../utils/store');
const nav = require('../../utils/nav');
const orientation = require('../../utils/orientation');
const SFIND = require('../../utils/spatial-findings');
const BZ = require('../../utils/bazhai');

const TYPES = ['主卧', '卧室', '客厅', '厨房', '卫生间', '书房', '储物', '餐厅'];

Page({
  data: {
    sitIdx: 0,
    sit: '子',
    face: '午',
    mountainNames: SF.MOUNTAINS_24.map((m) => `${m} 山`),
    orientationLabel: '',
    orientationHint: '',
    concSitFace: '',
    concArea: '',
    concAudit: '',
    concMissing: '',
    concPlan: '',
    concPivot: '',
    spatialFindings: [],
    spatialItems: [],
    spatialScore: 92,
    roomDetail: null,
    showRoomDetail: false,
    pkRows: [],
    pkHint: '',
    showDetail: false,
    rooms: [],
    summary: [],
    counts: null,
    area: 0,
    areaSqm: 0,
    widthMeters: '12',
    centroidText: '',
    coverage: [],
    show3D: false,
    bgImage: '',
    plans: [],
    selected: -1,
    types: TYPES,
    has3D: false,

    // 缺角专项
    missingAudits: [],
    missingCount: 0,
    // 中宫立极拖拽
    dragPivot: false,
    hasPivot: false,
    pivotText: '',
    pivotStyle: 'left:50%;top:50%;',
    // 罗盘叠透
    showOverlay: false,
    overlayMarks: [],
    overlayRot: 0,
    overlayLineStyle: '',
    overlayOpacity: 0.55,

    // 家人配房（对齐 iOS FamilyRoomAllocationEngine）
    roomPlan: null,
    planMode: 'suggested',
    planRows: [],
    planReviews: [],
    planUnassigned: [],
    planHint: '',

    // 户型模板（替代 RoomPlan 扫描的效率层）
    templates: [],
    tmplIdx: 0,
    // 3D 体块旋转
    isoRot: 0,
    isoZoom: 1,

    // 门窗开口（手工录入，替代 iOS RoomPlan 扫出的 opening）
    openings: [],
    openingRows: [],
    openingRoomIdx: 0,
    openingRoomNames: [],
    openingSideIdx: 0,
    openingSides: ['北（上）', '东（右）', '南（下）', '西（左）'],
    openingSideKeys: ['north', 'east', 'south', 'west'],
    openingTypeIdx: 0,
    openingTypes: ['门', '窗'],
    doorHint: '',
    openingCountText: ''
  },

  onLoad(options) {
    let sit = '子';
    if (options && options.sit && SF.MOUNTAINS_24.indexOf(options.sit) >= 0) sit = options.sit;
    else sit = orientation.current().sit;
    this.setData({
      sitIdx: SF.MOUNTAINS_24.indexOf(sit),
      plans: store.getFloorplans().map((p) => ({ id: p.id, label: p.label, at: p.at })),
      templates: FP.templateList().map((t) => `${t.label}（${t.count} 间）`)
    });
    this.recompute(FP.sampleRooms());
  },

  // tabBar 页：一次性参数优先，其次读全局方位源，
  // 户型九宫归宫、缺角与配房都随当前坐山动态重算。
  onShow() {
    const pending = nav.take('/pages/floorplan/index');
    let sit = null;
    if (pending && pending.sit && SF.MOUNTAINS_24.indexOf(pending.sit) >= 0) sit = pending.sit;
    if (pending && sit) orientation.applyPending(sit, null);
    if (!sit) sit = orientation.current().sit;
    const orient = orientation.display();
    if (sit && SF.MOUNTAINS_24.indexOf(sit) !== this.data.sitIdx) {
      this.setData({ sitIdx: SF.MOUNTAINS_24.indexOf(sit) });
      this.recompute(this._rooms || FP.sampleRooms());
    } else if (orient.label !== this.data.orientationLabel) {
      this.setData({ orientationLabel: orient.label, orientationHint: orient.hint });
    }
    this.refreshPK();
  },

  onSitChange(e) {
    const sitIdx = parseInt(e.detail.value, 10);
    this.setData({ sitIdx });
    orientation.fromManual(SF.MOUNTAINS_24[sitIdx]);
    const bar = this.selectComponent && this.selectComponent('ctx-bar');
    if (bar && bar.refresh) bar.refresh();
    this.recompute(this._rooms || FP.sampleRooms());
  },

  recompute(rooms) {
    this._rooms = rooms;
    const sit = SF.MOUNTAINS_24[this.data.sitIdx];
    const face = SF.opposite(sit);
    const period = XK.periodForYear(new Date().getFullYear());
    const chart = XK.calculateChart({ sitMountain: sit, faceMountain: face, period });
    const audit = FP.audit(rooms, chart);
    this._lastAudit = audit;
    const coverage = FP.coverageByPalace(rooms);
    const centroid = FP.centroidOf(rooms);
    const sqm = FP.areaSqm(rooms, this.data.widthMeters);
    const missingAudits = FP.missingCornerAudits(rooms);
    const missingList = missingAudits.filter((m) => m.status === 'missing');

    const viewRooms = audit.rooms.map((r, i) => ({
      ...r,
      idx: i,
      style: `left:${rooms[i].x}%;top:${rooms[i].y}%;width:${rooms[i].w}%;height:${rooms[i].h}%;`
    }));

    // 家人配房：家庭档案有出生年才计算，否则给提示
    let plan = null;
    const planRows = [];
    const planReviews = [];
    const planUnassigned = [];
    let planHint = '';
    try {
      const profiles = store.getProfiles() || {};
      const people = RF.peopleOf(profiles);
      if (people.length) {
        plan = RF.resolve(rooms, profiles, this._manualAssign || null);
        const assignedFor = (pid) => (plan.recommendations || []).filter((x) => x.personID === pid);
        plan.people.forEach((p) => {
          const recs = assignedFor(p.id);
          const bed = recs.filter((x) => x.use === 'bedroom')[0];
          const study = recs.filter((x) => x.use === 'study')[0];
          planRows.push({
            id: p.id,
            name: p.name,
            gua: `${p.gua.name}命（${p.gua.num}）`,
            bed: bed ? `${bed.roomName} · ${bed.place}宫 · ${bed.star}（${bed.rank}分）` : '无吉星卧房',
            bedOk: !!bed,
            study: study ? `${study.roomName} · ${study.place}宫 · ${study.star}（${study.rank}分）` : '无吉星书房',
            studyOk: !!study
          });
        });
        plan.reviews.forEach((r) => {
          planReviews.push(`${r.personName} → ${r.roomName}（${r.place}宫·${r.star}）：${r.reason}`);
        });
        plan.unassigned.forEach((p) => planUnassigned.push(p.name));
        // 房间叠人名牌
        viewRooms.forEach((vr, i) => {
          const rid = rooms[i] && rooms[i].id ? rooms[i].id : `r${i}`;
          vr.people = (plan.labels && plan.labels[rid]) || '';
        });
      } else {
        planHint = '尚未设置家庭资料（本人或成员的出生年），设置后可自动推荐每人宜住的卧房与书房。';
      }
    } catch (e) {
      console.warn('roomfit error:', e);
      planHint = '配房计算失败，请检查家庭资料中的出生年与性别。';
    }
    if (plan && planUnassigned.length) {
      planHint = `${planUnassigned.join('、')} 暂无吉星卧房可配，建议以八宅「伏位 / 延年」房为主，或依化解清单柔化凶星。`;
    }

    const extra = [];
    if (missingList.length) {
      extra.push(`量化缺角：${missingList.map((c) => `${c.name}（覆盖 ${Math.round(c.ratio * 100)}%）`).join('、')}，覆盖率低于 40%，主该方人气不聚。`);
    }
    const pivot = this._pivot || centroid;
    const px = pivot.x;
    const py = pivot.y;
    const centered = px > 33.34 && px < 66.66 && py > 33.34 && py < 66.66;
    const pivotNote = this._pivot
      ? `中宫立极取手工定点 (${px.toFixed(1)}, ${py.toFixed(1)})${centered ? '，落于中宫，气尚居中。' : '，已偏离中宫，立极须以宅心为准。'}`
      : `中宫立极落于面积重心 (${px.toFixed(1)}, ${py.toFixed(1)})${centered ? '，居中之气尚正。' : '，重心偏侧，立极宜以重心校正。'}`;
    extra.push(pivotNote);

    // 罗盘叠透标记（上北下南：北向上，顺时针即方位角顺时针）
    const overlayMarks = [];
    const order = [
      { palace: 1, name: '坎', dir: '北', az: 0 },
      { palace: 8, name: '艮', dir: '东北', az: 45 },
      { palace: 3, name: '震', dir: '东', az: 90 },
      { palace: 4, name: '巽', dir: '东南', az: 135 },
      { palace: 9, name: '离', dir: '南', az: 180 },
      { palace: 2, name: '坤', dir: '西南', az: 225 },
      { palace: 7, name: '兑', dir: '西', az: 270 },
      { palace: 6, name: '乾', dir: '西北', az: 315 }
    ];
    const rr = 36;
    order.forEach((o) => {
      const rad = o.az * Math.PI / 180;
      const lx = 50 + rr * Math.sin(rad);
      const ly = 50 - rr * Math.cos(rad);
      const missingHere = missingAudits.some((m) => m.palace === o.palace && m.status === 'missing');
      overlayMarks.push({
        palace: o.palace,
        label: `${o.name}·${o.dir}`,
        missing: missingHere,
        style: `left:${lx.toFixed(2)}%;top:${ly.toFixed(2)}%;`,
        color: missingHere ? '#e88b8b' : '#e9d8a6'
      });
    });
    const sitAz = SF.MOUNTAINS_24.indexOf(sit) * 15;
    const overlayRot = sitAz - 90;
    const overlayLineStyle = `transform:rotate(${overlayRot}deg);`;
    const orient = orientation.display();
    const counts = audit.levelCount || { ji: 0, ping: 0, xiong: 0 };

    // 门窗开口：手工录入即视为已采集；入户门可反推坐向（前提：图上方为北）
    const sites = FP.openingSites(this.data.openings, rooms);
    const openingRows = sites.map((s, i) => ({
      key: s.key,
      idx: i,
      text: `${s.typeText}｜${s.roomName} ${s.sideText}侧 · ${s.palaceName}宫（${s.dir}）`,
      isDoor: s.type === 'door'
    }));
    const doorFace = FP.facingFromDoor(this.data.openings, rooms);
    const doorHint = doorFace ? doorFace.note : '尚未录入入户门；录一扇「门」后可按其朝外法线反推坐向。';
    const openSum = FP.openingSummary(FP.normalizeOpenings(this.data.openings, rooms));
    const openingDots = FP.normalizeOpenings(this.data.openings, rooms).map((o, i) => {
      const site = FP.openingSites([o], [rooms[o.room]])[0];
      return {
        key: `${i}-${o.room}-${o.side}`,
        isDoor: o.type === 'door',
        glyph: o.type === 'door' ? '门' : '窗',
        len: Math.max(16, Math.round((o.width || 0.3) * 100)),
        style: `left:${site.x}%;top:${site.y}%;`
      };
    });

    // iOS computeSpatialFengshuiFindings：由户型平面几何自动判煞（水火冲等）
    const spatialPlan = { rooms, widthMeters: this.data.widthMeters, aspectRatio: null };
    const spatialFindings = SFIND.computeSpatialFindings(spatialPlan)
      .map((t) => ({ text: t, warn: t.indexOf('⚠️') === 0 }));
    const spatialAudit = SFIND.analyzeSpatialHouse2D(spatialPlan);

    this.setData({
      sit,
      face,
      orientationLabel: orient.label,
      orientationHint: orient.hint,
      concSitFace: `${sit}山${face}向 · ${rooms.length} 间房`,
      concArea: `${sqm} ㎡ · 图形占比 ${audit.area}`,
      concAudit: `吉 ${counts.ji} / 平 ${counts.ping} / 凶 ${counts.xiong}`,
      concMissing: missingList.length
        ? `${missingList.length} 处缺角：${missingList.map((c) => `${c.name} ${c.percent}%`).join('、')}`
        : '九宫完整，无缺角',
      concPlan: planHint || (planRows.length ? `${planRows.length} 人已配房 · ${plan.mode === 'manual' ? '手定' : '系统推荐'}` : ''),
      concPivot: centered ? '立极居中，气尚正' : '立极偏侧，宜以宅心校正',
      spatialFindings,
      spatialItems: spatialAudit.items,
      spatialScore: spatialAudit.score,
      rooms: viewRooms,
      summary: extra.concat(audit.summary),
      counts: audit.levelCount,
      area: audit.area,
      areaSqm: sqm,
      centroidText: `(${centroid.x.toFixed(1)}, ${centroid.y.toFixed(1)})`,
      pivotText: `(${px.toFixed(1)}, ${py.toFixed(1)})`,
      pivotStyle: `left:${px.toFixed(2)}%;top:${py.toFixed(2)}%;`,
      hasPivot: !!this._pivot,
      coverage,
      missingAudits,
      missingCount: missingList.length,
      overlayMarks,
      overlayRot,
      overlayLineStyle,
      has3D: true,
      roomPlan: plan ? { mode: plan.mode, peopleCount: plan.people.length } : null,
      planMode: plan ? plan.mode : 'suggested',
      planRows,
      planReviews,
      planUnassigned,
      planHint,
      openingRows,
      openingDots,
      openingRoomNames: rooms.map((r, i) => `${i + 1}. ${r.name}`),
      doorHint,
      openingCountText: openSum.total ? `门 ${openSum.doors} · 窗 ${openSum.windows}` : '未录入'
    });
    if (this.data.show3D) this.drawIso();
  },

  onWidth(e) {
    this.setData({ widthMeters: e.detail.value });
    this.recompute(this._rooms);
  },

  // ============ 门窗开口 ============
  onOpeningRoom(e) {
    this.setData({ openingRoomIdx: Number(e.detail.value) || 0 });
  },

  onOpeningSide(e) {
    this.setData({ openingSideIdx: Number(e.detail.value) || 0 });
  },

  onOpeningType(e) {
    this.setData({ openingTypeIdx: Number(e.detail.value) || 0 });
  },

  addOpening() {
    const rooms = this._rooms || [];
    if (!rooms.length) {
      wx.showToast({ title: '先录入房间', icon: 'none' });
      return;
    }
    const room = Math.min(this.data.openingRoomIdx, rooms.length - 1);
    const side = this.data.openingSideKeys[this.data.openingSideIdx] || 'south';
    const type = this.data.openingTypeIdx === 1 ? 'window' : 'door';
    const list = (this.data.openings || []).concat([{ room, side, type, pos: 0.35, width: 0.3 }]);
    this.setData({ openings: FP.normalizeOpenings(list, rooms) });
    this.recompute(rooms);
  },

  removeOpening(e) {
    const idx = Number(e.currentTarget.dataset.idx);
    const list = (this.data.openings || []).filter((o, i) => i !== idx);
    this.setData({ openings: FP.normalizeOpenings(list, this._rooms || []) });
    this.recompute(this._rooms || []);
  },

  /** 按入户门朝外法线反推坐向（图上方为北为前提，结果可再用手动坐向覆盖） */
  applyDoorFacing() {
    const rooms = this._rooms || [];
    const res = FP.facingFromDoor(this.data.openings, rooms);
    if (!res) {
      wx.showToast({ title: '先录一扇门', icon: 'none' });
      return;
    }
    const sitIdx = Math.max(0, SF.MOUNTAINS_24.indexOf(res.sit));
    this.setData({ sitIdx });
    orientation.fromManual(res.sit);
    this.recompute(rooms);
    wx.showModal({
      title: '已按入户门判向',
      content: `${res.note}\n\n如与罗盘实测不符，请直接改顶部「坐山」。`,
      showCancel: false
    });
  },

  clearOpenings() {
    this.setData({ openings: [] });
    this.recompute(this._rooms || []);
    wx.showToast({ title: '已清空门窗', icon: 'none' });
  },

  // ============ 房间拖动 ============
  onRoomTouchStart(e) {
    const idx = parseInt(e.currentTarget.dataset.idx, 10);
    const room = this._rooms && this._rooms[idx];
    const t = e.touches && e.touches[0];
    if (!room || !t) return;
    this._roomDrag = { idx, sx: t.clientX, sy: t.clientY, x0: room.x, y0: room.y, moved: false };
    this._dragRoom = null;
    // 每次按下重新量一次户型框：页面滚动、横竖屏切换后宽度可能变
    this.measurePlanBox();
  },

  onRoomTouchMove(e) {
    const d = this._roomDrag;
    const t = e.touches && e.touches[0];
    const rect = this._planRect;
    if (!d || !t) return;
    if (!rect || !rect.width || !rect.height) {
      this.measurePlanBox();
      return;
    }
    const dxPx = t.clientX - d.sx;
    const dyPx = t.clientY - d.sy;
    // 8px 以内视为点按，不触发移动，避免误触让房间跳走
    if (!d.moved && Math.sqrt(dxPx * dxPx + dyPx * dyPx) < 8) return;
    d.moved = true;
    const x = d.x0 + (dxPx / rect.width) * 100;
    const y = d.y0 + (dyPx / rect.height) * 100;
    const next = FP.moveRoom(this._rooms[d.idx], x, y);
    if (!next) return;
    this._dragRoom = next;
    // 拖动过程只改这一间的定位，不跑整盘重算，保证跟手
    this.setData({
      [`rooms[${d.idx}].style`]: `left:${next.x}%;top:${next.y}%;width:${next.w}%;height:${next.h}%;`
    });
  },

  onRoomTouchEnd() {
    const d = this._roomDrag;
    this._roomDrag = null;
    if (!d || !d.moved || !this._dragRoom) return;
    const rooms = this._rooms.slice();
    rooms[d.idx] = this._dragRoom;
    this._dragRoom = null;
    // 拖动结束后系统可能再派发一次 tap，用时间戳吃掉它（比布尔标记安全，不会误吞后续点击）
    this._dragEndAt = Date.now();
    this.recompute(rooms);
  },

  onRoomTap(e) {
    if (this._dragEndAt && Date.now() - this._dragEndAt < 300) return;
    const idx = parseInt(e.currentTarget.dataset.idx, 10);
    const room = this._rooms[idx];
    if (!room) return;
    // iOS RoomAuditDetailSheet：点房间先看该房间风水体检，再决定改用途/尺寸/删除
    const audited = (this._lastAudit && this._lastAudit.rooms || []).filter((r) => r.name === (room.name || room.type))[0];
    this.setData({
      showRoomDetail: true,
      roomDetail: Object.assign({}, room, {
        idx,
        audit: audited || null,
        areaText: audited ? `${(room.w * room.h * Math.pow(Number(this.data.widthMeters) / 100, 2)).toFixed(1)} ㎡` : ''
      })
    });
  },

  closeRoomDetail() {
    this.setData({ showRoomDetail: false, roomDetail: null });
  },

  noop() {},

  editRoomFromDetail() {
    const rd = this.data.roomDetail;
    if (!rd) return;
    this.closeRoomDetail();
    const idx = rd.idx;
    const room = this._rooms[idx];
    if (!room) return;
    wx.showActionSheet({
      itemList: ['改用途', '宽度 +5', '宽度 -5', '进深 +5', '进深 -5', '删除房间'],
      success: (res) => {
        const rooms = this._rooms.slice();
        if (res.tapIndex === 5) {
          rooms.splice(idx, 1);
          this.recompute(rooms);
          return;
        }
        if (res.tapIndex === 0) {
          wx.showActionSheet({
            itemList: TYPES,
            success: (r2) => {
              const next = this._rooms.slice();
              next[idx] = Object.assign({}, room, { type: TYPES[r2.tapIndex], name: TYPES[r2.tapIndex] });
              this.recompute(next);
            }
          });
          return;
        }
        const delta = res.tapIndex === 1 || res.tapIndex === 3 ? 5 : -5;
        const key = res.tapIndex === 1 || res.tapIndex === 2 ? 'w' : 'h';
        const room2 = rooms[idx];
        const max = 100 - (key === 'w' ? room2.x : room2.y);
        const val = Math.max(6, Math.min(max, room2[key] + delta));
        rooms[idx] = Object.assign({}, room2, { [key]: val });
        this.recompute(rooms);
      }
    });
  },

  addRoom() {
    const rooms = (this._rooms || []).slice();
    rooms.push({ name: '新房间', type: '卧室', x: 40, y: 40, w: 16, h: 16 });
    this.recompute(rooms);
    wx.showToast({ title: '已在宅心附近新建，点选可调', icon: 'none' });
  },

  chooseImage() {
    wx.chooseMedia({
      count: 1,
      mediaType: ['image'],
      success: (res) => {
        const path = res.tempFiles[0].tempFilePath;
        this.setData({ bgImage: path });
      }
    });
  },

  clearImage() {
    this.setData({ bgImage: '' });
  },

  toggle3D() {
    const show3D = !this.data.show3D;
    this.setData({ show3D });
    if (show3D) setTimeout(() => this.drawIso(), 80);
  },

  /** 模板库：一键铺底，再逐间微调（替代无扫描能力时的录入成本） */
  onTemplate(e) {
    const idx = parseInt(e.detail.value, 10) || 0;
    const key = FP.templateList()[idx].key;
    const t = FP.templateRooms(key);
    if (!t) return;
    this.setData({ tmplIdx: idx, widthMeters: t.widthMeters, bgImage: this.data.bgImage });
    this.recompute(t.rooms);
    wx.showToast({ title: `已载入${t.label}`, icon: 'none' });
  },

  /** 3D 拖动旋转：横向拖动改朝向，纵向拖动改俯仰（用缩放近似） */
  onIsoTouchStart(e) {
    const t = e.touches && e.touches[0];
    if (!t) return;
    this._isoStart = { x: t.clientX, y: t.clientY, rot: this.data.isoRot, zoom: this.data.isoZoom };
  },

  onIsoTouchMove(e) {
    const t = e.touches && e.touches[0];
    if (!t || !this._isoStart) return;
    const dx = t.clientX - this._isoStart.x;
    const dy = t.clientY - this._isoStart.y;
    const rot = (this._isoStart.rot + dx * 0.6) % 360;
    const zoom = Math.min(1.6, Math.max(0.7, this._isoStart.zoom - dy * 0.001));
    this.setData({ isoRot: rot, isoZoom: zoom });
    if (!this._isoTimer) {
      this._isoTimer = setTimeout(() => {
        this._isoTimer = null;
        this.drawIso();
      }, 40);
    }
  },

  onIsoTouchEnd() {
    this._isoStart = null;
  },

  resetIso() {
    this.setData({ isoRot: 0, isoZoom: 1 });
    this.drawIso();
  },

  drawIso() {
    const rooms = this._rooms || [];
    const blocks = FP.isoBlocks(rooms, { rotDeg: this.data.isoRot || 0 });
    const q = wx.createSelectorQuery().in(this);
    q.select('#isoCanvas').fields({ node: true, size: true }).exec((res) => {
      const item = res && res[0];
      if (!item || !item.node) return;
      const canvas = item.node;
      const ctx = canvas.getContext('2d');
      const dpr = wx.getSystemInfoSync().pixelRatio || 2;
      const W = item.width;
      const H = item.height;
      canvas.width = W * dpr;
      canvas.height = H * dpr;
      ctx.scale(dpr, dpr);
      ctx.clearRect(0, 0, W, H);

      // 计算投影边界并适配画布
      let minX = Infinity; let maxX = -Infinity; let minY = Infinity; let maxY = -Infinity;
      blocks.forEach((b) => {
        b.top.concat(b.south, b.east).forEach((p) => {
          if (p.x < minX) minX = p.x;
          if (p.x > maxX) maxX = p.x;
          if (p.y < minY) minY = p.y;
          if (p.y > maxY) maxY = p.y;
        });
      });
      const pad = 16;
      const fitScale = Math.min((W - pad * 2) / (maxX - minX || 1), (H - pad * 2) / (maxY - minY || 1));
      const zoom = this.data.isoZoom || 1;
      const scale = fitScale * zoom;
      // 缩放以画布中心为基准，避免放大后贴边被裁
      const cxW = W / 2;
      const cyH = H / 2;
      const ox = cxW - ((minX + maxX) / 2) * scale;
      const oy = cyH - ((minY + maxY) / 2) * scale;
      const tx = (p) => p.x * scale + ox;
      const ty = (p) => p.y * scale + oy;

      ctx.font = '12px sans-serif';
      blocks.forEach((b, i) => {
        // 四面侧墙按深度排序绘制（近处后画，遮住远处）
        const faces = b.faces || [
          { poly: b.south, shade: ['#2b3a55', '#33445f', '#3c4e6b', '#2f4059'][i % 4] },
          { poly: b.east, shade: 'rgba(120,145,190,0.55)' }
        ];
        faces.forEach((f, fi) => {
          ctx.beginPath();
          f.poly.forEach((p, k) => (k ? ctx.lineTo(tx(p), ty(p)) : ctx.moveTo(tx(p), ty(p))));
          ctx.closePath();
          ctx.fillStyle = f.shade || ['#2b3a55', '#33445f', '#3c4e6b', '#2f4059'][(i + fi) % 4];
          ctx.fill();
          ctx.strokeStyle = 'rgba(160,180,215,0.35)';
          ctx.stroke();
        });
        // 顶面
        ctx.beginPath();
        b.top.forEach((p, k) => (k ? ctx.lineTo(tx(p), ty(p)) : ctx.moveTo(tx(p), ty(p))));
        ctx.closePath();
        ctx.fillStyle = b.type === '主卧' || b.type === '客厅' ? '#e9d8a6' : '#cfd8ea';
        ctx.globalAlpha = 0.92;
        ctx.fill();
        ctx.globalAlpha = 1;
        ctx.stroke();
        // 名称
        const cx = b.top.reduce((s, p) => s + tx(p), 0) / 4;
        const cy = b.top.reduce((s, p) => s + ty(p), 0) / 4;
        ctx.fillStyle = '#1a1f2b';
        ctx.textAlign = 'center';
        ctx.fillText(b.name, cx, cy + 4);
      });

      ctx.fillStyle = '#8f9bb3';
      ctx.textAlign = 'left';
      ctx.fillText(`等轴测示意 · 旋转 ${Math.round(this.data.isoRot || 0)}° / 缩放 ${(zoom * 100).toFixed(0)}%（体块高度按功能设定，非真实层高）`, 10, H - 10);
    });
  },

  savePlan() {
    const rooms = this._rooms || [];
    const sit = SF.MOUNTAINS_24[this.data.sitIdx];
    const label = `${sit}山${SF.opposite(sit)}向 · ${rooms.length} 间 · ${this.data.areaSqm}㎡`;
    const plan = {
      id: 'fp_' + Date.now(),
      label,
      sit,
      widthMeters: this.data.widthMeters,
      rooms,
      openings: this.data.openings || [],
      at: Date.now()
    };
    const list = store.saveFloorplan(plan);
    this.setData({ plans: list.map((p) => ({ id: p.id, label: p.label, at: p.at })) });
    wx.showToast({ title: '已存档', icon: 'success' });
  },

  loadPlan() {
    const list = store.getFloorplans();
    if (!list.length) {
      wx.showToast({ title: '暂无存档', icon: 'none' });
      return;
    }
    wx.showActionSheet({
      itemList: list.slice(0, 6).map((p) => p.label),
      success: (res) => {
        const plan = list[res.tapIndex];
        if (!plan) return;
        const sitIdx = Math.max(0, SF.MOUNTAINS_24.indexOf(plan.sit));
        this.setData({ widthMeters: plan.widthMeters || '12', sitIdx, openings: plan.openings || [] });
        this.recompute(plan.rooms || FP.sampleRooms());
        wx.showToast({ title: '已载入', icon: 'success' });
      }
    });
  },

  deletePlan() {
    const list = store.getFloorplans();
    if (!list.length) {
      wx.showToast({ title: '暂无存档', icon: 'none' });
      return;
    }
    wx.showActionSheet({
      itemList: list.slice(0, 6).map((p) => '删除：' + p.label),
      success: (res) => {
        const plan = list[res.tapIndex];
        if (!plan) return;
        const rest = store.removeFloorplan(plan.id);
        this.setData({ plans: rest.map((p) => ({ id: p.id, label: p.label, at: p.at })) });
        wx.showToast({ title: '已删除', icon: 'none' });
      }
    });
  },

  resetSample() {
    this.setData({ bgImage: '', openings: [] });
    this._pivot = null;
    this._rooms = null;
    this.recompute(FP.sampleRooms());
  },

  // ============ 中宫立极点拖拽 ============
  toggleDragPivot() {
    const on = !this.data.dragPivot;
    this.setData({ dragPivot: on });
    if (on) this.measurePlanBox();
    wx.showToast({ title: on ? '拖动盘心可改立极点' : '已退出立极拖动', icon: 'none' });
  },

  measurePlanBox() {
    wx.createSelectorQuery().in(this).select('#planBox').boundingClientRect((rect) => {
      if (rect) this._planRect = rect;
    }).exec();
  },

  onPlanTouchStart(e) {
    if (!this.data.dragPivot) return;
    if (!this._planRect) this.measurePlanBox();
    this._dragFrom(e);
  },

  onPlanTouchMove(e) {
    if (!this.data.dragPivot) return;
    this._dragFrom(e);
  },

  _dragFrom(e) {
    const t = (e.touches && e.touches[0]) || (e.changedTouches && e.changedTouches[0]);
    const rect = this._planRect;
    if (!t || !rect) return;
    const x = Math.max(0, Math.min(100, ((t.clientX - rect.left) / rect.width) * 100));
    const y = Math.max(0, Math.min(100, ((t.clientY - rect.top) / rect.height) * 100));
    this._pivot = { x, y };
    this.setData({
      hasPivot: true,
      pivotText: `(${x.toFixed(1)}, ${y.toFixed(1)})`,
      pivotStyle: `left:${x.toFixed(2)}%;top:${y.toFixed(2)}%;`
    });
  },

  resetPivot() {
    this._pivot = null;
    this.setData({ hasPivot: false, dragPivot: false });
    this.recompute(this._rooms || FP.sampleRooms());
    wx.showToast({ title: '已回到面积重心', icon: 'none' });
  },

  // ============ 罗盘叠透 ============
  toggleOverlay() {
    this.setData({ showOverlay: !this.data.showOverlay });
  },

  // ============ 宅谱导入导出 / DXF ============
  currentPlan() {
    const rooms = this._rooms || [];
    const sit = SF.MOUNTAINS_24[this.data.sitIdx];
    return {
      label: `${sit}山${SF.opposite(sit)}向 · ${rooms.length} 间 · ${this.data.areaSqm}㎡`,
      sit,
      face: SF.opposite(sit),
      widthMeters: this.data.widthMeters,
      pivot: this._pivot || null,
      openings: this.data.openings || [],
      rooms
    };
  },

  _writeAndShare(name, content) {
    const fs = wx.getFileSystemManager();
    const path = `${wx.env.USER_DATA_PATH}/${name}`;
    try {
      fs.writeFileSync(path, content, 'utf8');
    } catch (err) {
      wx.showModal({ title: '写入失败', content: String(err && err.errMsg ? err.errMsg : err), showCancel: false });
      return;
    }
    const fallbackCopy = () => {
      wx.setClipboardData({
        data: content,
        success: () => wx.showToast({ title: '已复制到剪贴板', icon: 'none' })
      });
    };
    if (typeof wx.shareFileMessage === 'function') {
      wx.shareFileMessage({
        filePath: path,
        fileName: name,
        success: () => {},
        fail: () => fallbackCopy()
      });
    } else {
      fallbackCopy();
    }
  },

  exportJSON() {
    const plan = this.currentPlan();
    const text = FP.planToJSON(plan);
    this._writeAndShare(`宅谱_${plan.sit}山${plan.face}向_${Date.now()}.json`, text);
  },

  exportDXF() {
    const plan = this.currentPlan();
    const text = FP.toDXF(plan.rooms, {
      widthMeters: plan.widthMeters, sit: plan.sit, face: plan.face, openings: plan.openings
    });
    this._writeAndShare(`宅谱_${plan.sit}山${plan.face}向_${Date.now()}.dxf`, text);
  },

  importJSON() {
    const fs = wx.getFileSystemManager();
    wx.chooseMessageFile({
      count: 1,
      type: 'file',
      extension: ['json'],
      success: (res) => {
        const f = res.tempFiles && res.tempFiles[0];
        if (!f) return;
        let text = '';
        try {
          text = fs.readFileSync(f.path, 'utf8');
        } catch (err) {
          wx.showToast({ title: '读取失败', icon: 'none' });
          return;
        }
        const plan = FP.parsePlanJSON(text);
        if (plan.error) {
          wx.showModal({ title: '导入失败', content: plan.error, showCancel: false });
          return;
        }
        let sitIdx = SF.MOUNTAINS_24.indexOf(plan.sit);
        if (sitIdx < 0) sitIdx = this.data.sitIdx;
        this._pivot = plan.pivot || null;
        this.setData({ widthMeters: plan.widthMeters, sitIdx, openings: plan.openings || [] });
        this.recompute(plan.rooms);
        wx.showToast({ title: '已导入宅谱', icon: 'success' });
      },
      fail: () => {
        // 退而求其次：从剪贴板粘贴 JSON
        wx.getClipboardData({
          success: (r) => {
            const plan = FP.parsePlanJSON(r.data);
            if (plan.error) {
              wx.showModal({
                title: '未选择文件',
                content: '导入需选择聊天文件中的 .json 宅谱；也可先把宅谱内容复制到剪贴板再试。',
                showCancel: false
              });
              return;
            }
            this._pivot = plan.pivot || null;
            let sitIdx = SF.MOUNTAINS_24.indexOf(plan.sit);
            if (sitIdx < 0) sitIdx = this.data.sitIdx;
            this.setData({ widthMeters: plan.widthMeters, sitIdx, openings: plan.openings || [] });
            this.recompute(plan.rooms);
            wx.showToast({ title: '已从剪贴板导入', icon: 'success' });
          },
          fail: () => wx.showToast({ title: '导入已取消', icon: 'none' })
        });
      }
    });
  },

  /** 生成空间测绘报告：把当前户型写入草稿，跳报告页出长图 */
  goReport() {
    const plan = this.currentPlan();
    plan.id = 'fp_' + Date.now();
    plan.at = Date.now();
    store.write('yj_report_draft', plan);
    nav.go('/pages/report/index');
  },

  back() { nav.back(); },
  toggleDetail() { this.setData({ showDetail: !this.data.showDetail }); },

  /** 多房源 PK 评分（iOS evaluatePKMetric）：对已存档户型 + 当前户型横向打分 */
  refreshPK() {
    const list = store.getFloorplans() || [];
    if (!list.length) {
      this.setData({ pkRows: [], pkHint: '保存两套以上户型后，可在此横向对比综合评分。' });
      return;
    }
    // 宅主命卦：有出生年才判定匹配，否则不参与加减分（iOS personalAccess 口径）
    let kuaMatch = null;
    try {
      const profiles = store.getProfiles() || {};
      const self = (profiles.members || []).filter((m) => m.role === '本人')[0] || profiles.owner;
      if (self && self.birthYear) {
        const sit = SF.MOUNTAINS_24[this.data.sitIdx];
        const houseGua = SF.houseGuaName(sit);
        const lifeGua = BZ.lifeGua(parseInt(self.birthYear, 10), self.gender || 'male');
        kuaMatch = BZ.compatibility(houseGua, lifeGua.num).same;
      }
    } catch (e) {}

    const curSit = SF.MOUNTAINS_24[this.data.sitIdx];
    const period = XK.periodForYear(new Date().getFullYear());
    const rows = list.slice(0, 8).map((p) => {
      const sit = p.sit || curSit;
      const face = SF.opposite(sit);
      const chart = XK.calculateChart({ sitMountain: sit, faceMountain: face, period });
      const m = FP.evaluatePKMetric(p.rooms || [], chart, { kuaMatch });
      return {
        label: p.label || '未命名',
        sit,
        score: m.score,
        level: m.level,
        formula: m.formula,
        match: kuaMatch === null ? '未设宅主' : (kuaMatch ? '命卦相配' : '命卦不合')
      };
    }).sort((a, b) => b.score - a.score);

    // 当前未存档户型也加入对比
    const curChart = XK.calculateChart({ sitMountain: curSit, faceMountain: SF.opposite(curSit), period });
    const curMetric = FP.evaluatePKMetric(this._rooms || [], curChart, { kuaMatch });
    rows.unshift({
      label: '当前户型（未存档）', sit: curSit,
      score: curMetric.score, level: curMetric.level,
      formula: curMetric.formula,
      match: kuaMatch === null ? '未设宅主' : (kuaMatch ? '命卦相配' : '命卦不合')
    });
    this.setData({
      pkRows: rows,
      pkHint: kuaMatch === null ? '未设置宅主出生年，命卦匹配项暂不计分。' : '命卦匹配项已计入评分。'
    });
  },

  onShareAppMessage() {
    return {
      title: '演象时空罗盘 · 户型九宫',
      path: '/pages/floorplan/index?sit=' + this.data.sit
    };
  },

  /** 朋友圈分享：与好友分享区分，朋友圈侧只带标题与页面路径 */
  onShareTimeline() {
    return { title: '户型九宫 · 缺角审计与家人配房' };
  },
});
