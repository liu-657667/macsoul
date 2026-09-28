# 初始化包归档

这里保存已退出当前执行流程的原始合并包清单与入口。当前开发从仓库根目录 `AGENTS.md`、`README.md`、由 `tasks.json` 生成的 `docs/STATUS.md` 和 `prompts/CONTINUE.md` 开始。

原路径到现路径：

| 原路径 | 归档路径 |
|---|---|
| `START-HERE.md` | `docs/archive/bootstrap/START-HERE.md` |
| `BUNDLE-CHECKS.json` | `docs/archive/bootstrap/BUNDLE-CHECKS.json` |
| `BUNDLE-MANIFEST.json` | `docs/archive/bootstrap/BUNDLE-MANIFEST.json` |
| `MANIFEST.md` | `docs/archive/bootstrap/MANIFEST.md` |
| `CODEX-DAY1-PROMPT.md` | `docs/archive/bootstrap/CODEX-DAY1-PROMPT.md` |
| `DAY1-DESIGN-LOCK.md` | `docs/archive/bootstrap/DAY1-DESIGN-LOCK.md` |
| `prompts/KICKOFF.md` | `docs/archive/bootstrap/prompts/KICKOFF.md` |

上述文件只移动，未改写原内容或历史 SHA-256 清单。`DAY1-DESIGN-LOCK.md` 中“四窗口必须同时显示”的说法是旧设计，当前以 `docs/INTEGRATION-NOTES.md`、`docs/SCOPE.md`、`docs/DESIGN.md` 和 `docs/AI-QUOTA.md` 的动态窗口规则为准。

`python3 scripts/check_bundle.py` 是历史包检查，会按本表寻找已移动文件；`--hashes` 继续以未改的原清单比较文件内容。当前项目的源码已变更，原包的 `.codex/config.toml` 也未导入，因此这项历史检查可以失败，不能通过改写清单伪装成最初包校验通过。当前构建、单测和任务证据使用 `./scripts/verify.sh`。
