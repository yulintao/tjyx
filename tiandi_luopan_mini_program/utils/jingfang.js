/**
 * jingfang.js
 * 京房八宫：八宫卦序、世应、纳甲、六亲、六神
 * 依《京氏易传》传世规则：八纯卦为宫首，一至五世逐爻变，游魂再变四爻，归魂内卦三爻皆变。
 */

const { TRIGRAMS, byBinary } = require('./hexagram');

// 八宫（宫首纯卦）：键为宫名，值为该宫五行与宫首三爻结构
const GONG = [
  { name: '乾', elem: '金', bin: '111' },
  { name: '坎', elem: '水', bin: '010' },
  { name: '艮', elem: '土', bin: '001' },
  { name: '震', elem: '木', bin: '100' },
  { name: '巽', elem: '木', bin: '011' },
  { name: '离', elem: '火', bin: '101' },
  { name: '坤', elem: '土', bin: '000' },
  { name: '兑', elem: '金', bin: '110' }
];

// 八宫卦型：世爻 / 应爻（1=初爻 … 6=上爻）
const TYPES = [
  { key: 'ben', name: '本宫卦', shi: 6, ying: 3, mutate: [] },
  { key: 'i', name: '一世卦', shi: 1, ying: 4, mutate: [1] },
  { key: 'ii', name: '二世卦', shi: 2, ying: 5, mutate: [1, 2] },
  { key: 'iii', name: '三世卦', shi: 3, ying: 6, mutate: [1, 2, 3] },
  { key: 'iv', name: '四世卦', shi: 4, ying: 1, mutate: [1, 2, 3, 4] },
  { key: 'v', name: '五世卦', shi: 5, ying: 2, mutate: [1, 2, 3, 4, 5] },
  { key: 'you', name: '游魂卦', shi: 4, ying: 1, mutate: [1, 2, 3, 5] },
  // 归魂：游魂卦内卦三爻复原（相对宫首即为五爻变），如乾宫归魂为火天大有
  { key: 'gui', name: '归魂卦', shi: 3, ying: 6, mutate: [5] }
];

// 纳甲：每宫的内卦三爻 / 外卦三爻干支（自初爻向上）
const NA_JIA = {
  乾: { inner: [['甲', '子'], ['甲', '寅'], ['甲', '辰']], outer: [['壬', '午'], ['壬', '申'], ['壬', '戌']] },
  坤: { inner: [['乙', '未'], ['乙', '巳'], ['乙', '卯']], outer: [['癸', '丑'], ['癸', '亥'], ['癸', '酉']] },
  震: { inner: [['庚', '子'], ['庚', '寅'], ['庚', '辰']], outer: [['庚', '午'], ['庚', '申'], ['庚', '戌']] },
  巽: { inner: [['辛', '丑'], ['辛', '亥'], ['辛', '酉']], outer: [['辛', '未'], ['辛', '巳'], ['辛', '卯']] },
  坎: { inner: [['戊', '寅'], ['戊', '辰'], ['戊', '午']], outer: [['戊', '申'], ['戊', '戌'], ['戊', '子']] },
  离: { inner: [['己', '卯'], ['己', '丑'], ['己', '亥']], outer: [['己', '酉'], ['己', '未'], ['己', '巳']] },
  艮: { inner: [['丙', '辰'], ['丙', '午'], ['丙', '申']], outer: [['丙', '戌'], ['丙', '子'], ['丙', '寅']] },
  兑: { inner: [['丁', '巳'], ['丁', '卯'], ['丁', '丑']], outer: [['丁', '亥'], ['丁', '酉'], ['丁', '未']] }
};

const ZHI_ELEM = {
  子: '水', 丑: '土', 寅: '木', 卯: '木', 辰: '土', 巳: '火',
  午: '火', 未: '土', 申: '金', 酉: '金', 戌: '土', 亥: '水'
};

const SHENG = { 木: '火', 火: '土', 土: '金', 金: '水', 水: '木' };
const KE = { 木: '土', 土: '水', 水: '火', 火: '金', 金: '木' };

// 六神按日干起：甲乙青龙、丙丁朱雀、戊勾陈、己腾蛇、庚辛白虎、壬癸玄武
const LIU_SHEN_ORDER = ['青龙', '朱雀', '勾陈', '腾蛇', '白虎', '玄武'];
const LIU_SHEN_START = { 甲: 0, 乙: 0, 丙: 1, 丁: 1, 戊: 2, 己: 3, 庚: 4, 辛: 4, 壬: 5, 癸: 5 };

/** 六亲：以宫五行为「我」 */
function liuQinOf(gongElem, zhiElem) {
  if (gongElem === zhiElem) return '兄弟';
  if (SHENG[zhiElem] === gongElem) return '父母'; // 生我
  if (SHENG[gongElem] === zhiElem) return '子孙'; // 我生
  if (KE[zhiElem] === gongElem) return '官鬼';     // 克我
  return '妻财';                                    // 我克
}

/** 按宫首三爻与卦型生成六爻二进制（自初爻向上，1=阳） */
function binaryOfGong(gongBin, mutate) {
  const arr = [gongBin[0], gongBin[1], gongBin[2], gongBin[0], gongBin[1], gongBin[2]];
  mutate.forEach((pos) => {
    arr[pos - 1] = arr[pos - 1] === '1' ? '0' : '1';
  });
  return arr.join('');
}

// 建表：binary → { gong, type, shi, ying }
const TABLE = {};
GONG.forEach((g) => {
  TYPES.forEach((t) => {
    const bin = binaryOfGong(g.bin, t.mutate);
    if (!TABLE[bin]) {
      TABLE[bin] = { gong: g.name, gongElem: g.elem, typeKey: t.key, typeName: t.name, shi: t.shi, ying: t.ying };
    }
  });
});

/**
 * 京房八宫全解
 * @param {string} binary 六爻二进制，自初爻向上
 * @param {string} [dayGan] 日干（用于排六神）
 */
function analyze(binary, dayGan) {
  const info = TABLE[binary];
  const hex = byBinary(binary);
  if (!info || !hex) return null;

  const naJia = NA_JIA[info.gong] || NA_JIA[hex.upper];
  const shenStart = LIU_SHEN_START[dayGan];
  const hasShen = typeof shenStart === 'number';

  const lines = [];
  for (let i = 0; i < 6; i++) {
    const ganZhi = i < 3 ? naJia.inner[i] : naJia.outer[i - 3];
    const elem = ZHI_ELEM[ganZhi[1]];
    lines.push({
      pos: i + 1,
      yaoName: ['初', '二', '三', '四', '五', '上'][i] + '爻',
      yin: binary[i] === '0',
      gan: ganZhi[0],
      zhi: ganZhi[1],
      elem,
      liuQin: liuQinOf(info.gongElem, elem),
      liuShen: hasShen ? LIU_SHEN_ORDER[(shenStart + i) % 6] : '',
      isShi: i + 1 === info.shi,
      isYing: i + 1 === info.ying
    });
  }

  const shiLine = lines[info.shi - 1];
  const yingLine = lines[info.ying - 1];
  const text = `${hex.name}属${info.gong}宫（${info.gongElem}），${info.typeName}，世在${shiLine.yaoName}（${shiLine.liuQin}${shiLine.gan}${shiLine.zhi}），应在${yingLine.yaoName}（${yingLine.liuQin}${yingLine.gan}${yingLine.zhi}）。`;

  return {
    name: hex.name,
    binary,
    gong: info.gong,
    gongElem: info.gongElem,
    typeKey: info.typeKey,
    typeName: info.typeName,
    shi: info.shi,
    ying: info.ying,
    lines,
    text
  };
}

/** 八宫六十四卦表（每宫自本宫至归魂），供页面罗列 */
function table() {
  const out = [];
  GONG.forEach((g) => {
    TYPES.forEach((t) => {
      const bin = binaryOfGong(g.bin, t.mutate);
      const hex = byBinary(bin);
      out.push({
        gong: g.name,
        gongElem: g.elem,
        typeName: t.name,
        shi: t.shi,
        ying: t.ying,
        name: hex ? hex.name : '',
        binary: bin
      });
    });
  });
  return out;
}

module.exports = {
  GONG,
  TYPES,
  NA_JIA,
  ZHI_ELEM,
  LIU_SHEN_ORDER,
  binaryOfGong,
  liuQinOf,
  analyze,
  table
};
