/**
 * 云函数 almanac-notify —— 节气 / 换月 / 吉日 / 冲煞 定时下发
 *
 * 设计：算法只在客户端跑（与本项目 utils 同源），客户端把未来提醒写入
 * luopan_notify_plan 集合；本云函数按定时触发器扫描「已到期且未发送」的条目，
 * 调 subscribeMessage.send 下发后标记 sent。这样云函数不需要复制历法算法，
 * 也就不会出现两端口径不一致。
 *
 * 部署步骤：
 *  1. 开发者工具开通云开发，新建集合 luopan_notify_plan（权限：仅创建者可读写）
 *  2. 上传本目录为云函数 almanac-notify，运行时 Nodejs16.13
 *  3. 右键「上传并部署：云端安装依赖」，触发器会随 config.json 一起创建
 *  4. 公众平台「订阅消息」申请模板（节气提醒 / 吉日提醒），把模板 ID 填进小程序提醒中心
 *  5. 模板字段需与下方 data 的 key 对应（thing1 事件、time2 日期、thing3 提示）
 */

const cloud = require('wx-server-sdk');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });

const db = cloud.database();

const FIELD_MAP = {
  // 模板关键词 → 数据来源，按你申请的模板实际字段调整
  thing1: 'title',
  time2: 'date',
  thing3: 'detail'
};

async function sendOne(doc) {
  const data = {};
  Object.keys(FIELD_MAP).forEach((k) => {
    const v = String(doc[FIELD_MAP[k]] || '—');
    data[k] = { value: v.length > 20 ? `${v.slice(0, 19)}…` : v };
  });
  await cloud.openapi.subscribeMessage.send({
    touser: doc.openid,
    templateId: doc.tmplId,
    page: 'pages/notify/index',
    data,
    miniprogramState: doc.miniprogramState || 'formal'
  });
}

exports.main = async () => {
  const now = Date.now();
  let sent = 0;
  let failed = 0;

  // 每次最多处理 100 条，避免超时
  const res = await db.collection('luopan_notify_plan')
    .where({ sent: false, dueAt: db.command.lte(now) })
    .limit(100)
    .get();

  for (const doc of res.data) {
    try {
      await sendOne(doc);
      await db.collection('luopan_notify_plan').doc(doc._id).update({
        data: { sent: true, sentAt: now }
      });
      sent += 1;
    } catch (e) {
      failed += 1;
      await db.collection('luopan_notify_plan').doc(doc._id).update({
        data: { lastError: String((e && e.errMsg) || e), triedAt: now }
      });
    }
  }

  return { ok: true, scanned: res.data.length, sent, failed };
};
