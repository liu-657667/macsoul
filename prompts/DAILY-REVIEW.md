# 每次阶段结束 / 当日收尾

读取根目录规则、当前状态、任务账本、git diff/status 和本次实际生成的验证结果。
没有任务账本时先报告 Phase A 尚未结束，不根据模板生成虚假百分比。
核验完成声明、依赖、证据 revision/工作树指纹、未完成任务、质量风险与范围变更。
由脚本计算进度；Agent 解释原因。原始承诺与调整范围进度分开。

写入 `reports/day-N.md`（N 取当前实际计划，不按机器日期猜测），更新/生成 STATUS。
报告 build、unit、manual UI、performance、live provider 的各自状态；未跑就 NOT_RUN。
红黄状态先执行 `docs/PROGRESS-PROTOCOL.md`，写出下一次的追赶队列。
日历不会自动启动本提示；不承诺会话结束后主动继续执行。
