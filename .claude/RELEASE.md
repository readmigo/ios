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

# 创建并推送 tag（发布成功后执行）
git tag -a "v${VERSION}" -m "Release ${VERSION}"
git push origin "v${VERSION}"
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
│  创建 Git Tag   │
│  vX.Y.Z         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  App Store 发布 │
│  提交审核       │
└─────────────────┘
```

## Git Tag 管理

### 创建发布 Tag

发布成功后创建 Tag 标记版本：

```bash
# 创建 tag
git tag -a v2.0.1 -m "Release 2.0.1"

# 推送 tag 到远程
git push origin v2.0.1

# 推送所有 tags
git push origin --tags
```

### Tag 命名规范

| 类型 | 格式 | 示例 |
|------|------|------|
| 正式发布 | vX.Y.Z | v2.0.1 |
| 测试版本 | vX.Y.Z-beta.N | v2.0.1-beta.1 |
| 候选版本 | vX.Y.Z-rc.N | v2.0.1-rc.1 |

### 查看 Tags

```bash
# 列出所有 tags
git tag -l

# 列出匹配模式的 tags
git tag -l "v2.*"

# 查看 tag 详情
git show v2.0.1
```

### 删除 Tag（谨慎使用）

```bash
# 删除本地 tag
git tag -d v2.0.1

# 删除远程 tag
git push origin --delete v2.0.1
```

## 分支管理策略

### 分支结构

```
main (主分支)
├── 稳定代码，随时可发布
├── 所有发布从此分支构建
└── 受保护，需 PR 合并

feature/* (功能分支)
├── 新功能开发
├── 从 main 创建
└── 完成后合并回 main

bugfix/* (修复分支)
├── Bug 修复
├── 从 main 创建
└── 完成后合并回 main

hotfix/* (紧急修复)
├── 生产环境紧急修复
├── 从 main 创建
└── 修复后立即合并并发布
```

### 分支命名规范

| 类型 | 格式 | 示例 |
|------|------|------|
| 功能 | feature/简短描述 | feature/add-dark-mode |
| 修复 | bugfix/issue编号-描述 | bugfix/123-fix-crash |
| 紧急 | hotfix/简短描述 | hotfix/login-failure |

### 工作流程

```
┌─────────────────────────────────────────────────────────┐
│                        main                              │
└─────────────────────────────────────────────────────────┘
     │                    ▲                    ▲
     │ 创建分支           │ PR 合并            │ PR 合并
     ▼                    │                    │
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ feature/xxx  │    │ bugfix/xxx   │    │ hotfix/xxx   │
└──────────────┘    └──────────────┘    └──────────────┘
     │                    │                    │
     │ 开发完成           │ 修复完成           │ 紧急修复
     ▼                    ▼                    ▼
   创建 PR             创建 PR              创建 PR
```

### 发布后操作

1. **合并代码** → main 分支
2. **创建 Tag** → vX.Y.Z
3. **删除功能分支**（可选）

```bash
# 删除已合并的本地分支
git branch -d feature/xxx

# 删除远程分支
git push origin --delete feature/xxx
```

## 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| Archive 版本不对 | Info.plist 未更新 | 同时更新 project.pbxproj 和 Info.plist |
| 上传失败 "No Accounts" | 未登录 App Store Connect | 在 Xcode Organizer 中手动上传 |
| Build 号重复 | 同一天多次发版 | 使用 YYYYMMDD + 序号，如 2026013101 |
| Tag 已存在 | 重复创建同名 tag | 删除旧 tag 或使用新版本号 |
