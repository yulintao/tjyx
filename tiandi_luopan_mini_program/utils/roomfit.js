/**
 * roomfit.js
 * 家人配房引擎（对齐 iOS Models/FamilyRoomAllocation.swift 的 FamilyRoomAllocationEngine）
 *
 * 口径与 iOS 一致：
 *  - 主卧 / 次卧 / 卧室 → bedroom，书房 → study，其余房型（厨房、卫生间、客厅、储物、缺角）不可配人
 *  - 每间房按其几何中心归八宅宫位；含太极点（户型中心）的最小房间不参与排名
 *  - 每人按八宅命卦在该宫所得星排名：书房 伏位100 / 延年80 / 天医70 / 生气90，
 *    卧房 伏位80 / 延年100 / 天医95 / 生气75，凶星 0
 *  - 每人最多配一间卧房 + 一间书房，只取吉星（isRecommended），按 rank 降序、id 升序
 *  - 已分配到凶星的房间进「需复核」集合
 */

const BZ = require('./bazhai');
const FP = require('./floorplan');

// 洛书宫数 → 八宅宫名
const NUM_TO_PALACE = { 1: '坎', 2: '坤', 3: '震', 4: '巽', 6: '乾', 7: '兑', 8: '艮', 9: '离' };

// 房间类型 → 用途（null 表示不可配人）
const USE_BY_TYPE = {
  主卧: 'bedroom',
  次卧: 'bedroom',
  卧室: 'bedroom',
  书房: 'study'
};

const USE_LABEL = { bedroom: '卧房', study: '书房' };

// iOS 排名表
const RANK_TABLE = {
  study: { 伏: 100, 延: 80, 天: 70, 生: 90 },
  bedroom: { 伏: 80, 延: 100, 天: 95, 生: 75 }
};

const REASON_TEXT = {
  center: '位于太极点，无单一私向可判，不作吉凶排名',
  fitStudy: '吉星临位，宜作书房',
  fitRest: '吉星临位，宜作休憩',
  review: '已分配至凶星房间，建议复核'
};

function useOf(room) {
  return USE_BY_TYPE[room && room.type] || null;
}

/** 户型房间未带 id 时按序号补一个，保证配房结果可稳定引用 */
function withIds(rooms) {
  return (rooms || []).map((r, i) => (r && r.id ? r : Object.assign({}, r, { id: `r${i}` })));
}

function isAssignable(room) {
  if (!room || !useOf(room)) return false;
  return Number.isFinite(room.w) && Number.isFinite(room.h) && room.w > 0 && room.h > 0;
}

/** 房间几何中心（x 自西向东、y 自北向南，坐标 0–100） */
function centerOf(room) {
  return { x: room.x + room.w / 2, y: room.y + room.h / 2 };
}

/** 含太极点的最小房间（通常是中宫那间）不参与排名 */
function centralRoomId(rooms) {
  const hits = (rooms || []).filter((r) => {
    if (!isAssignable(r)) return false;
    const c = centerOf(r);
    const pal = FP.palaceOfPoint(c.x, c.y);
    return pal === 5;
  });
  if (!hits.length) return null;
  return hits
    .slice()
    .sort((a, b) => a.w * a.h - b.w * b.h)[0].id;
}

function palaceOfRoom(room, rooms) {
  if (!isAssignable(room)) return null;
  if (centralRoomId(rooms) === room.id) return null;
  const c = centerOf(room);
  const num = FP.palaceOfPoint(c.x, c.y);
  return NUM_TO_PALACE[num] || null;
}

/**
 * 单人 × 单房的匹配
 * @returns {{palace:string|null, starKey:string|null, star:string|null, type:string, rank:number, isRecommended:boolean, reasonKey:string, reason:string}}
 */
function fit(room, rooms, person) {
  const palace = palaceOfRoom(room, rooms);
  const use = useOf(room);
  let starKey = null;
  let star = null;
  let type = 'xiong';
  if (palace && person && person.gua) {
    const cell = BZ.roamStars(person.gua.num).cells.filter((c) => c.palace === palace)[0];
    if (cell) {
      starKey = cell.starKey;
      star = cell.star;
      type = cell.type;
    }
  }
  const offense = RANK_TABLE[use] || {};
  const rank = starKey && offense[starKey] ? offense[starKey] : 0;
  const isRecommended = type === 'ji';
  let reasonKey;
  if (!palace) reasonKey = 'center';
  else if (isRecommended) reasonKey = use === 'study' ? 'fitStudy' : 'fitRest';
  else reasonKey = 'review';
  return {
    palace,
    starKey,
    star,
    type,
    rank,
    isRecommended,
    reasonKey,
    reason: REASON_TEXT[reasonKey]
  };
}

/** 每间房对所有家人的匹配，按 rank 降序、id 升序 */
function fitsOfRoom(room, rooms, people) {
  const rs = withIds(rooms);
  const target = rs.filter((r) => r.id === room.id)[0] || room;
  return (people || [])
    .map((p) => Object.assign({ person: p }, fit(target, rs, p)))
    .sort((a, b) => (a.rank === b.rank ? String(a.person.id) < String(b.person.id) ? -1 : 1 : b.rank - a.rank));
}

/**
 * 推荐配房：每人一间卧房 + 一间书房，只挑吉星房
 * @returns {Array} [{personID, roomID, roomName, star, rank, use}]
 */
function recommend(rooms, people) {
  const rs = withIds(rooms);
  const out = [];
  (people || []).forEach((person) => {
    ['bedroom', 'study'].forEach((use) => {
      const candidates = rs
        .filter((r) => isAssignable(r) && useOf(r) === use)
        .map((r) => ({ room: r, f: fit(r, rs, person) }))
        .filter((x) => x.f.isRecommended)
        .sort((a, b) => (a.f.rank === b.f.rank ? (a.room.id < b.room.id ? -1 : 1) : b.f.rank - a.f.rank));
      if (candidates.length) {
        const best = candidates[0];
        out.push({
          personID: person.id,
          personName: person.name,
          roomID: best.room.id,
          roomName: best.room.name,
          place: best.f.palace,
          star: best.f.star,
          rank: best.f.rank,
          use,
          useLabel: USE_LABEL[use]
        });
      }
    });
  });
  return out;
}

function cleaned(assignments, rooms, people) {
  const rs = withIds(rooms);
  const personIDs = (people || []).map((p) => p.id);
  const occupied = {};
  return (assignments || []).filter((a) => {
    if (personIDs.indexOf(a.personID) < 0) return false;
    const room = rs.filter((r) => r.id === a.roomID)[0];
    if (!room || !isAssignable(room)) return false;
    const key = `${a.personID}:${useOf(room)}`;
    if (occupied[key]) return false;
    occupied[key] = true;
    return true;
  });
}

/** 已分配到凶星房的人房对 */
function reviewPairs(assignments, rooms, people) {
  const rs = withIds(rooms);
  const list = [];
  (assignments || []).forEach((a) => {
    const room = rs.filter((r) => r.id === a.roomID)[0];
    const person = (people || []).filter((p) => p.id === a.personID)[0];
    if (!room || !person) return;
    const f = fit(room, rs, person);
    if (!f.isRecommended) {
      list.push({
        personID: a.personID,
        personName: person.name,
        roomID: room.id,
        roomName: room.name,
        star: f.star,
        place: f.palace,
        reasonKey: f.reasonKey,
        reason: f.reason
      });
    }
  });
  return list;
}

function reviewRoomIDs(assignments, rooms, people) {
  return reviewPairs(assignments, rooms, people).map((x) => x.roomID);
}

/** 点选切换：同用途只保留一间，重复点则取消 */
function toggling(personID, roomID, assignments, rooms, people) {
  const rs = withIds(rooms);
  const result = cleaned(assignments, rs, people);
  const room = rs.filter((r) => r.id === roomID)[0];
  if (!room || !isAssignable(room)) return result;
  if (!(people || []).some((p) => p.id === personID)) return result;
  const wasAssigned = result.some((a) => a.personID === personID && a.roomID === roomID);
  const use = useOf(room);
  const kept = result.filter(
    (a) => !(a.personID === personID && (() => {
      const r2 = rs.filter((r) => r.id === a.roomID)[0];
      return r2 && useOf(r2) === use;
    })())
  );
  if (!wasAssigned) kept.push({ personID, roomID });
  return kept;
}

/** 房间 → 人名串 */
function labels(assignments, people) {
  const map = {};
  (assignments || []).forEach((a) => {
    const person = (people || []).filter((p) => p.id === a.personID)[0];
    if (!person) return;
    map[a.roomID] = map[a.roomID] ? `${map[a.roomID]}、${person.name}` : person.name;
  });
  return map;
}

/** 未分到卧房的人（iOS 会单列一条告警） */
function unassignedBedroom(assignments, rooms, people) {
  const rs = withIds(rooms);
  return (people || []).filter((person) => {
    const hit = (assignments || []).some((a) => {
      if (a.personID !== person.id) return false;
      const room = rs.filter((r) => r.id === a.roomID)[0];
      return room && useOf(room) === 'bedroom';
    });
    return !hit;
  });
}

/**
 * 完整方案：people 从家庭档案组装；有手动分配则沿用（清洗后），否则给推荐
 * @param {Array} rooms 户型房间
 * @param {object} profile store.getProfiles() 结果
 * @param {Array} manual 手动分配 [{personID, roomID}]
 */
function resolve(rooms, profile, manual) {
  const people = peopleOf(profile);
  if (manual && manual.length) {
    const cleanedList = cleaned(manual, rooms, people);
    return {
      people,
      assignments: cleanedList,
      mode: 'manual',
      reviews: reviewPairs(cleanedList, rooms, people),
      unassigned: unassignedBedroom(cleanedList, rooms, people),
      labels: labels(cleanedList, people)
    };
  }
  const rec = recommend(rooms, people);
  const assigned = rec.map((r) => ({ personID: r.personID, roomID: r.roomID }));
  return {
    people,
    assignments: assigned,
    recommendations: rec,
    mode: 'suggested',
    reviews: reviewPairs(assigned, rooms, people),
    unassigned: unassignedBedroom(assigned, rooms, people),
    labels: labels(assigned, people)
  };
}

/** 家庭档案 → 配房人员表（本人 + 成员，含命卦） */
function peopleOf(profile) {
  const p = profile || {};
  const list = [];
  const owner = p.owner;
  if (owner && owner.birthYear) {
    const gua = BZ.lifeGua(owner.birthYear, owner.gender || '男');
    list.push({ id: 'owner', name: owner.name || '本人', role: '本人', birthYear: owner.birthYear, gua });
  }
  (p.members || []).forEach((m, i) => {
    if (!m || !m.birthYear) return;
    const gua = BZ.lifeGua(m.birthYear, m.gender || '男');
    list.push({
      id: `family:${m.id || i}`,
      name: m.name || m.role || `成员${i + 1}`,
      role: m.role || '成员',
      birthYear: m.birthYear,
      gua
    });
  });
  return list;
}

module.exports = {
  NUM_TO_PALACE,
  USE_BY_TYPE,
  USE_LABEL,
  RANK_TABLE,
  REASON_TEXT,
  useOf,
  isAssignable,
  palaceOfRoom,
  centralRoomId,
  fit,
  fitsOfRoom,
  recommend,
  cleaned,
  reviewPairs,
  reviewRoomIDs,
  toggling,
  labels,
  unassignedBedroom,
  peopleOf,
  resolve
};
