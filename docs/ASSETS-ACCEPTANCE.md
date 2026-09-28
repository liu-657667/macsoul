# MacSoul 视觉资源验收

本清单用于现有任务账本中的资源接入任务。不要重置七天计划，也不要创建第二份权威进度表。

## 静态检查（包内已执行，可在本机复跑）

```bash
python3 scripts/verify-visual-assets.py
```

检查交付清单内文件、SHA-256、PNG 尺寸/通道、8 个 asset 的 JSON/文件引用、AppIcon 10 个 macOS 槽位，以及 Soul 与菜单栏 scale 对应关系。静态校验不能证明 Xcode 成功加载。

## 构建与 target

- [ ] 现有代码与未提交改动保留，没有误替换 MacSoul 目录。
- [ ] `MacSoulBrand.xcassets` 进入正确 App target。
- [ ] App Icon Source 对应 `MacSoulAppIcon`，没有重复名称造成的资源冲突。
- [ ] 构建没有缺图、重复 asset、未分配图槽位警告。
- [ ] `.app` 不包含 assets-source 原稿、海报、预览与开发文档。

## 界面

- [ ] Mock 数据模式仍明确标识；图片切换不冒充系统监控已经完成。
- [ ] 六状态同一 frame、scaledToFit；不挤压、不截断、不明显跳位。
- [ ] 正常 / 忙碌 / 过载 / 胃撑 / 低电量 / 休息均能通过 fixture 切换。
- [ ] CPU 过载与内存压力使用正确图片；业务触发沿用现有 SoulEngine。
- [ ] 112–160 pt 主窗口、40–56 pt popover 的彩色 Soul 在浅深主题可读。
- [ ] Alpha 区域没有额外黑色矩形；源图蓝紫光晕若在浅背景显脏，列为美术修订项。
- [ ] AppIcon 在 Dock、Finder 小尺寸可识别，外侧不透明展示背景是否可接受由用户确认。
- [ ] 菜单栏候选在实际 18 pt、Retina/可获得的非 Retina 环境浅深主题检查；不是看放大图就批准。
- [ ] 菜单栏候选不清楚时保留旧入口，记录 DRAFT_NOT_APPROVED。
- [ ] 状态文字提供同等信息；装饰图片不造成读屏重复；非装饰图有 label。
- [ ] 没有新增常驻动效 timer；减少动态效果时不抖动/呼吸。

## 证据与完成规则

- 记录实际构建命令、退出码、revision/工作树指纹、截图/录屏位置、测试环境。
- `static / build / manual UI / performance` 分别标记 PASS、FAIL 或 NOT_RUN。
- 只看到 PNG 正常不等于 UI PASS；只编译成功不等于 Dock PASS。
- 菜单栏 Draft 可以和其他图片一起进入开发候选，但不能把它汇报为“正式模板已完成”。
- 不提交个人绝对路径、账户/IP 信息和未脱敏日志；图片预览使用 fixture。

## 初始状态

STATIC：随 packaging-checks.json 查看实际结果。
XCODE / ACTOOL：NOT_RUN。
APP / DOCK / MENU BAR / ACCESSIBILITY：NOT_RUN。
PERFORMANCE：NOT_RUN。
MENU TEMPLATE FINAL DESIGN：NOT_APPROVED。
