---
title: "Orca 工作区参考与已确认决策"
version: "1.0.0"
status: "implemented"
type: "design-decision"
tags: [workspace, worktree, parallel-sessions, orca]
---

# 参考与决策

参考 [Orca Worktrees](https://www.onorca.dev/docs/model/worktrees) 及用户提供的侧栏截图。
用户确认：**后台真并行；新建会话默认留在当前 Worktree**。

采用项目 → Worktree / 主目录 → 会话三级结构；同目录会话共享文件，需隔离时显式新建 Worktree。会话、文件复用现有标签和并排宿主，不新造一套窗口系统。后台问答不抢焦点，创建 / 删除检查目录占用，删除默认保留分支。不扩展远程主机、PR、自动化及父子 Worktree 编排。

使用 Node 管理多个原生 Pi 会话，通过 PiChannelHub 共用一个物理 JSONL 连接。Flutter 不自行实现 Agent。复用 AppTreeTile、AppNavTile、AppDialog、AppTabWorkspace、AppSplitPanel 与 SlotContainer；保持空会话居中输入及原有主题 / 毛玻璃规则。

**当前入口、操作、数据结构、代码路径和验证记录统一见 [项目、Worktree 与并行会话](workspaces_sessions.md)**，本文件只保存设计来源与用户已确认的边界，不维护另一份实现说明。
