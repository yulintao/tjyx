/**
 * i18n.js
 * 多语言管理器，移植自 iOS Models/LocalizationManager.swift（AppLanguage / resolveLanguage /
 * setLanguage / t / validateTranslationTables）。
 * 支持 auto + 8 语种：zh-Hans / zh-Hant / en / th / vi / id / ja / ko。
 * 翻译表采用「增量并入」：TABLES[lang] 中为简体中文以外的译文，未收录的 key 自动回退简体中文，
 * 与 iOS t() 的漏译兜底一致（返回中文而非崩溃）。
 */

const store = require('./store');

const APP_LANGUAGES = [
  { key: 'auto', display: '跟随系统' },
  { key: 'zh-Hans', display: '简体中文' },
  { key: 'zh-Hant', display: '繁體中文' },
  { key: 'en', display: 'English' },
  { key: 'th', display: 'ภาษาไทย' },
  { key: 'vi', display: 'Tiếng Việt' },
  { key: 'id', display: 'Bahasa Indonesia' },
  { key: 'ja', display: '日本語' },
  { key: 'ko', display: '한국어' }
];

// UI 高频文案（导航 / 设置 / 通用动作）。其余业务文案未收录时回退简体中文。
const ZH_HANS = {
  nav_compass: '罗盘', nav_analysis: '盘解', nav_zeri: '择日', nav_floorplan: '户型', nav_settings: '设置',
  settings_title: '设置', settings_appearance: '外观与显示', settings_more: '更多 · 协议 / 权益 / 引导',
  settings_language: '界面语言', settings_unit: '英制单位', settings_notify: '吉日提醒',
  settings_evidence: '显示古籍出处', settings_vip: '功能权益说明', settings_terms: '用户服务协议',
  settings_compliance: '合规与安全说明', settings_privacy: '隐私政策', settings_rate: '评分与反馈',
  settings_guide: '重播新手引导', settings_about: '功能说明',
  common_back: '返回', common_detail: '展开详情', common_collapse: '收起详情', common_more: '更多',
  common_save: '保存', common_delete: '删除', common_cancel: '取消', common_confirm: '确认',
  conclusion_eyebrow: '此刻 · 此地 · 此向', conclusion_detail: '详细盘面与依据见下方「展开详情」',
  footer_note: '本工具仅供传统文化研究与参考，不构成医疗、投资、法律等专业建议。'
};

const TABLES = {
  'zh-Hans': Object.assign({}, ZH_HANS),
  'zh-Hant': {
    nav_compass: '羅盤', nav_analysis: '盤解', nav_zeri: '擇日', nav_floorplan: '戶型', nav_settings: '設定',
    settings_title: '設定', settings_appearance: '外觀與顯示', settings_more: '更多 · 協議 / 權益 / 引導',
    settings_language: '介面語言', settings_unit: '英制單位', settings_notify: '吉日提醒',
    settings_evidence: '顯示古籍出處', settings_vip: '功能權益說明', settings_terms: '用戶服務協議',
    settings_compliance: '合規與安全說明', settings_privacy: '隱私政策', settings_rate: '評分與回饋',
    settings_guide: '重播新手引導', settings_about: '功能說明',
    common_back: '返回', common_detail: '展開詳情', common_collapse: '收起詳情', common_more: '更多',
    common_save: '儲存', common_delete: '刪除', common_cancel: '取消', common_confirm: '確認',
    conclusion_eyebrow: '此刻 · 此地 · 此向', conclusion_detail: '詳細盤面與依據見下方「展開詳情」',
    footer_note: '本工具僅供傳統文化研究與參考，不構成醫療、投資、法律等專業建議。'
  },
  en: {
    nav_compass: 'Compass', nav_analysis: 'Analysis', nav_zeri: 'Date Selection', nav_floorplan: 'Floorplan', nav_settings: 'Settings',
    settings_title: 'Settings', settings_appearance: 'Appearance & Display', settings_more: 'More · Terms / Benefits / Guide',
    settings_language: 'Interface Language', settings_unit: 'Imperial Units', settings_notify: 'Auspicious Day Reminders',
    settings_evidence: 'Show Classical Sources', settings_vip: 'Feature Benefits', settings_terms: 'Terms of Service',
    settings_compliance: 'Compliance & Safety', settings_privacy: 'Privacy Policy', settings_rate: 'Rate & Feedback',
    settings_guide: 'Replay Onboarding', settings_about: 'About This Tool',
    common_back: 'Back', common_detail: 'Show Details', common_collapse: 'Hide Details', common_more: 'More',
    common_save: 'Save', common_delete: 'Delete', common_cancel: 'Cancel', common_confirm: 'Confirm',
    conclusion_eyebrow: 'THIS TIME · THIS PLACE · THIS DIRECTION', conclusion_detail: 'See "Show Details" below for the full chart and sources',
    footer_note: 'For traditional culture study and reference only; not medical, investment, or legal advice.'
  },
  ja: {
    nav_compass: '羅盤', nav_analysis: '盤解', nav_zeri: '選日', nav_floorplan: '間取り', nav_settings: '設定',
    settings_title: '設定', settings_language: '表示言語', settings_unit: 'ヤード・ポンド単位', settings_notify: '吉日リマインダー',
    settings_evidence: '古典出典を表示', settings_terms: '利用規約', settings_privacy: 'プライバシーポリシー',
    settings_guide: 'チュートリアルを再表示', common_back: '戻る', common_detail: '詳細を表示', common_collapse: '詳細を閉じる',
    common_save: '保存', common_delete: '削除', common_cancel: 'キャンセル', common_confirm: '確認'
  },
  ko: {
    nav_compass: '나침반', nav_analysis: '해석', nav_zeri: '길일', nav_floorplan: '평면도', nav_settings: '설정',
    settings_title: '설정', settings_language: '인터페이스 언어', settings_unit: '야드파운드 단위', settings_notify: '길일 알림',
    settings_evidence: '고전 출처 표시', settings_terms: '이용 약관', settings_privacy: '개인정보 처리방침',
    settings_guide: '가이드 다시 보기', common_back: '뒤로', common_detail: '자세히 보기', common_collapse: '접기',
    common_save: '저장', common_delete: '삭제', common_cancel: '취소', common_confirm: '확인'
  },
  th: {
    nav_compass: 'เข็มทิศ', nav_analysis: 'การวิเคราะห์', nav_zeri: 'เลือกวัน', nav_floorplan: 'ผังบ้าน', nav_settings: 'ตั้งค่า',
    settings_title: 'ตั้งค่า', settings_language: 'ภาษาของอินเทอร์เฟซ', settings_notify: 'แจ้งเตือนวันมงคล',
    settings_evidence: 'แสดงแหล่งที่มาคลาสสิก', settings_terms: 'เงื่อนไขการให้บริการ', settings_privacy: 'นโยบายความเป็นส่วนตัว',
    common_back: 'กลับ', common_detail: 'ดูรายละเอียด', common_collapse: 'ยุบรายละเอียด',
    common_save: 'บันทึก', common_delete: 'ลบ', common_cancel: 'ยกเลิก', common_confirm: 'ยืนยัน'
  },
  vi: {
    nav_compass: 'La bàn', nav_analysis: 'Giải mã', nav_zeri: 'Chọn ngày', nav_floorplan: 'Mặt bằng', nav_settings: 'Cài đặt',
    settings_title: 'Cài đặt', settings_language: 'Ngôn ngữ giao diện', settings_notify: 'Nhắc ngày tốt',
    settings_evidence: 'Hiện nguồn kinh điển', settings_terms: 'Điều khoản dịch vụ', settings_privacy: 'Chính sách quyền riêng tư',
    common_back: 'Quay lại', common_detail: 'Xem chi tiết', common_collapse: 'Thu gọn',
    common_save: 'Lưu', common_delete: 'Xóa', common_cancel: 'Hủy', common_confirm: 'Xác nhận'
  },
  id: {
    nav_compass: 'Kompas', nav_analysis: 'Analisis', nav_zeri: 'Pilih Tanggal', nav_floorplan: 'Denah', nav_settings: 'Pengaturan',
    settings_title: 'Pengaturan', settings_language: 'Bahasa Antarmuka', settings_notify: 'Pengingat hari baik',
    settings_evidence: 'Tampilkan sumber klasik', settings_terms: 'Syarat Layanan', settings_privacy: 'Kebijakan Privasi',
    common_back: 'Kembali', common_detail: 'Lihat Detail', common_collapse: 'Tutup Detail',
    common_save: 'Simpan', common_delete: 'Hapus', common_cancel: 'Batal', common_confirm: 'Konfirmasi'
  }
};

const SETTING_KEY = 'app_language';
let currentSetting = 'auto';
let effective = 'zh-Hans';
const loggedMissing = new Set();

/** iOS resolveLanguage(for:)：auto 按系统语言前缀落到具体语种 */
function resolveLanguage(setting, systemLang) {
  if (setting !== 'auto') return setting;
  const pref = (systemLang || 'zh-Hans').toLowerCase();
  if (pref.includes('hant') || pref.includes('tw') || pref.includes('hk') || pref.includes('mo')) return 'zh-Hant';
  if (pref.startsWith('zh')) return 'zh-Hans';
  if (pref.startsWith('th')) return 'th';
  if (pref.startsWith('vi')) return 'vi';
  if (pref.startsWith('id')) return 'id';
  if (pref.startsWith('ja')) return 'ja';
  if (pref.startsWith('ko')) return 'ko';
  return 'en';
}

function init() {
  let saved = 'auto';
  try {
    const s = store.getSettings() || {};
    saved = s[SETTING_KEY] || s.lang || 'auto';
  } catch (e) {}
  if (APP_LANGUAGES.filter((l) => l.key === saved).length === 0) saved = 'auto';
  currentSetting = saved;
  let sysLang = 'zh-Hans';
  try { sysLang = (wx.getSystemInfoSync && wx.getSystemInfoSync().language) || 'zh-Hans'; } catch (e) {}
  effective = resolveLanguage(currentSetting, sysLang);
}

/** iOS setLanguage(_:) */
function setLanguage(lang) {
  if (APP_LANGUAGES.filter((l) => l.key === lang).length === 0) return;
  currentSetting = lang;
  const s = store.getSettings() || {};
  s[SETTING_KEY] = lang;
  store.saveSettings(s);
  let sysLang = 'zh-Hans';
  try { sysLang = (wx.getSystemInfoSync && wx.getSystemInfoSync().language) || 'zh-Hans'; } catch (e) {}
  effective = resolveLanguage(currentSetting, sysLang);
}

function currentLanguage() { return effective; }
function currentSettingLang() { return currentSetting; }

/** iOS t(_:)：优先当前语种，缺译回退简体中文，仍缺则返回 key（只记录一次） */
function t(key) {
  const table = TABLES[effective] || {};
  if (table[key] !== undefined) return table[key];
  if (ZH_HANS[key] !== undefined) return ZH_HANS[key];
  if (!loggedMissing.has(key)) {
    loggedMissing.add(key);
    console.warn('[i18n] missing key:', key, 'lang=', effective);
  }
  return key;
}

/** iOS validateTranslationTables()：全语种并集 key 完备性 + 缺表检测（此处表为增量，仅校验缺表） */
function validateTranslationTables() {
  const issues = [];
  APP_LANGUAGES.filter((l) => l.key !== 'auto').forEach((lang) => {
    if (!TABLES[lang.key]) issues.push(`[${lang.key}] 缺少完整语言字典表`);
  });
  return { valid: issues.length === 0, issues };
}

init();

module.exports = {
  APP_LANGUAGES, TABLES,
  resolveLanguage, setLanguage, currentLanguage, currentSettingLang,
  t, validateTranslationTables
};
