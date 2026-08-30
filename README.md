# MiniPills 家庭药品管理

一款帮助家庭管理常备药品的移动应用。支持录入药品信息、追踪有效期、管理存放位置与库存，通过拍照 / AI 识别快速录入。

> 本项目由 Flutter 实现，业务功能参考（并迁移自）同名微信小程序版本。

## 功能特性

- **药品清单管理**：添加、编辑、删除药品，支持按名称搜索、按存放位置筛选
- **有效期追踪**：自动标记临期与过期药品，按紧急程度排序，支持日期选择器编辑有效期
- **多照片支持**：每件药品可存储多张照片（拍照或相册选择），支持预览与删除
- **存放位置管理**：内置常用位置（如药箱/冰箱），支持自定义位置输入并自动记忆
- **AI 拍照识别**：拍摄药盒照片，调用云函数识别药品名称/规格/厂家，快速回填表单
- **库存管理**：记录数量与单位，剩余不足时提示
- **条形码记录**：可手动记录药品条形码，便于后续检索比对

## 技术栈

- **框架**：Flutter
- **本地存储**：shared_preferences
- **图片选择**：image_picker
- **网络请求**：http
- **AI 识别后端**：Supabase Edge Function（`ai-recognize` 云函数）

## 目录结构

```
lib/
├── main.dart                  # 应用入口
├── theme.dart                 # 全局主题
├── models/
│   ├── medicine.dart          # 药品数据模型
│   └── med_list.dart          # 药品列表业务逻辑（状态计算、排序、过期处理）
├── pages/
│   ├── medication_list_page.dart  # 药品列表主页
│   ├── add_medicine_page.dart     # 添加药品页（拍照/AI 录入、有效期/位置选择）
│   └── medicine_detail_page.dart  # 药品详情/编辑页
└── services/
    ├── medicine_storage.dart      # 药品数据持久化
    ├── ai_recognize_service.dart  # AI 识别服务
    └── api_config.dart            # 后端地址配置
```

## 环境要求

- Flutter SDK 3.13+ / Dart 3.13+
- Android 7.0 (API 24) 及以上

## 快速开始

```bash
flutter pub get
flutter run
```

### AI 识别配置

AI 识别依赖 Supabase Edge Function。部署 `ai-recognize` 云函数后，将 `lib/services/api_config.dart` 中的 `baseUrl` 替换为你的 Edge Function 地址：

```dart
static const String baseUrl = 'https://<your-project>.functions.supabase.co';
```

## 构建 Android Release

```bash
flutter build apk --release
```

产物位于 `build/app/outputs/flutter-apk/app-release.apk`。

## 测试

```bash
flutter test
```

## 许可证

本项目基于 [MIT License](LICENSE) 开源。