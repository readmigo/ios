# BUG: 段落翻译内容不匹配

## 状态：待修复

## 问题描述

长按段落触发翻译时，显示的中文翻译与当前英文段落不对应。

## 影响范围

所有包含超出单页高度段落的书籍。以《丛林》第一章为例，42 个段落中 16 个被拆分，产生 **19 处翻译错误**。

## 数据流

```
用户长按段落 → JS 获取 paragraphIndex → Swift 接收 → API 请求 /paragraphs/{index} → 显示翻译
                        ↑
                   此处 index 错误
```

## 根因

```
┌─────────────────────────────────────────────────────────────┐
│ 1. DOMContentLoaded                                         │
│    indexAllParagraphs() 给所有 <p> 分配                       │
│    data-global-paragraph-index (0,1,2...)                   │
│                          ↓                                  │
│ 2. paginateContent()                                        │
│    超高段落被拆分为多个新 <p>                                   │
│    新 <p> ❌ 没有 data-global-paragraph-index 属性             │
│                          ↓                                  │
│ 3. setupParagraphLongPress()                                │
│    遍历分页后的 <p>，读取 data-global-paragraph-index          │
│    丢失属性的 → fallback 到 localIdx（DOM 中的序号）            │
│    localIdx ≠ 原始段落 index                                  │
│                          ↓                                  │
│ 4. API 收到错误的 index，返回其他段落的翻译                      │
└─────────────────────────────────────────────────────────────┘
```

## 截图验证（丛林 第一章）

| 项目 | 内容 |
|------|------|
| 英文显示 | "...advantage of her in altitude, the driver had stood his ground..." |
| 所属段落 | **P0 的第2部分**（P0 共 1240 字符，被拆分为 2 页） |
| 实际发送的 index | **1**（localIdx fallback） |
| API 返回 | T1: "这是不幸的，因为门前已经有一群人了..." |
| 正确的 index | **0** |
| 正确的翻译 | T0: "当仪式结束，马车开始到达时，已经是四点钟了..." |

## 第一章完整影响分析

| 指标 | 数值 |
|------|------|
| 原始段落数 | 42 |
| 被拆分段落数 | 16（38%） |
| 分页后 `<p>` 总数 | 61 |
| 翻译出错位置数 | 19 |

### 被拆分段落详情

| 段落 | 字符数 | 拆分数 | 出错部分 |
|------|--------|--------|----------|
| P0 | 1240 | 2 | part 1 |
| P5 | 1703 | 2 | part 1 |
| P6 | 1213 | 2 | part 1 |
| P15 | 2221 | 3 | part 1, 2 |
| P20 | 1213 | 2 | part 1 |
| P21 | 1305 | 2 | part 1 |
| P23 | 4046 | 4 | part 1, 2, 3 |
| P24 | 1443 | 2 | part 1 |
| P29 | 1159 | 2 | part 1 |
| P30 | 1383 | 2 | part 1 |
| P31 | 1220 | 2 | part 1 |
| P32 | 1830 | 2 | part 1 |
| P33 | 1785 | 2 | part 1 |
| P34 | 1866 | 2 | part 1 |
| P35 | 2069 | 2 | part 1 |
| P37 | 1791 | 2 | part 1 |

## 关键代码位置

| 文件 | 行号 | 说明 |
|------|------|------|
| ReaderContentView.swift | 1301-1312 | `indexAllParagraphs()` 分配原始 index |
| ReaderContentView.swift | 1640-1698 | 超高段落拆分逻辑，新 `<p>` 未复制属性 |
| ReaderContentView.swift | 1682-1685 | 创建拆分 `<p>` 的位置（修复点 1） |
| ReaderContentView.swift | 1694-1697 | 创建剩余内容 `<p>` 的位置（修复点 2） |
| ReaderContentView.swift | 731-810 | `setupParagraphLongPress()` fallback 逻辑 |

## 修复方案

在段落拆分逻辑中（第 1682 行和第 1694 行），创建新 `<p>` 元素时复制原始段落的 `data-global-paragraph-index` 属性，使拆分后的每个部分长按时都发送正确的原始 index。
