---
name: daily-report
description: Generate daily or weekly work reports in the user's TME format and save them as Bear notes. Use when the user mentions 日报, 周报, daily report, weekly report, standup, 写日报, 写周报, or any request to write or generate a work report. Also use when the user asks to summarize their recent work.
---

# Daily / Weekly Report Generator

## Core Rules

**1. Never fabricate.** All work items must come from the user. If the user
hasn't provided enough detail, ask — don't guess. The skill only handles
formatting and structure.

**2. Two-step confirmation.** Always present the draft report to the user first.
Only create the Bear note after the user explicitly confirms the content.

## Step 1: Understand Context

When the user asks to write a report, first search recent Bear notes to
understand what's in progress:

```
mcp__bear__search_notes with query "#tme/meeting" and sort by modified date
```

Read the most recent 1-2 daily reports to identify ongoing projects, their
version numbers, and module names. Use this to seed the draft — but the user's
actual input always takes precedence over what the notes suggest.

## Step 2: Populate Yesterday's Work

**Default rule:** Today's "昨天的进展" = Yesterday's "今天的工作".

When creating a new daily report, do NOT ask the user "昨天做了什么?" — pull
it from yesterday's report automatically:

```
1. Determine yesterday's date (today - 1 day)
2. Search for yesterday's report: search_notes(query: "YYYYMMDD | 日报")
3. If found: read its content, extract the "今天的工作" section
4. Use it directly as today's "昨天的进展" draft
5. Only ask the user if something looks wrong or you need clarification
```

**Weekend / Holiday handling:**

If yesterday is a weekend (Saturday/Sunday) or a holiday, search backwards
to find the most recent workday's report:

| Today | Yesterday | Read this report for "昨天的进展" |
|-------|-----------|----------------------------------|
| Monday | Sunday | Last Friday's report |
| Tuesday | Monday | Monday's report ✅ |
| After holiday | Holiday | The last workday before the holiday |

- If the most recent report is ≤ 3 days old: use it
- If the most recent report is > 3 days old: leave "昨天的进展" empty, ask the user
- Weekend days: Saturday and Sunday

**The user can always override** — if they say "昨天实际做了X而不是Y", apply the change.

## Step 3: Gather Today's Work

Ask the user what they worked on today. Two prompts cover most situations:

**For daily reports:**
> 以下是根据最近日报识别到的项目。今天做了什么？有哪些需要新增/修改？

**For weekly reports:**
> 这周主要做了哪些工作？我根据日报帮你汇总了初稿，你看看有没有要补充的。

The user can reply with shorthand — the skill translates it into the proper
format.

## Step 4: Format the Report

### Daily Report Format

```markdown
# YYYYMMDD | 日报
#tme/meeting/YYYY/MM

## ❮ 昨天的进展
序号. 🔨 版本号 【模块】需求名称（状态）
* 具体工作项
序号. 🐛 版本号 - 问题描述
* 具体工作项
序号. 🎯 OKR：主题
* 子工作项
序号. 📌 其他事项

## ❙ 今天的工作
（同上结构）

## ❯ 明天的计划
（创建时留空，后续可补充）
```

### Weekly Report Format

```markdown
# YYYYMMDD | 周报
#tme/meeting/YYYY/MM

## 本周的工作
序号. 🔨 版本号 【模块】需求名称
* 动作链1、动作链2、动作链3
序号. 🐛 版本号 - 问题描述
* 动作链
序号. 🎯 OKR：主题
* 子工作项
```

### Emoji Scheme

**Section headers:**

| Emoji | Section |
|-------|---------|
| ❮ | 昨天的进展 |
| ❙ | 今天的工作 |
| ❯ | 明天的计划 |

**Work item types (placed after the number, before the content):**

| Emoji | Type | Usage |
|-------|------|-------|
| 🔨 | 需求开发 | All feature development, regardless of status |
| 🐛 | 问题跟进 | Bug fixes, issue tracking |
| 🎯 | OKR | Goal-related work |
| 📌 | 其他 | Meetings, sharing sessions, misc |

### Work Item Types

There are four types of items that can appear in the report:

**1. 需求开发（Feature Development）**
Format: `序号. 🔨 版本号 【模块】需求名称` followed by `*` bullet items.

Features go through a lifecycle. Append a status tag at the end of the title
line to indicate the current stage:

| Stage | Tag |
|-------|-----|
| 评估工作量 | `（评估中）` |
| 开发中 | `（开发中）` |
| 转体验 | `（转体验）` |
| 测试中 | `（测试中）` |
| 已发布 | `（已发布）` |

Example: `1、🔨 20.5.5 【推荐】猜你喜欢场景选择（开发中）`

Note: In rare cases the version number may not be determined yet in early
stages. Use `TBD` or ask the user.

**2. 问题跟进（Issue Tracking）**
Format: `序号. 🐛 版本号 - 问题描述` or `序号. 🐛 版本号 - 【模块】问题描述`

Usually no status tag. Example:
`2、🐛 20.5.0 - 问题跟进` or `2、🐛 20.4.5 - 【启动定位】客户端后台定位策略...`

**3. OKR**
Format: `序号. 🎯 OKR：主题` with `*` sub-items.

Example:
```
3、🎯 OKR：AI-Coding
* AGENT.md 建设方案细化
```

**4. 其他（Other）**
Format: `序号. 📌 事项描述` — no version number needed.

Examples: `参加月会`, `参加技术分享`

### General Formatting Rules

- **Title date:** `YYYYMMDD` format. For daily reports use today's date. For
  weekly reports use the Friday or Sunday of the current week.
- **Tags:** `#tme/meeting/YYYY/MM` — month derived from the title date.
- **Bullet items:** Verb phrases only — 开发, 跟测, 合入, 转体验, 体验问题跟进, 数据上报,
  方案评估, 工作量评估. No complete sentences. Strip modifiers like
  继续/接着/再/正在 before action verbs (e.g., "继续跟测" → "跟测").
  No "完成了", no "进行了".
- **Numbering:** Ordered list starting from 1. Group related work under the same
  numbered item.
- **Item spacing:** Consecutive numbered items within the same section must NOT
  be separated by blank lines. The last `*` bullet of one item should be directly
  followed by the next `序号.` line. Blank lines are only allowed between sections
  (between `##` headers), not between items within a section.
- **Weekly aggregation:** When aggregating daily reports into a weekly report,
  merge actions for the same project into a chain: `需求开发、转体验、跟测、合入`.
  Status tags are not used in weekly reports.

## Step 5: Confirm Then Create

1. Show the formatted report to the user.
2. Wait for explicit confirmation (e.g., "好的", "可以", "创建").
3. Create the note in Bear:

```
mcp__bear__create_note with:
  title: "YYYYMMDD | 日报" (or 周报)
  content: <the confirmed markdown>
```

The `#tme/meeting/YYYY/MM` tag is embedded in the content as the first line
after the title. Bear will parse it automatically.

**After creation:** Inform the user the note has been created. Remind them that
`## 明天的计划` is left empty and can be filled in later.

## Updating an Existing Report

Daily reports are living documents — tasks shift, new things come up, plans
change. The user may ask to update today's (or any date's) report at any time.

When the user asks to 补充, 更新, 修改, 调整, or add content to a daily report:

1. Search for the existing note by title (e.g., `20260602 | 日报`).
   If the user doesn't specify a date, default to today.
2. Read its current content.
3. Ask the user what changed.
4. Present the updated full content for confirmation.
5. Use `mcp__bear__overwrite_note` to apply the change.

Any section can be updated at any time:

**更新「今天的工作」**
- 新增事项: 「灵活动调节临时加了个需求评审」→ 追加新的编号条目
- 调整状态: 「场景选择转体验了」→ 改条目状态标签，改 bullet 内容
- 追加细节: 「跟测发现一个 crash，定位中」→ 在已有条目下加 `*` bullet

**补充「明天的计划」**
- 「补充下明天的计划」→ 填写 `## 明天的计划`
- 计划可能包含: 继续做某个需求、启动新事项、参加会议等

**修正已有内容**
- 「场景选择的状态改成测试中」→ 改状态标签
- 「灵动调节的版本号是 20.6.0」→ 补版本号

Updates can happen multiple times per day — each time, follow the same
search → read → ask → confirm → overwrite flow.

## Examples

### Example 1: Feature in Development

User says "写日报，猜你喜欢场景选择还在开发中"

**Draft:**
```markdown
# 20260602 | 日报
#tme/meeting/2026/06

## ❮ 昨天的进展
1、🔨 20.5.5 【推荐】猜你喜欢场景选择（开发中）
* 开发

## ❙ 今天的工作
1、🔨 20.5.5 【推荐】猜你喜欢场景选择（开发中）
* 开发

## ❯ 明天的计划
```

### Example 2: Mixed Item Types

User says "写日报。场景选择还在开发，另外有个问题跟进，OKR 方案在细化，下午参加了月会。"

**Draft:**
```markdown
# 20260602 | 日报
#tme/meeting/2026/06

## ❮ 昨天的进展
1、🔨 20.5.5 【推荐】猜你喜欢场景选择（开发中）
* 开发
2、🐛 20.5.0 - 问题跟进
* 体验问题跟进
3、🎯 OKR：AI-Coding
* AGENT.md 建设方案细化

## ❙ 今天的工作
1、🔨 20.5.5 【推荐】猜你喜欢场景选择（开发中）
* 开发
2、🐛 20.5.0 - 问题跟进
* 体验问题跟进
3、🎯 OKR：AI-Coding
* AGENT.md 建设方案细化
4、📌 参加月会

## ❯ 明天的计划
```

### Example 3: Feature Status Transitions

User says "写日报。场景选择开发完了，今天转体验。"

**Draft:**
```markdown
# 20260602 | 日报
#tme/meeting/2026/06

## ❮ 昨天的进展
1、🔨 20.5.5 【推荐】猜你喜欢场景选择（开发中）
* 开发

## ❙ 今天的工作
1、🔨 20.5.5 【推荐】猜你喜欢场景选择（转体验）
* 转体验

## ❯ 明天的计划
```

### Example 4: Weekly Report

User says "写周报"

Skill reads the week's daily reports and aggregates (no status tags in weekly):

**Draft:**
```markdown
# 20260605 | 周报
#tme/meeting/2026/06

## 本周的工作
1、🔨 20.5.5 【推荐】猜你喜欢场景选择
* 开发、转体验、体验问题跟进、跟测、数据上报
2、🔨 20.5.5 【推荐】猜你喜欢灵动调节改版
* 评估工作量、启动开发
3、🎯 OKR：AI-Coding
* AGENT.md 建设方案细化
```
