/**
 * reminders.js
 * 提醒引擎：把 iOS 的节气 / 换月 / 吉日 / 冲煞四类系统通知，改为小程序端可落地的
 * 「提醒中心 + 订阅消息 + 桌面快捷方式」三层实现。
 *
 *  - 计算层（本文件）：给定日期与坐山，算出未来 N 天值得提醒的事件
 *  - 投递层：页面内的今日提醒卡（一定能到）；wx.requestSubscribeMessage（需模板 ID，用户授权后由云函数下发）
 *  - 兜底层：一键复制提醒到备忘录 / 添加到桌面快捷方式
 *
 * 与 iOS 的对应：setSolarTermNotifications / toggleAuspiciousDayReminder /
 * scheduleSolarTermNotificationPayload / refreshScheduledReminders 的通知内容口径。
 */

const ST = require('./solar-terms');
const ZR = require('./zeri');
const SF = require('./sitface');

// 节 vs 气：偶数索引为「节」，是换月点（立春/惊蛰/清明…），奇数索引为「气」
function isMonthChangingTerm(index) {
  return index % 2 === 0;
}

function fmt(d) {
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

function dayText(d) {
  return `${d.getMonth() + 1}月${d.getDate()}日`;
}

/**
 * 生成未来 days 天的提醒事件
 * @param {Date} from 起始日期（含当天）
 * @param {object} opts { days, sitMountain, ownerBirthYear }
 * @returns {Array} [{key,date,iso,type,typeLabel,title,detail,level}]
 */
function upcoming(from, opts) {
  const o = opts || {};
  const days = Math.max(1, Math.min(15, o.days || 7));
  const start = new Date(from || new Date());
  start.setHours(0, 0, 0, 0);
  const items = [];

  for (let i = 0; i < days; i++) {
    const d = new Date(start.getTime() + i * 86400000);
    const tp = ST.solarTermProgress(d);
    const iso = fmt(d);

    // 1) 节气当日：交节提醒（按真实交节时刻所在日期判断，避免跨零点误判）
    const midnight = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
    const endD = new Date(tp.end);
    const endMidnight = new Date(endD.getFullYear(), endD.getMonth(), endD.getDate()).getTime();
    const dayDiff = Math.round((endMidnight - midnight) / 86400000);
    const incomingIndex = (tp.index + 1) % 24;

    if (dayDiff === 0) {
      const hh = String(endD.getHours()).padStart(2, '0');
      const mm = String(endD.getMinutes()).padStart(2, '0');
      items.push({
        key: `term_${iso}`,
        date: iso,
        iso,
        type: 'term',
        typeLabel: '节气交节',
        title: `今日 ${tp.nextName} 交节（${hh}:${mm}）`,
        detail: `太阳视黄经到位，节气交接前后气场交替，宜静守，不宜开张、动土、搬迁大动作。`,
        level: 'notice',
        day: dayText(d)
      });
      // 2) 换月（节令换月）：进入的是「节」才换月
      if (isMonthChangingTerm(incomingIndex)) {
        items.push({
          key: `month_${iso}`,
          date: iso,
          iso,
          type: 'month',
          typeLabel: '换月',
          title: `今日交 ${tp.nextName}，月建换月`,
          detail: '月建更替，紫白流月与三煞方位同步改换；此前按旧月布置的化解宜复核一次。',
          level: 'warning',
          day: dayText(d)
        });
      }
    } else if (dayDiff === 1) {
      items.push({
        key: `term_next_${iso}`,
        date: iso,
        iso,
        type: 'term',
        typeLabel: '节气预告',
        title: `明日 ${tp.nextName}`,
        detail: `${tp.nextName} 将至，宜提前安排修造、搬迁与开市，避开交节当日。`,
        level: 'notice',
        day: dayText(d)
      });
    }

    // 3) 冲煞：岁破 / 月破 / 冲山
    try {
      const a = ZR.dayCourseAudit(d, o.sitMountain || null, { ownerBirthYear: o.ownerBirthYear });
      if (a.suiPo || a.yuePo || a.sittingClash) {
        const tags = [];
        if (a.suiPo) tags.push('岁破');
        if (a.yuePo) tags.push('月破');
        if (a.sittingClash) tags.push('冲山');
        items.push({
          key: `clash_${iso}`,
          date: iso,
          iso,
          type: 'clash',
          typeLabel: '冲煞',
          title: `${iso.slice(5)} ${tags.join(' / ')}`,
          detail: `${a.jianChu.name}日，${tags.join('、')}：${a.canGroundbreak ? '仍可择吉时小修' : '忌动土、起造、安门立向'}。${a.sittingTitle}。`,
          level: a.suiPo || a.sittingClash ? 'warning' : 'notice',
          day: dayText(d)
        });
      }
    } catch (e) {
      // 单日算错不影响整体
    }
  }

  // 4) 未来吉日：建除成开定满除且不冲坐山
  try {
    const list = ZR.upcomingAuspicious(start, o.sitMountain || null, 8);
    const horizon = new Date(start.getTime() + days * 86400000);
    list.forEach((g) => {
      const gd = new Date(g.iso.replace(/-/g, '/'));
      if (gd >= start && gd < horizon) {
        items.push({
          key: `good_${g.iso}`,
          date: g.iso,
          iso: g.iso,
          type: 'good',
          typeLabel: '吉日',
          title: `${g.date} ${g.jianChu}日 · ${g.dayPillar}`,
          detail: `宜：${g.yi}${o.sitMountain ? `（已按坐${o.sitMountain}山筛除冲山日）` : ''}`,
          level: 'good',
          day: dayText(gd)
        });
      }
    });
  } catch (e) {
    // ignore
  }

  items.sort((a, b) => (a.date === b.date ? 0 : a.date < b.date ? -1 : 1));
  return items;
}

/** 只要「今天」的提醒，用于首页/设置页的红点与横幅 */
function today(from, opts) {
  const iso = fmt(from || new Date());
  return upcoming(from, Object.assign({ days: 1 }, opts || {})).filter((x) => x.iso === iso);
}

/** 提醒文案导出（复制到备忘录或订阅消息正文） */
function toText(items) {
  const head = ['【演象时空罗盘 · 提醒】'];
  (items || []).forEach((x) => {
    head.push(`${x.day}【${x.typeLabel}】${x.title}`);
    head.push(`　${x.detail}`);
  });
  return head.join('\n');
}

/** 默认提醒偏好（写入 settings.reminders） */
const DEFAULT_PREFS = {
  term: true,
  month: true,
  clash: true,
  good: false,
  tmplIds: '',
  subscribedAt: 0,
  lastSyncAt: 0
};

function normalizePrefs(p) {
  return Object.assign({}, DEFAULT_PREFS, p || {});
}

/** 按偏好过滤 */
function filterByPrefs(items, prefs) {
  const p = normalizePrefs(prefs);
  return (items || []).filter((x) => {
    if (x.type === 'term') return p.term;
    if (x.type === 'month') return p.month;
    if (x.type === 'clash') return p.clash;
    if (x.type === 'good') return p.good;
    return true;
  });
}

/** 锁定坐山（与罗盘 settings.compassLock 同源） */
function lockedSit(settings) {
  const s = settings || {};
  const lock = s.compassLock || {};
  if (lock && lock.locked && typeof lock.heading === 'number') {
    const idx = Math.round((((lock.heading % 360) + 360) % 360) / 15) % 24;
    return SF.MOUNTAINS_24[idx];
  }
  return null;
}

module.exports = {
  DEFAULT_PREFS,
  isMonthChangingTerm,
  upcoming,
  today,
  toText,
  normalizePrefs,
  filterByPrefs,
  lockedSit
};
