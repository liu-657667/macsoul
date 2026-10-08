# 任务进度、每日汇报与追赶

> 当前 validator 逐条要求 done evidence 与当前全局 fingerprint 相同；旧 Owner UI/Live/性能/Archive 记录不能批量改指纹沿用。文档/生成器也可能参与 fingerprint。需更改受控输入时先制作隔离候选和具体证据处理方案，原验收指纹、原始记录与人工确认保持不变。

原七天目标已在批准范围内完成：48 项 done、76/76。v0.1.0 已公开发行，见 [RELEASE](RELEASE.md)。全账本仍保留增量 verifying 项，不自动重开 Phase A / Day 7，也不代表所有任务均关闭。维护按 Owner 当前授权执行；包装/复制文档不能替代应用验收。

## 状态来源

`tasks.json` 是任务状态唯一写入源，STATUS 由脚本生成。初始 STATUS / 示例 schema 属历史，不能用来推断当前完成率。
迁移保留原任务、原点数/日期、依赖、验收与历史记录。当前账本锁定的原计划基线为 `docs/7-DAY-PLAN.md`，不得改动；`reference/originals/harness/docs/7-DAY-PLAN.md` 是初始输入副本。

状态：todo → doing → verifying → done；另外有 blocked / deferred。
done 要有对应验收、真实命令/退出码、revision/工作树指纹和证据。UI 人工确认独立记录。
代码变化后失效证据不能继续证明完成。fallback 测试与真实 Provider 测试不是同一任务。

## 每次会话收尾 / 每日检查点

报告：计划与实际任务 ID、已验收/未验收、未完成原因、验证命令与证据、风险、下次第一项。
保留 build / unit / manual UI / performance / live provider 的各自状态；未做就 NOT_RUN。
在授权需要记录时更新对应实际日期报告，见 [报告导航](../reports/README.md)。`reports/day-2.md` 至 `day-7.md` 是未使用模板，不覆盖它们制造第二份验收报告。真实模型可见时记录，不可见则 UNKNOWN。
脚本计算百分比，Agent 解释原因；不为写日报固定调用多个模型。

同时报告：原始承诺验收率、批准调整后验收率、延期项。不得删未完成项或改分母造绿。
相对点数不是小时；Day 是检查点，不是自动计时器。

## 原七天排程与追赶规则 — Historical

先修构建/运行回归 → 核心依赖 blocker → 验收 → 当前 ready 核心任务 → 已批准可选项。
RED 优先：release-blocking regression、多项未完成 P0 或低于原基线 70%。
YELLOW：未命中 RED，但有 1 项遗留 P0 或验收比例低于 90%。
GREEN：不存在上述风险且相关检查全部通过。未开始、不知道容量时用 NOT_STARTED/UNKNOWN，不预先报绿。
颜色是提示，不替代具体 blocker 和关键路径；由真实里程碑基线计算，不按当天钟点猜测。

RED、连续两个 YELLOW，或 carry-over 超过次日容量约 40% 时进入 Recovery：
1. 冻结 P2，不开始 Notch/新模块。
2. 保持测试、性能、隐私、错误处理。
3. 对可选 Cleaner/地域信息/额外适配提出延期并记账。
4. 核心需求缩减要负责人明确决定；AI 不默默把 unavailable 算完成。
5. 每次只解决当前最高优先级可行任务。复杂阻塞先收集证据，再考虑更强模型或审查。

不要为追赶自动提高权限、开启更频繁轮询或并发修改同一文件。
原计划 Day 5 后冻结功能；Day 6/7 只修复、验收与发布准备。该阶段已结束；当前维护不因旧排程启动功能。任何新的发布行为仍需单独授权。
没有持续运行的会话/运行器就不会自动触发本流程，不承诺退出后继续开发或主动发日报。

## 可执行账本与历史证据归属

`tasks.json` 为唯一状态写入源。原七天计划 48 个计分项、76 点按原文迁移，Phase A 的 A1–A4 为 0 个新增原计划点。`python3 scripts/generate_status.py` 生成状态页；`python3 scripts/verify_progress.py` 检查依赖、基线、状态、延期批准、done 证据及指纹。`./scripts/verify.sh` 保存本机 build/unit 与检查日志。证据目录 `.artifacts/` 被 Git 忽略；跨机器需要重新执行验证。人工 UI 确认必须单独记录，不由截图或 Agent 浏览代替。

## Fixed v0.1.0 maintenance contract

This is one fixed maintenance contract, not a general evidence migration framework.
Review checkpoint (2026-10-08): the candidate had no final Owner authorization.
That dated checkpoint does not determine a future decision record’s actual state.
Default validation still requires current full-fingerprint evidence. The unchanged
`tasks.json` keeps all original task/evidence/history/human flags and the eight
verifying states; generated STATUS describes those states, not approval of this
candidate.

The historical complete-input baseline is
`b7ca041e0a07623113534e577301f7c3c313df26`, fingerprint
`1c60e81ec22795ba49bac7877309e57f534e2bc1d21911dcddef9adb171fb067`.
The implementation base is PR #13's actual merge commit
`51f0c0d3a1361ac5ac7ceac52b84175f71ff78e0`. The old five-file candidate and
its `8dd20…` fingerprint are historical, not the new implementation identity.

[The declaration](evidence/v0.1.0-doc-maintenance.json) lists the exact payload,
complete before/after components and all 70 original evidence entries. Its target
is calculated after implementation. `verify_doc_maintenance.py prepare` explicitly
fetches only missing fixed public objects; validation itself has no network path.
Missing or mismatched objects fail. Full baseline bytes are independently hashed,
then compared with current input names/content. Production/resources/project,
locked plan, ledger and all content outside the explicit payload remain unchanged.
The only product-test exception is `MacSoulTests/NetworkTests.swift`: the
Owner-authorized CI-02 completion synchronization and deterministic fake-client
regression. Its exact before/after bytes and modes are a distinct payload entry;
other product tests remain unchanged. This does not change runtime behavior or
reopen RC human/Live/performance/Archive acceptance.

The payload digest is SHA256 of canonical UTF-8 sorted JSON path/before/after
file-SHA256 and Git mode records, relative to the implementation base. It includes the eleven
implementation payload paths (including generated STATUS and the one explicit test file); the external declaration and fixed decision record are excluded.
The declaration's own exact-byte SHA256 is recorded outside it, alongside the
complete delivery patch SHA256. Neither is embedded into itself. No fingerprint
inputs/exclusions change. No unknown successor, chain, wildcard, new task or
mapping outside the enumerated entries can reuse this exception.

48 references map exact task/acceptance/index/original-entry hash/check/command to
one real new automatic manifest, not 48 independent runs. The runner records
actual revision, full fingerprint, payload/declaration identity, commands, exit
codes and log hashes after execution. Doctor/build/unit/progress/assets/document
checks precede ledger; ledger's result is appended afterward, never predeclared.
The 15 scope and 7 Day 7 report references bind fixed baseline report sections,
original source/time/result/scope and entry identity. They retain historical
Owner/Live/performance/Archive attribution; new CI cannot manufacture those runs.
Historical D7-05 RC/version/license review coexists with new document consistency,
link and generator checks. Raw RSS REVIEW, finite Owner REVIEW ACCEPTED and all
NOT_RUN / NOT_OBSERVED / Deferred boundaries stay unchanged.

Integrity PASS is separate from authorization. Coverage requires an explicit,
externally reviewed decision binding from/to fingerprints, both fixed revisions,
payload SHA256 and exact declaration SHA256 plus a real, nonblank review reference.

The only future decision location is `docs/evidence/v0.1.0-owner-decision.json`,
a separate ordinary file (Git mode 100644). This candidate ships no decision file;
the previous PENDING template is retained only in ignored historical evidence.
Absence means `PENDING_FINAL_OWNER_DECISION`. If present, the actual record must
be an exact JSON object with these keys: `decision`, `review_reference`,
`historical_baseline`, `implementation_base`, `from_fingerprint`, `to_fingerprint`,
`payload_sha256`, `declaration_sha256`. PENDING requires a null review reference;
ACCEPTED requires an actual nonblank string. All identity fields must equal the
independently verified fixed declaration. Unknown fields, wrong identity, invalid
structure, symlinks or executable modes fail. The declaration lists this one
future path explicitly; no directory-wide exemption exists.

The record is excluded from existing fingerprint inputs and the eleven-path payload,
independently hashed when present in the review object/manifest, and never hashes
itself. Only a later explicit Owner decision and recording authorization may
create an ACCEPTED record with the real review reference and unchanged identity
tuple. The runner neither creates nor modifies it. JSON identity comparison does
**not** authenticate the Owner; recording the external decision remains human
governance, and old RC acceptance or implementation permission is insufficient.

Existing CI already calls `./scripts/verify.sh`; no workflow change is needed.
When the fixed file exists the runner explicitly forwards it to ledger. Equivalent
explicit usage is `./scripts/verify.sh --owner-decision docs/evidence/v0.1.0-owner-decision.json`.
Direct ledger also reads the same default fixed file, or the identical explicit
argument. Unknown arguments/arbitrary paths fail. Missing, PENDING, mismatched,
illegal or TEST_FIXTURE_ONLY decisions do not enable coverage. The actual argv,
command, record digest/state, exit and log digest are recorded. A failed current
manifest creation cannot reuse a prior manifest.

The delivered patch has no decision file. A later separately authorized record
creates a new record/tree/patch identity; the reviewed implementation payload and
declaration remain unchanged. The record does not contain its own hash, patch
hash or review-object hash, avoiding self-reference. It cannot authorize a new
implementation, arbitrary successor, mapping or outside file.

Run `python3 scripts/verify_doc_maintenance.py check` for offline integrity/docs,
and `./scripts/verify.sh` for current automatic checks. Without the exact real
Owner decision, ledger exit1 with PENDING_FINAL_OWNER_DECISION is refusal, not a
completed transition. Under a valid separately recorded decision the same code
path can pass; no script or protocol text change is required to use it.

Tests retain the original six negative structural cases, real 51-done/70-entry
mapping fixtures, both non-main checkout shapes and exact missing-object reasons.
The normal shell runner is exercised with real integrity/mapping/ledger logic,
heavy command outcomes simulated through ignored tools in a temporary repository,
and a test-only injected decision reader that explicitly marks simulation. It does
not alter production scripts or add a production bypass flag. Without that test
injection, production CLI still rejects TEST_FIXTURE_ONLY records. These simulated
runner PASS results are neither fresh actual build/unit results nor Owner approval.

### Complete scope and immutable object rules

Read fixed Git commit/tree/blob objects directly with replacement objects disabled; export-ignore does not filter
the baseline. Compare all paths in implementation base, HEAD, index and working
files, including outside fingerprint inputs. The CI-01/CI-02 candidate changes twelve paths (eleven payload files and declaration);
the future decision is a thirteenth individually constrained path, currently absent.
The real Owner decision committed at `112e4dc78d6165bcc0145ead3241470a363ee891`
binds only the earlier exact candidate. It is retained as history there, excluded
from this candidate, and cannot authorize these new bytes. This remains a direct
original RC fingerprint → exact new candidate mapping, not a migration chain.
Outside paths must retain baseline content, Git mode and type in all three states;
new untracked, staged or committed paths fail. Payload index/HEAD may match base
or exact current candidate; a third staged version fails. Decision-only updates
retain the exact identity tuple. Conflicts, symlinks (including ancestors/ignored
targets), nonregular files and record executable modes fail. Missing baseline
objects fail offline; only the explicit prepare entry can fetch them.

Shallow fixtures transport both fixed baseline and implementation commits from
the explicitly prepared local source before checkout, validating their commit,
tree and blob objects. Initial clones use `--no-local`, with no shared-object
alternates. Depth-one committed descendant feature and detached two-parent
synthetic-merge topologies reproduce the previous missing-implementation checkout
failure and verify the repair without any local main or advertised base refs.
Full progress tests also run in both isolated committed shapes. Missing historical
objects and incorrect objects continue to fail; validators never fetch network. Runner positive argument probes use isolated stub
dependencies only; the production CLI always rejects TEST_FIXTURE_ONLY records.

The runner records baseline preparation separately from document-check exit codes; a failed manifest receipt write also fails the runner. No failed preparation is mislabeled as the document-check command outcome.
