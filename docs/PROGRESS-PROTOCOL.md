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
