/**
 * scripts/check-assets.js
 * 校验 app.json 中引用的本地资源确实存在（tabBar 图标最容易漏）。
 * 用法：node scripts/check-assets.js
 */

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const app = JSON.parse(fs.readFileSync(path.join(ROOT, 'app.json'), 'utf8'));
const errors = [];
let checked = 0;

function must(file, where) {
  checked += 1;
  if (!file || typeof file !== 'string') {
    errors.push(`${where}：缺少路径`);
    return;
  }
  const abs = path.join(ROOT, file);
  if (!fs.existsSync(abs)) {
    errors.push(`${where}：文件不存在 ${file}`);
  }
}

(app.tabBar && app.tabBar.list ? app.tabBar.list : []).forEach((item, i) => {
  must(item.iconPath, `tabBar[${i}].iconPath`);
  must(item.selectedIconPath, `tabBar[${i}].selectedIconPath`);
});

if (app.tabBar && app.tabBar.custom) {
  errors.push('tabBar 使用自定义组件时需另行校验，当前脚本未覆盖');
}

console.log(`检查 ${checked} 个资源路径`);
if (errors.length) {
  errors.forEach((e) => console.error('✗ ' + e));
  process.exit(1);
}
console.log('资源引用检查通过。');
