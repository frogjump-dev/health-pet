# HealthPet 3D（3D方案 · 测试版）

现在仓库里唯一的 App（Bundle ID `com.healthpet.app3d`，桌面名字「HealthPet 3D」）。2D 版 HealthPet 已在 2026-11-08 停用，见仓库根目录 README。
界面是最终版 v3「干净版」· Mountain Jade 配色（白天）/ 森林夜（黑夜），宠物是 3D方案 的切片宠物，带 26 个表情。

## 在 Mac 上跑起来

1. 终端进入仓库：`cd ~/Developer/health-pet`
2. 生成 Xcode 工程：`xcodegen generate`（XcodeGen 在 `~/Developer/tools/xcodegen-dl/xcodegen/bin/xcodegen`）
3. 打开 `HealthPet.xcodeproj`，左上角的 scheme 选 **HealthPet3D**，设备选 **iPhone 18 Pro**（iOS 27.0）
4. 按 ⌘R 运行。模拟器里默认用 Demo 数据；右上角「…」→ Settings → Test build 可以切换数据和 Demo 的四种日子
5. 测完马上退出：模拟器 ⌘Q，Xcode 里按 ⌘. 停止（Mac 会发热）

命令行构建（不开 Xcode）：

```
xcodebuild -project HealthPet.xcodeproj -scheme HealthPet3D \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES build
```

模拟器截图（不开 Simulator.app，结束时自动关掉模拟器）：上面的命令加 `-derivedDataPath build/dd` 构建，然后
`HealthPet3D/tools/sim-shots.sh <模拟器 UDID> <输出目录>`。每次启动的日志在输出目录的 `console-*.log`，
`[pet]` 开头的行是宠物网页的加载用时和报错。

## 结构

```
HealthPet3D/
  App/          入口、导航、HomeState（今天吃掉的食物、每天第一次醒来、新宠物小圆点、外观、名字）、通知
  Design/       配色（Jade）、字体（SF Pro Rounded）、卡片和按钮
  Pet/          Pet3D（20 只宠物）、RosterPet（宠物名单和对应的运动）、PetStage（活的 3D 宠物，WKWebView 里跑 pet.html）
  Model/        AppModel（汇总所有数据源、算出宠物状态）、DayFacts（食物气泡、状态条、日历小点、宠物说的话）、Progress
  Health/       数据源：HealthKit、Whoop（走 Supabase 后端）、Demo
  Store/        PetStore：存在手机上的领养日、回忆、自律周、运动记录、请假日、健康数据缓存
  Backend/      Supabase 客户端（Whoop 登录和同步）
  Features/     Home · Today · Pets（含宠物详情）· Share · Memories · Settings
  Resources/    Assets（20 只宠物 × 正常/开心两张静态图、App 图标）、PetWeb/pet.html
  PetWeb/       pet.html 的源码和构建脚本（不进 App）
```

规则和计算（自律周、宠物等级、精力、成就账本、分享称号……）在 `Packages/PetCore`，可以单独跑测试：`cd Packages/PetCore && swift test`。

## 3D 宠物（pet.html）

- 一个离线网页：open-bot-avatar 0.1.2（MIT）+ 3D方案 表情引擎 engine.js + 活宠物导演 live.js（和预览页同一份代码，没有改）+ `PetWeb/src/bridge.js`（App 和宠物之间的接口）。
- 只有首页和宠物详情页的宠物是活的；Pets 格子和分享卡用静态图（由同一个 3D 宠物渲染）。
  网页启动要一点时间，这期间同一位置先显示静态图，宠物画出来后淡掉；iOS 在后台回收了网页进程时会自动重新加载。
- 改了 `PetWeb/src/` 以后：`cd HealthPet3D/PetWeb && npm install && npm run build`，会重新生成 `Resources/PetWeb/pet.html`。
  重新渲染静态图和图标：`node tools/stills.js ../Resources/PetWeb/pet.html <输出目录>`（需要 Playwright）。
- 表情规则沿用预览：点一下随机害羞 / 吓一跳 / 歪头 / 眨眼，连点 3 下被挠痒，6 下晕乎乎，按住被摸摸；没人碰 45 秒犯困、2 分钟睡着；
  每天第一次打开播「醒来」；有新打卡时「打卡欢呼」；吃完所有食物「开心跳」；睡觉时间一到很快睡着；状态差的日子是「有点累」。

## 按 PRD v0.2 做了什么（2026-11-08）

PRD：「健康宠物 3D 方案 · PRD v0.2」（Claude Doc）。设计稿：项目文件 `健康宠物/3D方案/ui-final-v3/home-v3.2-share-v2/`。

- **主页 v3.2**：状态区没有数字，只有「月亮 + 入睡时间 + 勾」（准时才打勾，晚了只显示时间）和一条休息条；HRV 条去掉；
  Apple 用户的休息条是 App 自己估的 Rest，Whoop 用户是 Whoop 恢复分，右边标 WHOOP。负荷泡泡只在有 Whoop strain 时出现。
  「…」里只有 Settings（好友占位去掉）。一周固定周一开始。
- **宠物慢变状态（元气 / 平常 / 没电）**：按最近 7 天的准时夜、运动次数、Rest 均值各占三分之一（`PetCore/PetEnergy.swift`）。
  元气多哼歌、开心跳、星星眼；没电多打哈欠、发呆、伸懒腰，脚下椭圆变淡，点它先给你打气。只改待机动作和椭圆，不改任何数值。
  Settings → Test build → Pet energy 可以手动切三档看效果。
- **面包人等级 = 累计自律周数**；亲密度（拍拍 / 零食）不再用，喂食只是动画。
- **能量棒** 改成「连续两天训练量匹配恢复」：一串匹配的日子里每两天算一次（`ActivityTracker.withBalancedStreaks`）。
- **请假日**：Today 的 Sleep 卡上可以把昨晚标成请假（每周 1 次，算一个准时夜，再点一下取消）。
- **睡眠目标**：半小时档位（20:00–02:00），周末（周五、周六晚）可以单独设；设置会保存。
- **Pets** 只平铺已解锁的（面包人第一，其余按等级），没遇见的收进一个「+N」入口；没连 Whoop 不显示补给小队。
- **Memories = 成就账本**（`PetCore/Ledger.swift`）：每个自律周、月度成就、每次解锁、Lv 10 / 20、30 / 100 个准时夜、100 次运动、第一个 2 万步日、在一起 30 / 100 / 365 天。
- **分享卡 v2**：印章 + 身份标题（如 Early-to-bed Runner，`PetCore/ShareIdentity.swift`）+ 一行人话 + 三只宠物（主宠居中骄傲挺胸、都带 Lv）
  + 累计自律周数做最大的数字 + 名字 · 日期 · HealthPet。达成自律周时，主页庆祝完自动弹出这张卡（Share / Not now）。
- **首次打开**：连 Apple Health → 「Your last 30 days」展示过去 30 天已经解锁的宠物和等级 → 选目标入睡时间 → 主页。
- **早上揭晓**：每天第一次打开，醒来之后：准时 = 骄傲挺胸 + 「On time last night ✓」；有宠物升级 = 开心跳；断签回来 = 给你打气。
- **接上的表情**：困惑（今天没拿到手表数据）、星星眼（新宠物加入）、骄傲挺胸（早上揭晓）、给你打气（断签回来 / 差一点到 1 万步）、
  喜欢你（在一起 7 / 30 / 100 / 365 天、第一个自律周）。「有点失落」不用。
- **两条通知**（Settings → Notifications，默认关）：睡前 30 分钟「Toast is getting sleepy」、起床时间「See how last night went」。
- **活宠物只有一个 WKWebView**：App 启动就在后台加载 pet.html（预热），主页和宠物详情轮流用同一个（`Pet/PetStage.swift`）。

## 首页的数据

- 食物气泡：步数、活动消耗、每次运动（最多两个，图标是运动类型）；有 Whoop 时再加当天 strain。点一下飞进宠物嘴里；数据涨了会再长出来。
- 休息：Whoop 用户直接用 Whoop 恢复分；Apple 用 HRV 对比自己过去 30 天（60%）+ 睡眠时长（40%）估算，界面叫 Rest。
- 估算公式在 `Packages/PetCore/Sources/PetCore/DailyMetrics.swift`，有单元测试（Linux 上也能跑：`cd Packages/PetCore && swift test`）。

## 还没做

- 小装饰品（Dress up 还是占位，样式待设计，PRD §5.4）。
- 分享卡的 Milestone 卡、数据详情页。
