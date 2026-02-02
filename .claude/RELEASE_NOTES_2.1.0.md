# Release Notes for Version 2.1.0

## App Store 更新说明

### 中文版本

```
全球化升级！

• 新增 10 种语言支持（英语、西班牙语、阿拉伯语、葡萄牙语、印尼语、法语、日语、俄语、韩语、繁体中文）
• 全新多语言界面，为全球用户提供本地化体验
• 优化应用性能和稳定性
```

### English Version

```
Global Update!

• Added 10 new language support (English, Spanish, Arabic, Portuguese, Indonesian, French, Japanese, Russian, Korean, Traditional Chinese)
• Brand new multi-language interface for global users
• Performance improvements and bug fixes
```

### 简洁版本（备用）

```
• 新增多语言支持，服务全球用户
• 性能优化和问题修复
```

```
• Added multi-language support
• Performance improvements
```

## 详细更新内容（内部参考）

### 新增功能
1. **多语言支持**
   - 支持 11 种语言（包含原有的简体中文）
   - 完整的界面本地化（22 个字符串翻译）
   - 本地化应用名称和隐私说明
   - 自动根据系统语言切换

2. **语言列表**
   - 🇺🇸 英语 (English)
   - 🇨🇳 简体中文 (Simplified Chinese)
   - 🇹🇼 繁体中文 (Traditional Chinese)
   - 🇪🇸 西班牙语 (Español)
   - 🇸🇦 阿拉伯语 (العربية)
   - 🇵🇹 葡萄牙语 (Português)
   - 🇮🇩 印尼语 (Bahasa Indonesia)
   - 🇫🇷 法语 (Français)
   - 🇯🇵 日语 (日本語)
   - 🇷🇺 俄语 (Русский)
   - 🇰🇷 韩语 (한국어)

### 技术实现
- 创建了 22 个 .lproj 资源包（11 种语言 × 2 个文件）
- Localizable.strings: 应用内文本翻译
- InfoPlist.strings: 应用名称和权限说明
- 在 LocalizationManager 中添加完整的语言支持
- Xcode 项目配置中添加所有语言区域

### 版本信息
- 版本号：2.1.0
- Build 号：20260202
- 发布日期：2026-02-02

## 提交审核时的操作

1. 登录 [App Store Connect](https://appstoreconnect.apple.com/apps/6740539519/appstore)
2. 选择版本 2.1.0
3. 在 "此版本的新增内容" 中填写上述中文或中英双语版本
4. 选择刚上传的 Build (20260202)
5. 提交审核

## 营销要点

- **全球化扩张**：支持 11 种语言，覆盖全球主要市场
- **用户体验**：本地化界面，让各国用户都能轻松使用
- **技术升级**：完整的国际化架构，为未来扩展打下基础
