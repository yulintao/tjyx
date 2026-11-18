/**
 * heading-lock.js
 * AR 读数稳持锁定：镜头在容差内停住一段时间就锁读数，转身超过阈值自动解锁。
 * 纯函数状态机，页面只持有 state，便于单测。
 */

const CFG = {
  stableMs: 1500,   // 停住多久算锁定
  tol: 1.2,         // 判定「稳」的角度容差
  drift: 12,        // 锁定后偏离多少度开始计时
  driftMs: 800,     // 偏离持续多久自动解锁
  release: 8        // 手动解锁后，需再转动多少度才允许重新锁定
};

function create() {
  return {
    last: null,        // 上一次参与判稳的角度
    stableSince: 0,    // 稳定起点
    locked: false,
    lockHeading: null, // 锁定角
    driftSince: 0,     // 偏离起点
    suppress: false,   // 手动解锁后压住自动锁定
    refHeading: null   // 手动解锁时的角度基准
  };
}

function delta(a, b) {
  return Math.abs(((a - b + 540) % 360) - 180);
}

/**
 * 推进一步
 * @param {object} state create() 的结果
 * @param {number} heading 当前方位角
 * @param {number} now 时间戳（毫秒）
 * @param {object} [cfg] 覆盖 CFG
 */
function step(state, heading, now, cfg) {
  const c = Object.assign({}, CFG, cfg || {});
  const st = Object.assign({}, state);
  const h = ((heading % 360) + 360) % 360;
  let justLocked = false;
  let justUnlocked = false;

  if (st.last === null) st.last = h;

  // 判稳
  if (delta(h, st.last) <= c.tol) {
    if (!st.stableSince) st.stableSince = now;
  } else {
    st.stableSince = now;
    st.last = h;
  }

  if (st.locked) {
    if (delta(h, st.lockHeading) > c.drift) {
      if (!st.driftSince) st.driftSince = now;
      if (now - st.driftSince >= c.driftMs) {
        st.locked = false;
        st.lockHeading = null;
        st.driftSince = 0;
        st.stableSince = now;
        justUnlocked = true;
      }
    } else {
      st.driftSince = 0;
    }
    return { state: st, justLocked, justUnlocked };
  }

  // 手动解锁后，等真正转头才恢复自动锁定
  if (st.suppress) {
    if (delta(h, st.refHeading === null ? h : st.refHeading) > c.release) {
      st.suppress = false;
      st.stableSince = now;
    } else {
      return { state: st, justLocked, justUnlocked };
    }
  }

  if (st.stableSince && now - st.stableSince >= c.stableMs) {
    st.locked = true;
    st.lockHeading = h;
    st.stableSince = 0;
    justLocked = true;
  }

  return { state: st, justLocked, justUnlocked };
}

/** 手动解锁 */
function unlock(state, heading) {
  const st = Object.assign({}, state);
  st.locked = false;
  st.lockHeading = null;
  st.driftSince = 0;
  st.refHeading = ((heading % 360) + 360) % 360;
  st.suppress = true;
  st.stableSince = 0;
  return st;
}

module.exports = { CFG, create, step, unlock, delta };
