# EmuTrain 重构后架构说明

## 目录结构

```
lib/
├── main.dart                          # 入口：初始化 + Provider 注入
├── app.dart                           # 根组件 + 主屏幕导航
├── core/                              # 核心层（无 Flutter UI 依赖）
│   ├── constants/
│   │   ├── app_constants.dart         # 所有硬编码常量、URL、prefs 键名
│   │   └── data_source.dart           # 数据源枚举（TrainDataSource 等）
│   ├── models/
│   │   ├── journey.dart               # Journey + StationDetail 数据模型
│   │   ├── track_record.dart          # TrackPoint + TrackRecord GPS 轨迹
│   │   └── coach_record.dart          # 普速客车车厢记录
│   ├── providers/
│   │   ├── app_settings_provider.dart # 全局设置状态（主题、数据源等）
│   │   ├── journey_provider.dart      # 行程列表状态 + 持久化
│   │   └── gps_settings_provider.dart # GPS 测速设置
│   ├── services/
│   │   ├── data_file_service.dart     # 本地/Assets JSON 文件加载
│   │   ├── data_build_service.dart    # 数据版本号管理
│   │   ├── remote_config_service.dart # 远程版本/指令拉取
│   │   └── speed_service.dart         # GPS 测速核心逻辑
│   └── utils/
│       ├── train_icon_utils.dart      # 列车图标映射规则
│       └── url_utils.dart             # URL 打开工具
├── features/                          # 功能模块（业务逻辑，可独立测试）
│   ├── journey/
│   │   └── journey_search_service.dart # 所有行程相关 HTTP 请求
│   └── update/
│       ├── update_service.dart        # 更新检查与数据下载
│       └── update_dialogs.dart        # 更新相关弹窗 UI
├── shared/                            # 跨页面共用组件
│   └── widgets/
│       ├── icon_widgets.dart          # TrainIconWidget, BureauIconWidget
│       └── ui_helpers.dart            # SectionCard, IconSwitchTile, DataSourceCard
└── ui/                                # 纯 UI 层（只负责展示与用户交互）
    ├── pages/
    │   ├── travel_page.dart           # 行程列表页（首页之一）
    │   ├── search_page.dart           # 搜索入口页
    │   ├── add_journey_page.dart      # 添加行程（车次/站间搜索）
    │   ├── journey_detail_page.dart   # 行程详情页
    │   ├── settings_page.dart         # 设置页（Tab: 通用 / 功能）
    │   ├── tool_page.dart             # 工具入口页
    │   ├── emu_search_page.dart       # 动车组查询页
    │   ├── coach_search_page.dart     # 普速客车查询页
    │   ├── station_page.dart          # 车站大屏页
    │   ├── speedometer_page.dart      # GPS 测速页
    │   ├── gallery_page.dart          # 动车图鉴页
    │   └── about_page.dart            # 关于页
    └── widgets/
        └── line_map_widget.dart       # 线路走向图组件（可交互缩放）
```

## 设计原则

### 分层职责
| 层 | 职责 | 允许依赖 |
|----|------|----------|
| `core/models` | 纯数据结构 + 序列化 | 无外部依赖 |
| `core/services` | 网络/文件 IO | models, constants |
| `core/providers` | 状态管理 | services, models |
| `features` | 功能业务逻辑 | core/\* |
| `shared/widgets` | 通用 UI 组件 | core/providers |
| `ui/pages` | 页面 UI | 所有以上层 |

### 关键变更
- **原 `main.dart` 中的 `Vars` 类** → `AppConstants`（常量）+ `AppSettingsProvider`（状态）
- **原 `tool.dart`（工具类）** → `TrainIconUtils`、`UrlUtils`、`DataFileService` 等专职类
- **原 `journey_model.dart`** → `core/models/journey.dart`（增加 `copyWith`、计算属性、完整文档注释）
- **原 `journey.dart`（UI 页）** → `ui/pages/add_journey_page.dart`（UI）+ `features/journey/journey_search_service.dart`（网络）
- **原 `update.dart`（混合类）** → `update_service.dart`（逻辑）+ `update_dialogs.dart`（UI）
- **原 `speed_service.dart`** → `core/services/speed_service.dart`（单例，定时轮询，支持运行中调整间隔）
- **所有文件命名** → 全部 `snake_case`，与 Dart 规范一致

### 命名规范
- 文件：`snake_case.dart`
- 类：`PascalCase`
- 私有字段：`_camelCase`
- 常量：`camelCase`（静态成员）
- 注释：关键方法均有 `///` doc comment，复杂逻辑有行内注释
