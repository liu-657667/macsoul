# 仓库卫生与初始化材料整理

日期：2026-09-28（Asia/Shanghai）。本轮只整理仓库入口、历史包材料和忽略规则；保留先前未提交的产品代码与任务进度。未提交或推送。

## 三类清单

| 类别 | 路径与决定 |
|---|---|
| 保留 | `MacSoul/`、`MacSoulTests/`、`MacSoul.xcodeproj/` 及共享 scheme、`.github/workflows/verify.yml`、`scripts/` 的构建/测试/进度入口、`LICENSE`、正式 `.xcassets` 和 `ThirdPartyNotices.txt`。保留 `AGENTS.md`、`CLAUDE.md`、当前产品/架构文档、`tasks.json`、生成的 `docs/STATUS.md`、必要的脱敏报告与审查材料。`reference/`、原七天基线和旧日报作为历史输入保留，不因数量多而删除。 |
| 归档 | 原根目录 `START-HERE.md`、`BUNDLE-CHECKS.json`、`BUNDLE-MANIFEST.json`、`MANIFEST.md`、`CODEX-DAY1-PROMPT.md`、`DAY1-DESIGN-LOCK.md`，以及 `prompts/KICKOFF.md`，移入 `docs/archive/bootstrap/`。原字节均与移动前 `HEAD` 完全相同；原包清单哈希未修改。移动对照见 `docs/archive/bootstrap/README.md`。 |
| 应忽略 | `.artifacts/`、`build-preview/`、`DerivedData/`、`build/`、`dist/`、`test-results/`、`coverage/`，Xcode 本地结果包和 App/归档/DMG/PKG、MacSoul ZIP 输出，以及 `.env*`、局部 Codex/Claude/Xcode 设置和私钥/签名文件。规则写入 `.gitignore`，没有忽略整个 `docs/`、`prompts/`、`reports/`、`review/`、PNG、JSON 或 `xcodeproj`。 |

`git ls-files -c -i --exclude-standard` 无输出；再按构建包、结果、日志、环境文件等路径筛选已跟踪文件也无结果。因此**本轮没有定向取消跟踪的路径**，未运行 `git rm --cached`，本地现有构建和测试文件继续保留在忽略目录中。曾有的 `reports/screenshots/day-1-soul-overview.png` 属于跟踪的历史截图证据，不作为待删除的构建产物。

## `assets-source` 分类

- 正式原稿：`assets-source/app-icon/macsoul-app-icon-source.png`、`assets-source/menu-bar/macsoul-menu-template-source.png` 和 `assets-source/soul/` 六态原图。菜单栏原稿及运行时图标仍为 DRAFT。
- 历史候选：`assets-source/reference/concept-*.png`、`selected-refinement.png`；`macsoul-product-hero.png` 是 README 概念主视觉，不是运行时 App 截图。
- 重复预览：`assets-source/preview/` 的资源总览、菜单栏草稿预览和深浅色对照图。它们不是新的正式原稿。
- `assets-source/asset-manifest.json` 仍驱动 `scripts/verify-visual-assets.py`；上述原稿、历史候选与预览都在交付清单中，本轮未删、未忽略、未改写资源哈希。

## 路径与历史校验

当前入口改为 `AGENTS.md`、`README.md`、`docs/STATUS.md` 和 `prompts/CONTINUE.md`；未完成 Phase A 仍可读 `prompts/BOOTSTRAP.md`。README、Claude 入口、原文映射、审查示例和 `scripts/check_bundle.py` 已指向归档路径。历史 Day 1 设计中的“四窗口必须同时显示”与当前动态窗口规则冲突，因此只归档，不再当作当前规范。

`python3 scripts/check_bundle.py --hashes` 检查 115 个原包条目，退出 1：3 条缺失（原包 `.codex` 文件）、41 条内容与原始包不同。此检查保留原始清单，不把开发后的仓库伪装成原封不动的初始化包；它不是当前 App 的构建门禁。项目级 `.codex/config.toml` 仍不存在，故其实际加载状态不可确认，本轮未创建或修改个人/全局配置。

## 验证

当前基底 revision `835c8870a9c5791c7375c85c1d8bac5b2a5d2ad9`，工作树指纹 `04a2c3098c4b97408cef19e9ff1d374d33f9d66a5a7ef83e8fcb4a4fbbe18aa7`；macOS 27.0、Xcode 27.0 (27A266a)。工作树含此前未提交的产品修订，revision 单独不代表这些改动。

| 检查 | 结果 | 证据 |
|---|---|---|
| 本工作树 `./scripts/verify.sh` | PASS，退出 0 | `.artifacts/verification.json`，UTC `2026-09-28T15:04:33.564289+00:00`；doctor/build/unit/progress/assets/ledger 均退出 0，21 个 XCTest、0 失败。 |
| 干净克隆叠加候选差异后 `./scripts/verify.sh` | PASS，退出 0 | `.artifacts/clean-clone-check.json`；本地克隆 `HEAD`，应用 `git diff --binary HEAD` 并复制未忽略的新文件；克隆中的指纹与本工作树相同，六项检查均通过。此验证代表待提交候选内容，不声称远端现有提交包含未提交改动。 |
| 资源静态检查 | PASS，退出 0 | 59 个交付文件、38 个 PNG 头、8 个资源集合；`.artifacts/visual-assets-check.json`。脚本中“Dock review is pending”是原交付快照的历史提示；负责人后续已单独确认 Dock PASS，静态脚本并未执行 Dock 目视检查。 |
| 归档字节比对 | PASS | 七个移动文件逐个与 `git show HEAD:<原路径>` 比较，字节一致；未改 `BUNDLE-MANIFEST.json`。 |
| 已跟踪本地产物筛查 | PASS | 无匹配路径；未取消跟踪任何文件。 |
| 本轮 manual UI / performance / live provider | NOT_RUN | 本轮未修改或重启运行中的 App，也未接真实采集。既有人工验收记录保持原状态。 |

## 建议提交内容

当前工作树还含上轮未提交的 Swift UI、测试、进度和验收报告修订。建议先由维护者核对这些内容，再将**当前已一起验证的候选内容**提交；其中仓库卫生部分是本轮归档移动、`.gitignore`、入口和路径修正、`scripts/check_bundle.py`、本报告及 `tasks.json` 的证据指纹更新。若要拆成“上轮功能修订”和“仓库卫生”两个提交，需要在每个提交状态重新运行验证并刷新账本指纹，否则单独克隆中账本证据会过期。提交前须把归档新路径与旧路径删除一同纳入 Git，勿只提交删除。此处仅给出建议，未执行 `git add`、commit 或 push。
