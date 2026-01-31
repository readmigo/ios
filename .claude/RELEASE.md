# iOS 发版流程

## 版本号规则

| 字段 | 位置 | 格式 | 示例 |
|------|------|------|------|
| MARKETING_VERSION | project.pbxproj + Info.plist | X.Y.Z | 2.0.1 |
| CURRENT_PROJECT_VERSION | project.pbxproj + Info.plist | YYYYMMDD | 20260131 |

## 发版步骤

### Step 1: 更新版本号

**必须同时更新两个文件：**

```
Readmigo.xcodeproj/project.pbxproj
├── MARKETING_VERSION = X.Y.Z
└── CURRENT_PROJECT_VERSION = YYYYMMDD

Readmigo/Info.plist
├── CFBundleShortVersionString = X.Y.Z
└── CFBundleVersion = YYYYMMDD
```

### Step 2: 构建 Archive

```bash
xcodebuild -project Readmigo.xcodeproj \
  -scheme Readmigo \
  -configuration Release \
  -archivePath /tmp/Readmigo.xcarchive \
  archive -quiet
```

### Step 3: 验证版本

```bash
/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleShortVersionString" /tmp/Readmigo.xcarchive/Info.plist
/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleVersion" /tmp/Readmigo.xcarchive/Info.plist
```

### Step 4: 上传到 App Store Connect

```bash
open /tmp/Readmigo.xcarchive
```

在 Xcode Organizer 中：
1. 选择新创建的 Archive
2. 点击 "Distribute App"
3. 选择 "App Store Connect"
4. 选择 "Upload"
5. 等待上传完成

### Step 5: 提交代码

```bash
git add Readmigo.xcodeproj/project.pbxproj Readmigo/Info.plist
git commit -m "chore: bump version to X.Y.Z (YYYYMMDD)"
git push
```

### Step 6: 在 App Store Connect 发布

上传完成后，前往 App Store Connect 提交审核：

**操作链接：**
- App Store Connect: https://appstoreconnect.apple.com/apps/6740539519/appstore

**发布步骤：**

1. 打开上方链接，进入 App Store 页面
2. 点击左侧版本号（如 "2.0.1 准备提交"）
3. 在 "构建版本" 区域点击 "+" 选择刚上传的 Build
4. 填写 "此版本的新增内容"（更新说明）
5. 点击右上角 "添加以供审核"
6. 确认提交信息，点击 "提交至 App 审核"

**审核状态查看：**
- TestFlight: https://appstoreconnect.apple.com/apps/6740539519/testflight
- 审核状态: https://appstoreconnect.apple.com/apps/6740539519/appstore

**常用更新说明模板：**
```
Bug 修复和性能优化
```

## 完整命令（一键执行）

```bash
# 设置版本号变量
VERSION="2.0.1"
BUILD="20260131"

# 更新 project.pbxproj
sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = ${VERSION};/g" Readmigo.xcodeproj/project.pbxproj
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = ${BUILD};/g" Readmigo.xcodeproj/project.pbxproj

# 更新 Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" Readmigo/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD}" Readmigo/Info.plist

# 构建 Archive
rm -rf /tmp/Readmigo.xcarchive
xcodebuild -project Readmigo.xcodeproj -scheme Readmigo -configuration Release -archivePath /tmp/Readmigo.xcarchive archive -quiet

# 验证版本
/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleShortVersionString" /tmp/Readmigo.xcarchive/Info.plist
/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleVersion" /tmp/Readmigo.xcarchive/Info.plist

# 打开 Organizer 上传
open /tmp/Readmigo.xcarchive

# 提交代码
git add Readmigo.xcodeproj/project.pbxproj Readmigo/Info.plist
git commit -m "chore: bump version to ${VERSION} (${BUILD})"
git push
```

## 流程图

```
┌─────────────────┐
│  确定版本号     │
│  X.Y.Z + BUILD  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  更新版本文件   │
│  • project.pbxproj
│  • Info.plist   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  构建 Archive   │
│  xcodebuild     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  验证版本号     │
│  PlistBuddy     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  上传 App Store │
│  Xcode Organizer│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  提交 Git       │
│  commit & push  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  App Store 发布 │
│  提交审核       │
└─────────────────┘
```

## 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| Archive 版本不对 | Info.plist 未更新 | 同时更新 project.pbxproj 和 Info.plist |
| 上传失败 "No Accounts" | 未登录 App Store Connect | 在 Xcode Organizer 中手动上传 |
| Build 号重复 | 同一天多次发版 | 使用 YYYYMMDD + 序号，如 2026013101 |
