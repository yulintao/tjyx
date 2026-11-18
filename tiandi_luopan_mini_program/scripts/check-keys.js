/**
 * scripts/check-keys.js
 * 校验代码里出现的 yj_* 存储键都登记在 store.KEYS 中。
 * 背景：新增存储键却忘了登记，备份会漏、清空会残留 —— 这类问题只能靠静态检查兜住。
 */

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const store = require(path.join(ROOT, 'utils', 'store'));
const REGISTERED = new Set(store.KEYS);

const KEY_RE = /['"]((?:yj)_[a-z0-9_]+)['"]/g;
const DIRS = ['utils', 'pages'];
const files = [];

DIRS.forEach((dir) => {
  const abs = path.join(ROOT, dir);
  (function walk(d) {
    fs.readdirSync(d).forEach((name) => {
      const p = path.join(d, name);
      const st = fs.statSync(p);
      if (st.isDirectory()) walk(p);
      else if (name.endsWith('.js')) files.push(p);
    });
  })(abs);
});

const used = new Map();
files.forEach((file) => {
  const text = fs.readFileSync(file, 'utf8');
  let m;
  while ((m = KEY_RE.exec(text)) !== null) {
    const key = m[1];
    if (!used.has(key)) used.set(key, path.relative(ROOT, file));
  }
});

const unknown = [];
used.forEach((file, key) => {
  if (!REGISTERED.has(key)) unknown.push(`${key}（${file}）`);
});
const unused = store.KEYS.filter((k) => !used.has(k));

console.log(`扫描 ${files.length} 个文件，发现 ${used.size} 个存储键，已登记 ${store.KEYS.length} 个`);

if (unused.length) console.log('未在代码中直接使用（可能由备份/迁移间接使用）：' + unused.join(', '));

if (unknown.length) {
  unknown.forEach((x) => console.error('✗ 未登记的存储键：' + x));
  console.error('请在 utils/store.js 的 KEYS 中登记，否则备份会漏、清空会残留。');
  process.exit(1);
}

console.log('存储键登记检查通过。');
