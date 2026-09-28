# 从这里开始

本次是完整合并包，不用再找之前的三个 ZIP。

## 1. 放到本地 macsoul 项目

ZIP 解压后得到一个 `macsoul/` 文件夹。**它本身就是项目根目录**。
- 本地刚建的 `macsoul` 还是空的：可直接使用解压出来的这个文件夹作为项目。
- 已经放了旧包：先备份旧文件夹。没有自己修改过的代码/进度时，可用新包重新整理；有改动则先比较，不直接覆盖。
- 手动复制时，把解压后 `macsoul/` 里面的内容复制到你的项目；不要变成 `macsoul/macsoul/`。
- `.codex/` 和 `.gitignore` 是隐藏项目。不要漏掉；本包不含你的 `.git/` 或私人凭据。

最终这些路径应直接存在：

```text
macsoul/AGENTS.md
macsoul/CLAUDE.md
macsoul/START-HERE.md
macsoul/MacSoul/App/MacSoulApp.swift
macsoul/review/AUDIT.md
macsoul/review/CODEX-HARDENING-PROMPT.md
```

## 2. 在本机项目目录打开 AI

用你现有的 Codex / Claude Code 客户端打开此目录。不需要逐份上传文档，不要把所有文档一次塞进聊天。
选择你账户中实际可用的编程模型即可；本包不强制某个模型 ID，不修改全局配置。

首次只发送：

```text
先读取 START-HERE.md，再读取 prompts/BOOTSTRAP.md。
检查项目目录和现有文件，按文档只执行 Phase A。
保留我的现有代码、未提交改动和已有进度，不直接覆盖冲突文件。
结束时汇报修改内容、实际命令，以及 build / unit / manual UI / performance 各自的状态和证据。
```

## 3. 首次 AI 应当做什么

先建立设计一致性和可重复构建，再修正 Mock 数据契约，最后建立任务账本与证据检查。
`review/CODEX-HARDENING-PROMPT.md` 是 Phase A 的详细任务，`review/AUDIT.md` 是为什么要改。

此阶段不连接真实 AI 配额或公网 IP，不扫描磁盘，不杀进程，不做 Notch，不清理真实数据。
只对当前任务需要的文件进行修改。全局工具安装、改账号配置、推送 GitHub、签名发布都不是本次默认授权。

## 4. 你需要验收什么

AI 报告代码写完，不等于 App 已验收：
- 构建与单测：必须有本机命令、退出码和日志。
- 手工 UI：你实际打开 App，检查主窗口和菜单栏；两家各有 5h + Week。
- Mock 模式：有明显标记；改 fixture 时数字与进度一起变。
- 性能/真实额度/发布签名：未做就写 NOT_RUN，不允许假报通过。

`BUNDLE-CHECKS.json` 只证明这个合并包的检查，不是你本机 App 的验证结果。

## 5. 下一次怎么继续

```text
读取 prompts/CONTINUE.md。
先检查 Phase A 和当前进度，继续最高优先级、依赖已满足的当前任务。
对没有证据的完成状态重新验证；结束时更新报告。
```

Phase A 没结束就继续 Phase A；结束后先给你看结果，不自动一次跑完七天。
七天任务仍在 `docs/7-DAY-PLAN.md`；Phase A 迁移为结构化任务后，再据真实依赖执行。
`review/tasks.example.json` 只是示例，不是已经批准或完成的计划。

## 可选：检查是否漏复制文件

在项目根目录运行 `python3 scripts/check_bundle.py`。
首次刚解压时可加 `--hashes` 检查初始文件字节。开始修改后不要把初始哈希不一致误判成产品 Bug。
