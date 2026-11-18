/**
 * compass-layer.js
 * 罗盘图层流派预设管理器，1:1 移植自 iOS Models/CompassLayerManager.swift。
 *
 * 核心：activePreset 不是持久化的“上次应用预设”，而是依据 8 个图层开关
 * 实时反推当前实际生效的流派（手动切换单层后也能正确反映）。
 */

// iOS 8 个判定图层 → 小程序 layerConfig 的 key
// showDegreeTicks/showSolarTerms/showHexagrams64/showFenjin120/
// showMountain24/showEightGua/showTrueNorthNeedle/showLevelBubble
const LAYER_KEYS = [
  'degreeTicks', 'solarRing', 'hex64', 'fenjin',
  'mountains', 'palaces', 'trueNorthNeedle', 'bubbleLevel'
];

// iOS CompassPreset.allCases 顺序，activePreset 按此顺序取第一个命中
const PRESETS = [
  {
    key: 'comprehensive', name: '综合全息盘',
    layers: { degreeTicks: true, solarRing: true, hex64: true, fenjin: true, mountains: true, palaces: true, trueNorthNeedle: true, bubbleLevel: true }
  },
  {
    key: 'sanYuan', name: '三元玄空盘',
    layers: { degreeTicks: true, solarRing: false, hex64: true, fenjin: true, mountains: true, palaces: true, trueNorthNeedle: true, bubbleLevel: true }
  },
  {
    key: 'sanHe', name: '三合水法盘',
    layers: { degreeTicks: true, solarRing: true, hex64: false, fenjin: true, mountains: true, palaces: true, trueNorthNeedle: true, bubbleLevel: true }
  },
  {
    key: 'minimalist', name: '极简勘测盘',
    layers: { degreeTicks: true, solarRing: false, hex64: false, fenjin: false, mountains: true, palaces: true, trueNorthNeedle: true, bubbleLevel: true }
  }
];

/** applyPreset：返回该预设下 iOS 8 个图层的目标值（其它图层保持不变） */
function presetLayers(presetKey) {
  const p = PRESETS.filter((x) => x.key === presetKey)[0];
  return p ? Object.assign({}, p.layers) : null;
}

/** activePreset：从当前图层开关反推生效预设（iOS CompassLayerManager.activePreset） */
function activePreset(config) {
  const cfg = config || {};
  const hit = PRESETS.filter((p) => LAYER_KEYS.every((k) => !!cfg[k] === p.layers[k]))[0];
  return hit ? hit.key : null;
}

function activePresetName(config) {
  const key = activePreset(config);
  if (key) return PRESETS.filter((p) => p.key === key)[0].name;
  return '自定义盘';
}

/** 把预设叠加到现有配置上，仅覆盖 iOS 判定的 8 个图层 */
function applyTo(config, presetKey) {
  const layers = presetLayers(presetKey);
  if (!layers) return Object.assign({}, config || {});
  return Object.assign({}, config || {}, layers);
}

module.exports = { LAYER_KEYS, PRESETS, presetLayers, activePreset, activePresetName, applyTo };
