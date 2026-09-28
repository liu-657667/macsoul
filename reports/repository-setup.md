# 仓库初始化续办记录

日期：2026-09-28（Asia/Shanghai）。此记录描述本次仓库维护，不改变产品范围或 76 点原计划。

## 仓库与协议

- `.gitignore` 已包含在首次推送的 `d12ff5ce1329296a11a4db8790a52b3be1e0acd3` 中；本地和 GitHub `main` 在本次修改前同为该提交。
- 根目录原本没有 `LICENSE`，仓库内也未发现其他 `LICENSE`、`COPYING` 或 `NOTICE` 文件。负责人确认版权持有人为 `liu-657667`；本次加入标准 MIT 全文，署名 `Copyright (c) 2026 liu-657667`，并更新 README 与当前产品范围文档。
- `reference/` 的历史资料和概念素材，以及未来引入的第三方内容，不因项目的 MIT 决定而统一改标。

## 初始化续办

- 修正 `scripts/verify.sh` 的顺序：先生成本机命令证据，再检查 `tasks.json`。因此空的 `.artifacts/` 也可运行固定入口。
- 已准备 `.github/workflows/verify.yml` 草案，在 GitHub 的 macOS runner 上执行同一入口。首次推送因 PAT 缺少 `workflow` 权限被 GitHub 拒绝；负责人补齐权限后，以提交 `3d9466a` 推送成功。
- 更新 README、启动页和合并说明中的仓库现状，避免把已建立的 Xcode 工程称为尚不存在。历史 Phase A 报告保留其当时的事实。

## 本机验证

| 项目 | 结果 | 证据 |
|---|---|---|
| build | PASS | `./scripts/verify.sh` 退出 0；`.artifacts/build.log` 含 `BUILD SUCCEEDED` |
| unit | PASS | 同上；`.artifacts/test.log` 含 6 tests、0 failures |
| progress ledger | PASS | `.artifacts/progress-verify.log`：52 tasks、76 original points |
| 干净目录复核 | PASS | 排除 `.git` / `.artifacts` 的文件副本运行 `./scripts/verify.sh` 退出 0；`.artifacts/clean-checkout-final/.artifacts/verification.json` 的五项命令均为退出 0 |
| manual UI | NOT_RUN | 本次仅维护仓库与验证入口；负责人 Phase A 验收仍待进行 |
| performance | NOT_RUN | 未进行 Release 性能测量 |
| live provider | NOT_RUN | 仍为 Mock App |

后续远端验证：提交 `3d9466a` 的 [GitHub Actions 首轮运行](https://github.com/liu-657667/macsoul/actions/runs/36393204231) 于 2026-09-28 07:45 UTC 完成，macOS job 及 `Verify MacSoul` 步骤均为 success。此结果只证明该提交的远端验证，不替代人工 UI、性能或真实 Provider 验收。

本次验证对应的工作树指纹为 `7ae2a06230961aa763cea7d9e41a51b453b69b77ae178e0ff832f375df9131be`，记录在 `.artifacts/verification.json` 与 `tasks.json`。本机 `.artifacts/` 被 Git 忽略；其他机器及 GitHub CI 必须重新运行验证。
