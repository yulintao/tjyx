/**
 * check-handlers.js — 静态检查：wxml 里 bind/catch 绑定的方法名，是否都在对应 page 的 js 中定义
 * 用法：node scripts/check-handlers.js
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const PAGES = JSON.parse(fs.readFileSync(path.join(ROOT, 'app.json'), 'utf8')).pages;

let issues = 0;

PAGES.forEach((p) => {
  const wxmlPath = path.join(ROOT, p + '.wxml');
  const jsPath = path.join(ROOT, p + '.js');
  if (!fs.existsSync(wxmlPath) || !fs.existsSync(jsPath)) return;
  const wxml = fs.readFileSync(wxmlPath, 'utf8');
  const js = fs.readFileSync(jsPath, 'utf8');

  const handlers = [];
  const re = /(?:bind|catch)[:a-z]*\s*=\s*"([^"{}]+)"/g;
  let m;
  while ((m = re.exec(wxml))) {
    const name = m[1].trim();
    if (name && handlers.indexOf(name) < 0) handlers.push(name);
  }

  handlers.forEach((h) => {
    // 兼容 `name() {`、`name: function(`、`async name(`
    const defined = new RegExp('(^|[^\\w.])' + h.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\s*[(:]').test(js);
    if (!defined) {
      console.log(`  ✗ ${p}: wxml 绑定了 ${h}，js 未定义`);
      issues++;
    }
  });
});

console.log(issues ? `\n共 ${issues} 处未定义处理器` : '\n全部绑定处理器均已定义。');
process.exit(issues ? 1 : 0);
