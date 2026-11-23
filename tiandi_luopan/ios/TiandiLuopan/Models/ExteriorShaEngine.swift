import Foundation

// MARK: - 建筑外部环境几何与微气候观测知识库 (Architectural Site Environment Engine)

public enum ShaSeverity: String, Codable {
    case critical = "高关注度 (强环境影响)"
    case warning  = "中关注度 (建议隔离)"
    case minor    = "轻关注度 (局部优化)"
    case notice   = "环境良好 (视野开阔)"

    public var badgeColorHex: String {
        switch self {
        case .critical: return "#ef4444"
        case .warning:  return "#f59e0b"
        case .minor:    return "#eab308"
        case .notice:   return "#10b981"
        }
    }

    public var localizedTitle: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch self {
        case .critical:
            switch lang {
            case .en: return "High Priority (Strong Impact)"
            case .zhHant, .ja: return "高關注度 (強環境影響)"
            case .ko: return "높은 주의 (강한 환경 영향)"
            case .vi: return "Ưu tiên cao (Ảnh hưởng mạnh)"
            case .th: return "ระดับสูง (ผลกระทบสิ่งแวดล้อมชัดเจน)"
            case .id: return "Prioritas Tinggi (Dampak Kuat)"
            case .auto, .zhHans: return "高关注度 (强环境影响)"
            }
        case .warning:
            switch lang {
            case .en: return "Medium Priority (Mitigate)"
            case .zhHant: return "中關注度 (建議隔離)"
            case .ja: return "中優先度 (対策推奨)"
            case .ko: return "중간 주의 (차폐 권장)"
            case .vi: return "Ưu tiên vừa (Nên che chắn)"
            case .th: return "ระดับกลาง (ควรปรับลดผลกระทบ)"
            case .id: return "Prioritas Sedang (Perlu Mitigasi)"
            case .auto, .zhHans: return "中关注度 (建议隔离)"
            }
        case .minor:
            switch lang {
            case .en: return "Low Priority (Fine-Tune)"
            case .zhHant: return "輕關注度 (局部優化)"
            case .ja: return "軽微 (局所調整)"
            case .ko: return "낮은 주의 (부분 보완)"
            case .vi: return "Ưu tiên thấp (Tối ưu nhẹ)"
            case .th: return "ระดับเล็กน้อย (ปรับแต่งเฉพาะจุด)"
            case .id: return "Prioritas Rendah (Optimasi Ringan)"
            case .auto, .zhHans: return "轻关注度 (局部优化)"
            }
        case .notice:
            switch lang {
            case .en: return "Favorable (Open Sightline)"
            case .zhHant: return "環境良好 (視野開闊)"
            case .ja: return "良好 (開放的な視界)"
            case .ko: return "양호 (개방된 시야)"
            case .vi: return "Tốt (Tầm nhìn thông thoáng)"
            case .th: return "สภาพแวดล้อมดี (โปร่งโล่ง)"
            case .id: return "Baik (Pandangan Terbuka)"
            case .auto, .zhHans: return "环境良好 (视野开阔)"
            }
        }
    }
}

public struct ExteriorShaItem: Identifiable, Codable {
    public let id: String
    public let name: String              // 建筑外部环境特征名称
    public let aliases: String           // 工程别名 / 微气候标签
    public let visualFeature: String     // 视觉与几何特征
    public let metaphysicsHarm: String   // 物理与人居环境影响机理
    public let severity: ShaSeverity     // 关注等级
    public let classicalText: String     // 建筑环境学参考说明
    public let remedySolution: String    // 建筑物理优化方案

    public var localizedName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            switch id {
            case "tianzhan": return "Narrow Building Wind Channel"
            case "luchong":  return "Direct Road Sightline"
            case "fangong":  return "Outer Curve Traffic Exposure"
            case "tantou":   return "Elevated Sightline Overlap"
            case "chuanxin": return "Straight-Through Draft Axis"
            case "huoxing":  return "Acute Facade Glare Angle"
            case "baihu":    return "Asymmetric Massing / Shadow"
            case "gejiao":   return "Adjacent Artery / Waterfront"
            default: return name
            }
        case .zhHant:
            switch id {
            case "tianzhan": return "樓間狹縫風道"
            case "luchong":  return "直路視線與眩光"
            case "fangong":  return "弧形外側車流"
            case "tantou":   return "高差視線交疊"
            case "chuanxin": return "中軸直通穿堂風"
            case "huoxing":  return "尖角立面反光"
            case "baihu":    return "側翼體量遮陰"
            case "gejiao":   return "臨路/臨水緊鄰"
            default: return name
            }
        case .ja:
            switch id {
            case "tianzhan": return "ビル間狭小風道"
            case "luchong":  return "直線道路の視線・眩光"
            case "fangong":  return "カーブ外側交通影響"
            case "tantou":   return "段差視線・プライバシー"
            case "chuanxin": return "直通気流・振動軸"
            case "huoxing":  return "鋭角外壁・反射光"
            case "baihu":    return "側方ボリューム日影"
            case "gejiao":   return "幹線・水辺近接"
            default: return name
            }
        case .ko:
            switch id {
            case "tianzhan": return "건물 간 협곡 풍도"
            case "luchong":  return "직선 도로 시선·눈부심"
            case "fangong":  return "곡선 외측 교통 노출"
            case "tantou":   return "고저차 시선 간섭"
            case "chuanxin": return "직통 맞바람·진동 축"
            case "huoxing":  return "예각 입면 반사광"
            case "baihu":    return "측면 매스 일조 비대칭"
            case "gejiao":   return "간선·수변 인접"
            default: return name
            }
        case .vi:
            switch id {
            case "tianzhan": return "Khe gió hẹp giữa tòa nhà"
            case "luchong":  return "Trục đường thẳng & đèn pha"
            case "fangong":  return "Góc cua ngoài giao thông"
            case "tantou":   return "Giao thoa tầm nhìn cao tầng"
            case "chuanxin": return "Hành lang gió lùa xuyên tâm"
            case "huoxing":  return "Góc nhọn & phản xạ nắng"
            case "baihu":    return "Bóng đổ khối nhà bên cạnh"
            case "gejiao":   return "Sát đường cao tốc / bờ nước"
            default: return name
            }
        case .th:
            switch id {
            case "tianzhan": return "ช่องลมแคบระหว่างอาคาร"
            case "luchong":  return "แนวถนนตรงและแสงไฟหน้ารถ"
            case "fangong":  return "โค้งถนนด้านนอก"
            case "tantou":   return "มุมมองทับซ้อนจากอาคารสูง"
            case "chuanxin": return "แนวลมโกรกและแรงสั่นสะเทือน"
            case "huoxing":  return "มุมอาคารแหลมและแสงสะท้อน"
            case "baihu":    return "เงาบังแสงจากอาคารด้านข้าง"
            case "gejiao":   return "ชิดทางยกระดับ/ริมน้ำ"
            default: return name
            }
        case .id:
            switch id {
            case "tianzhan": return "Lorong Angin Celah Gedung"
            case "luchong":  return "Jalur Jalan Lurus & Silau"
            case "fangong":  return "Sisi Luar Tikungan Jalan"
            case "tantou":   return "Tumpang Tindih Privasi Pandang"
            case "chuanxin": return "Koridor Angin Lurus"
            case "huoxing":  return "Sudut Fasad Tajam & Pantulan"
            case "baihu":    return "Bayangan Massa Samping"
            case "gejiao":   return "Berbatasan Jalan Layang / Air"
            default: return name
            }
        case .auto, .zhHans:
            return name
        }
    }

    public var localizedAliases: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            switch id {
            case "tianzhan": return "Venturi Wind Tunnel · Pressure Drop"
            case "luchong":  return "Headlight Glare · Traffic Acoustics"
            case "fangong":  return "Outer Bend Acoustics · Dust"
            case "tantou":   return "Visual Privacy · Overlooking"
            case "chuanxin": return "Cross-Draft · Subsurface Vibration"
            case "huoxing":  return "Specular Glare · Thermal Load"
            case "baihu":    return "Daylight Asymmetry · Shading"
            case "gejiao":   return "Road Noise · Humidity Buffer"
            default: return aliases
            }
        case .zhHant:
            return aliases.replacingOccurrences(of: "风", with: "風").replacingOccurrences(of: "气", with: "氣").replacingOccurrences(of: "压", with: "壓")
        default:
            return aliases
        }
    }

    public var localizedVisualFeature: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            switch id {
            case "tianzhan": return "A narrow vertical gap between two tall buildings faces the window or balcony directly, accelerating local wind speed via the Venturi effect."
            case "luchong":  return "A straight road or long corridor aligns directly with the entrance or window, increasing nighttime headlight glare and traffic noise."
            case "fangong":  return "An elevated highway, river bend, or curved street bows outward toward the facade, exposing the frontage to noise and headlight sweep."
            case "tantou":   return "A taller structure rises directly behind a foreground building, creating elevated sightlines toward windows and balconies."
            case "chuanxin": return "An underpass/driveway passes beneath the structure or front-to-back openings align linearly, creating strong cross-drafts or vibration."
            case "huoxing":  return "Sharp facade corners, reflective glass curtain walls, or heat-emitting mechanical installations face the windows directly."
            case "baihu":    return "A noticeably taller building or active construction mass sits on one side, creating uneven daylight access and lateral wind turbulence."
            case "gejiao":   return "A rapid roadway, overpass, or fast-moving waterway runs immediately beside the building base with minimal setback buffer."
            default: return visualFeature
            }
        case .zhHant:
            switch id {
            case "tianzhan": return "兩棟高樓間距過窄並正對開窗或陽台，氣流通過狹縫時受文丘里效應加速，易產生局部強風與風噪。"
            case "luchong":  return "筆直道路或長走廊正對入戶口或主窗，夜間車燈直射與交通噪聲較明顯。"
            case "fangong":  return "高架橋或弧形道路外側凸面正對建築立面，轉彎車流噪聲、揚塵與車燈掃射較集中。"
            case "tantou":   return "前方建築後方露出較高樓體或屋頂構件，與本戶開窗形成高低視線交疊，影響日間私密性。"
            case "chuanxin": return "樓底存在車道/軌道貫通，或前後門窗完全成一直線，易形成高速穿堂風或輕微低頻振動。"
            case "huoxing":  return "對面尖角立面、大面積反光幕牆或設備機房正對窗口，易帶來強眩光與夏季熱反射。"
            case "baihu":    return "建築一側鄰樓明顯偏高或正在施工，導致兩側採光不均與局部視覺壓迫。"
            case "gejiao":   return "快速路、高架橋或河道緊貼樓基，退距緩衝較小，需重點關注隔聲與防潮。"
            default: return visualFeature
            }
        default:
            return visualFeature
        }
    }

    public var localizedRemedySolution: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            switch id {
            case "tianzhan": return "1. Install double/triple-glazed acoustic windows with airtight weatherstripping.\n2. Place dense broad-leaf balcony plants or operable windbreak louvers to diffuse gusts.\n3. Add an entry partition if front and rear openings align."
            case "luchong":  return "1. Use laminated acoustic glazing and blackout/sheer dual curtains to reduce glare and street noise.\n2. Add a foyer screen or greenery buffer to soften direct sightlines from the road."
            case "fangong":  return "1. Upgrade facade glazing for traffic acoustics (Rw ≥ 35 dB) and seal window perimeters.\n2. Use balcony planters and acoustic drapes to absorb road reflection and dust."
            case "tantou":   return "1. Install top-down/bottom-up cellular shades or one-way daylight privacy film.\n2. Position tall potted plants along the window sill to block overlapping sightlines while keeping sky light."
            case "chuanxin": return "1. Add a semi-open foyer cabinet or sliding screen to slow linear cross-drafts.\n2. Use heavy rugs and acoustic window/door seals to dampen low-frequency vibration."
            case "huoxing":  return "1. Apply Low-E solar-control film or exterior louvers to cut glare and heat gain.\n2. Use matte interior finishes and sheer diffusers to soften harsh specular reflections."
            case "baihu":    return "1. Optimize interior artificial lighting (4000K balanced fill) on the shaded side.\n2. Use acoustic drapes on the construction/high-mass side and high-reflectance wall paint to balance brightness."
            case "gejiao":   return "1. Install laminated soundproof glazing and mechanical fresh-air filtration so windows can stay closed during peak traffic.\n2. Check exterior damp-proofing and balcony drainage near waterways."
            default: return remedySolution
            }
        default:
            return remedySolution
        }
    }

    public var localizedMetaphysicsHarm: String {
        localizedTraditionalHarm
    }

    public var localizedTraditionalHarm: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            switch id {
            case "tianzhan": return "Venturi airflow acceleration increases local gust pressure, whistling window noise, and rapid winter heat loss."
            case "luchong":  return "Direct sightline alignment amplifies oncoming headlight glare at night and direct-path traffic noise."
            case "fangong":  return "Outer-bend road geometry concentrates tire/braking noise, particulate dust, and sweeping headlights onto the facade."
            case "tantou":   return "Overlooking sightlines reduce daytime privacy and visual comfort in living areas."
            case "chuanxin": return "Unbuffered linear openings cause draft discomfort and faster indoor thermal loss; subsurface traffic can transmit low-frequency noise."
            case "huoxing":  return "Specular facade reflections increase visual glare and indoor cooling loads in summer."
            case "baihu":    return "Tall adjacent massing reduces direct sunlight hours on one side and creates uneven room illuminance."
            case "gejiao":   return "Minimal building setback increases traffic noise exposure and ambient humidity near open water."
            default: return metaphysicsHarm
            }
        default:
            return metaphysicsHarm
        }
    }

    public var localizedClassicalText: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            return "Site Physics Note: Observed geometry should be verified on site with daylight, acoustic (dB), and wind-draft measurements before renovation."
        case .zhHant:
            return "建築環境參考：以上為基於實景方位角與幾何遮擋的物理微氣候觀察，裝修或隔聲改造請結合現場實測（光照/噪聲/氣密性）核驗。"
        default:
            return classicalText
        }
    }
}

public final class ExteriorShaEngine {
    public static let shared = ExteriorShaEngine()

    public let database: [ExteriorShaItem] = [
        ExteriorShaItem(
            id: "tianzhan",
            name: "楼间狭缝风道",
            aliases: "文丘里风道 · 狭管风压",
            visualFeature: "两栋高楼间距过窄并正对开窗或阳台，气流通过狭缝时受文丘里效应加速，易产生局部强风与风噪",
            metaphysicsHarm: "狭管效应会显著增大局部风压、引起窗框啸叫并加速冬季室内热量流失",
            severity: .critical,
            classicalText: "建筑微气候参考：楼间狭缝易形成高速风道，建议优先核验外窗抗风压等级与气密性。",
            remedySolution: "① 隔声气密：优先选用双层中空夹胶隔音窗与三元乙丙密封胶条，降低风噪与冷风渗透。\n② 气流缓冲：阳台或窗前布置耐风阔叶绿植或可调百叶，打散高速直吹气流。\n③ 室内导流：若入户与迎风窗成直线，玄关增设半通透隔断减缓穿堂风。"
        ),
        ExteriorShaItem(
            id: "luchong",
            name: "直路视线与眩光",
            aliases: "直向车灯 · 交通声源",
            visualFeature: "笔直道路或长走廊正对入户口或主窗，夜间车灯直射与交通噪声较明显",
            metaphysicsHarm: "直通视廊会放大夜间来车远光眩光与直达交通噪声，降低入户与卧室静谧度",
            severity: .critical,
            classicalText: "建筑声光参考：道路直对立面时，建议以声学窗与遮光层次削弱直达噪光。",
            remedySolution: "① 遮光降噪：配置夹胶隔音窗与日夜双层窗帘（纱帘+遮光帘），削弱夜间车灯直射。\n② 视线缓冲：入户玄关或窗台布置绿植与格栅屏风，柔化直向视线压迫。"
        ),
        ExteriorShaItem(
            id: "fangong",
            name: "弧形外侧车流",
            aliases: "弯道声学 · 扬尘暴露",
            visualFeature: "高架桥或弧形道路外侧凸面正对建筑立面，转弯车流噪声、扬尘与车灯扫射较集中",
            metaphysicsHarm: "道路弯道外侧车辆减速与胎噪反射较强，临街面易受持续交通噪光与灰尘影响",
            severity: .warning,
            classicalText: "场地环境参考：弯道外侧退距不足时，应重点评估立面隔声与新风过滤。",
            remedySolution: "① 声学门窗：临街侧升级隔声等级 Rw ≥ 35 dB 的断桥铝夹胶窗并密封窗缝。\n② 绿化与新风：阳台加设绿植缓冲带，并配合带 HEPA 滤网的新风系统减少开窗扬尘。"
        ),
        ExteriorShaItem(
            id: "tantou",
            name: "高差视线交叠",
            aliases: "高低俯视 · 日间隐私",
            visualFeature: "前方建筑后方露出较高楼体或屋顶构件，与本户开窗形成高低视线交叠，影响日间私密性",
            metaphysicsHarm: "高差对视会降低客厅与卧室的日间私密体验，增加心理视觉干扰",
            severity: .warning,
            classicalText: "人居隐私参考：高层建筑群常见视线交叠，可通过可调角度遮挡兼顾采光与隐私。",
            remedySolution: "① 可调遮挡：安装上下可开合蜂巢帘、香格里拉帘或单向透视磨砂膜，保光不透人。\n② 窗台绿化：在视平线高度布置适量绿植，柔化邻楼棱角遮挡。"
        ),
        ExteriorShaItem(
            id: "chuanxin",
            name: "中轴直通穿堂风",
            aliases: "直通气流 · 地下振动",
            visualFeature: "楼底存在车道/轨道贯通，或前后门窗完全成一直线，易形成高速穿堂风或轻微低频振动",
            metaphysicsHarm: "无缓冲的直线通风会造成体感风速过高、温湿度波动大，地下通道还可能传导低频声振",
            severity: .warning,
            classicalText: "建筑通风参考：合理折线通风比直线穿堂风更利于维持稳定舒适的室内微气候。",
            remedySolution: "① 气流折流：在直通门窗动线中段设置半通透玄关柜或推拉隔断，将直风转为柔和环流。\n② 减振吸音：地面铺设织物地毯、门窗加装密封胶条，降低低频振动与风啸。"
        ),
        ExteriorShaItem(
            id: "huoxing",
            name: "尖角立面反光",
            aliases: "镜面眩光 · 热辐射",
            visualFeature: "对面尖角立面、大面积反光幕墙或设备机房正对窗口，易带来强眩光与夏季热反射",
            metaphysicsHarm: "玻璃幕墙与尖角立面在特定太阳高度角下会产生刺眼眩光并增加室内夏季制冷负荷",
            severity: .warning,
            classicalText: "建筑光热参考：高反射幕墙周边住宅宜采用 Low-E 镀膜与漫反射窗饰控光。",
            remedySolution: "① 隔热控光：外窗加贴 Low-E 隔热防眩膜或安装外遮阳百叶，大幅削减反射热量。\n② 室内柔光：采用哑光墙面漆与柔光纱帘，避免二次镜面眩光。"
        ),
        ExteriorShaItem(
            id: "baihu",
            name: "侧翼体量遮阴",
            aliases: "日照不均 · 施工干扰",
            visualFeature: "建筑一侧邻楼明显偏高或正在施工，导致两侧采光不均与局部视觉压迫",
            metaphysicsHarm: "高大邻楼遮挡会减少侧向有效日照时长，施工期还会带来间歇性粉尘与噪声",
            severity: .minor,
            classicalText: "日照采光参考：单侧受遮挡户型可通过室内反射率与色温照明补足照度均衡。",
            remedySolution: "① 照度平衡：受遮挡一侧选用高反射浅色墙面与 4000K 均匀漫反射补光。\n② 施工隔离：邻侧施工期间使用厚质隔音遮尘窗帘并定期清理窗轨。"
        ),
        ExteriorShaItem(
            id: "gejiao",
            name: "临路/临水紧邻",
            aliases: "退距不足 · 声湿缓冲",
            visualFeature: "快速路、高架桥或河道紧贴楼基，退距缓冲较小，需重点关注隔声与防潮",
            metaphysicsHarm: "退距过小会提高底层/低楼层交通噪声暴露，临水侧在梅雨季则易出现高湿返潮",
            severity: .minor,
            classicalText: "场地缓冲参考：临快速路或水体建筑需重点关注低频隔声与防潮排水构造。",
            remedySolution: "① 声学封闭：优先更换三玻两腔或夹胶隔声窗，并配合机械新风保障关窗换气。\n② 防潮除湿：临水一侧墙地做好防潮处理并配置除湿机，维持室内湿度 45%–60%。"
        )
    ]
}
