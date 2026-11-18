/**
 * check-components.js — WXML 自定义标签/组件声明静态检查
 * 用法：node scripts/check-components.js
 *
 * 为什么需要它：
 *   WXML 里出现 `<br>`、`<div>`、`<p>` 这类 HTML 标签时，小程序会把它当成**自定义组件**去解析，
 *   找不到声明就退化成 `wx://not-found`，控制台报
 *   `Component is not found in path "wx://not-found"`，页面渲染中断。
 *   这类问题 `node --check` 查不出（wxml 不是 JS），所以单独校验一遍：
 *     1) 收集每个页面/组件 wxml 里用到的标签；
 *     2) 与内置标签表、该目录 json 的 usingComponents 比对；
 *     3) 声明了但目标 .js/.wxml 缺失的也算错误；
 *     4) 顺带做标签开闭配平（跳过注释、属性里的引号内容与自闭合标签）。
 */

const fs = require('fs');
const path = require('path');

// 无需闭合标签：仅 import/include/wxs 这类指令式标签（image/input 等在小程序里通常仍写闭合或自闭合）
const VOID = new Set(['import', 'include', 'wxs']);

const ROOT = path.join(__dirname, '..');

// 小程序内置组件（WebView 渲染层）
const BUILTIN = new Set([
  'view', 'scroll-view', 'swiper', 'swiper-item', 'movable-area', 'movable-view', 'cover-view', 'cover-image',
  'icon', 'text', 'rich-text', 'progress', 'button', 'checkbox', 'checkbox-group', 'form', 'input', 'label',
  'picker', 'picker-view', 'picker-view-column', 'radio', 'radio-group', 'slider', 'switch', 'textarea', 'navigator',
  'functional-page-navigator', 'audio', 'image', 'video', 'camera', 'live-player', 'live-pusher', 'map', 'canvas',
  'web-view', 'ad', 'ad-custom', 'official-account', 'open-data', 'block', 'template', 'slot', 'wxs', 'import', 'include',
  'page-meta', 'navigation-bar', 'match-media', 'page-container', 'share-element', 'keyboard-accessory', 'editor',
  'voip-room', 'root-portal', 'sticky-header', 'sticky-section', 'grid-view', 'list-view', 'snapshot',
  'channel-live', 'channel-video', 'store-product', 'store-home', 'store-member-card', 'inline-payment-panel',
  'aria-component'
]);

// 全局 app.json 的 usingComponents 对所有页面生效，先读进来做兜底
let GLOBAL_DECLARED = {};
try {
  const app = JSON.parse(fs.readFileSync(path.join(ROOT, 'app.json'), 'utf8'));
  GLOBAL_DECLARED = app.usingComponents || {};
} catch (e) {
  GLOBAL_DECLARED = {};
}

const problems = [];

function scanDir(dir, kind) {
  if (!fs.existsSync(dir)) return;
  fs.readdirSync(dir, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .forEach((d) => {
      const base = path.join(dir, d.name);
      // 兼容两种命名：pages/x/index.wxml、components/x/x.wxml
      const wxml = [path.join(base, 'index.wxml'), path.join(base, d.name + '.wxml')].filter((p) => fs.existsSync(p))[0];
      if (!wxml) return;

      // 0) 每个页面必须有自己的 index.json：
      //    在 lazyCodeLoading: requiredComponents 下，缺页面配置会报
      //    `Component is not found in path "wx://not-found"`，
      //    同时控制台可能出现 `Page "xxx" has not been registered yet`。
      if (kind === 'pages' && !fs.existsSync(path.join(base, 'index.json'))) {
        problems.push(`pages/${d.name}: 缺少 index.json（会导致 wx://not-found）`);
      }

      let declared = {};
      const jsonCandidates = [path.join(base, 'index.json'), path.join(base, d.name + '.json')];
      const jsonPath = jsonCandidates.find((p) => fs.existsSync(p));
      if (jsonPath) {
        try {
          const cfg = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
          declared = cfg.usingComponents || {};
        } catch (e) {
          problems.push(`${kind}/${d.name}: json 解析失败 → ${e.message}`);
        }
      }

      const txt = fs.readFileSync(wxml, 'utf8');
      const tags = new Set();
      const re = /<([a-zA-Z][\w-]*)/g;
      let m;
      while ((m = re.exec(txt))) tags.add(m[1]);

      tags.forEach((t) => {
        if (BUILTIN.has(t)) return;
        const rel = declared[t] || GLOBAL_DECLARED[t];
        if (!rel) {
          problems.push(`${kind}/${d.name}: 使用了未声明的标签 <${t}>（会被解析为 wx://not-found）`);
          return;
        }
        const target = rel.charAt(0) === '/' ? path.join(ROOT, rel.slice(1)) : path.resolve(base, rel);
        if (!fs.existsSync(target + '.js') || !fs.existsSync(target + '.wxml')) {
          problems.push(`${kind}/${d.name}: 组件 <${t}> 声明为 ${rel}，但目标文件缺失`);
        }
      });

      // 4) 标签配平
      const badTags = checkBalance(txt);
      if (badTags.length) problems.push(`${kind}/${d.name}: 标签未闭合 → ${badTags.join('、')}`);
    });
}

/** 简易标签栈校验：跳过注释与属性引号内容，返回未闭合/多余闭合的标签名 */
function checkBalance(src) {
  const text = src.replace(/<!--[\s\S]*?-->/g, '');
  const stack = [];
  const errors = [];
  let i = 0;
  while (i < text.length) {
    const lt = text.indexOf('<', i);
    if (lt < 0) break;
    // 找标签结束的 '>'，跳过引号内的内容
    let j = lt + 1;
    let quote = '';
    while (j < text.length) {
      const ch = text[j];
      if (quote) { if (ch === quote) quote = ''; }
      else if (ch === '"' || ch === "'") quote = ch;
      else if (ch === '>') break;
      j++;
    }
    if (j >= text.length) break;
    const raw = text.slice(lt, j + 1);
    if (raw.charAt(1) === '/') {
      const name = raw.slice(2, -1).trim();
      const top = stack.pop();
      if (!top) errors.push(`多余的 </${name}>`);
      else if (top !== name) errors.push(`</${name}> 与 <${top}> 交叉`);
    } else if (raw.charAt(1) !== '!' && raw.charAt(1) !== '?') {
      const name = (raw.match(/^<([a-zA-Z][\w-]*)/) || [])[1];
      const selfClose = /\/>$/.test(raw);
      if (name && !selfClose && !VOID.has(name)) stack.push(name);
    }
    i = j + 1;
  }
  stack.slice().reverse().forEach((t) => errors.push(`<${t}> 未闭合`));
  return errors;
}

scanDir(path.join(ROOT, 'pages'), 'pages');
scanDir(path.join(ROOT, 'components'), 'components');

if (problems.length) {
  problems.forEach((p) => console.log('  ✗ ' + p));
  console.log(`\n共 ${problems.length} 处组件声明问题。`);
  process.exit(1);
}
console.log('组件声明检查通过：未发现未声明或缺失的组件。');
