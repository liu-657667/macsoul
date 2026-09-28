# 任务进度、每日汇报与追赶

目标：七天内交付可验证的 MacSoul 起步版本。七天是目标，不是订阅/模型保证。
当前先执行 Phase A；不要把包装/复制文档计作应用功能完成。

## 状态来源

Phase A 建立 `tasks.json` 后，它是任务状态唯一写入源，STATUS 由脚本生成。
在它建立前，保留初始 STATUS，不从示例 schema 推断开发完成率。
迁移保留原任务、原点数/日期、依赖、验收与历史记录。原计划基线在 `reference/originals/harness/docs/7-DAY-PLAN.md`。

状态：todo → doing → verifying → done；另外有 blocked / deferred。
done 要有对应验收、真实命令/退出码、revision/工作树指纹和证据。UI 人工确认独立记录。
代码变化后失效证据不能继续证明完成。fallback 测试与真实 Provider 测试不是同一任务。

## 每次会话收尾 / 每日检查点

报告：计划与实际任务 ID、已验收/未验收、未完成原因、验证命令与证据、风险、下次第一项。
保留 build / unit / manual UI / performance / live provider 的各自状态；未做就 NOT_RUN。
写当前 `reports/day-N.md`，真实模型可见时记录，不可见则 UNKNOWN。
脚本计算百分比，Agent 解释原因；不为写日报固定调用多个模型。

同时报告：原始承诺验收率、批准调整后验收率、延期项。不得删未完成项或改分母造绿。
相对点数不是小时；Day 是检查点，不是自动计时器。

## 排程与追赶

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
Day 5 后冻结功能；Day 6/7 只修复、验收与发布准备。发布行为需单独授权。
没有持续运行的会话/运行器就不会自动触发本流程，不承诺退出后继续开发或主动发日报。

## Phase A 可执行账本

`tasks.json` 为唯一状态写入源。原七天计划 48 个计分项、76 点按原文迁移，Phase A 的 A1–A4 为 0 个新增原计划点。`python3 scripts/generate_status.py` 生成状态页；`python3 scripts/verify_progress.py` 检查依赖、基线、状态、延期批准、done 证据及指纹。`./scripts/verify.sh` 保存本机 build/unit 与检查日志。证据目录 `.artifacts/` 被 Git 忽略；跨机器需要重新执行验证。人工 UI 确认必须单独记录，不由截图或 Agent 浏览代替。
