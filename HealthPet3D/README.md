# HealthPet 3D（3D方案 · 测试版）

和 2D 版 HealthPet 并排安装的第二个 App（Bundle ID `com.healthpet.app3d`，桌面名字「HealthPet 3D」）。
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

## 结构

```
HealthPet3D/
  App/          入口、导航、HomeState（今天吃掉的食物、每天第一次醒来、新宠物小圆点、外观、名字）
  Design/       配色（Jade）、字体（SF Pro Rounded）、卡片和按钮
  Pet/          Pet3D（20 只宠物）、PetStage（活的 3D 宠物，WKWebView 里跑 pet.html）
  Model/        DayFacts：食物气泡、状态条、日历小点、宠物说的话
  Features/     Home · Today · Pets（含宠物详情）· Share · Memories · Settings
  Resources/    Assets（20 只宠物 × 正常/开心两张静态图、App 图标）、PetWeb/pet.html
  PetWeb/       pet.html 的源码和构建脚本（不进 App）
```

共用 2D 版的数据层（不复制）：`HealthPet/App/AppModel.swift`、`Health/`、`Store/`、`Backend/`、`Character/`，以及 `Packages/PetCore`。
两个 App 各自保存自己的数据（UserDefaults 按 App 分开）。

## 3D 宠物（pet.html）

- 一个离线网页：open-bot-avatar 0.1.2（MIT）+ 3D方案 表情引擎 engine.js + 活宠物导演 live.js（和预览页同一份代码，没有改）+ `PetWeb/src/bridge.js`（App 和宠物之间的接口）。
- 只有首页和宠物详情页的宠物是活的；Pets 格子和分享卡用静态图（由同一个 3D 宠物渲染）。
- 改了 `PetWeb/src/` 以后：`cd HealthPet3D/PetWeb && npm install && npm run build`，会重新生成 `Resources/PetWeb/pet.html`。
  重新渲染静态图和图标：`node tools/stills.js ../Resources/PetWeb/pet.html <输出目录>`（需要 Playwright）。
- 表情规则沿用预览：点一下随机害羞 / 吓一跳 / 歪头 / 眨眼，连点 3 下被挠痒，6 下晕乎乎，按住被摸摸；没人碰 45 秒犯困、2 分钟睡着；
  每天第一次打开播「醒来」；有新打卡时「打卡欢呼」；吃完所有食物「开心跳」；睡觉时间一到很快睡着；状态差的日子是「有点累」。

## 首页的数据

- 食物气泡：步数、活动消耗、每次运动（最多两个，图标是运动类型）、每日负荷。点一下飞进宠物嘴里；数据涨了会再长出来。
- 每日负荷：Whoop 用户直接用 Whoop 的 day strain；Apple Watch 没有可读的负荷分，用活动消耗 + 运动时长在手机上估算到 0–21（不叫 Strain）。
- 状态条（越满 = 休息得越好，不用红色）：恢复（Whoop 恢复分；Apple 用 HRV 对比自己过去 30 天 + 睡眠时长估算）、HRV（对比自己的平常）、入睡时间（按时 = 满）。
- 估算公式在 `Packages/PetCore/Sources/PetCore/DailyMetrics.swift`，有单元测试。

## 还没做

- Dress up（点了提示即将推出）、好友。
- 宠物详情里的等级只算活动次数；面包人的等级是亲密度。
- 分享卡没有 Milestone 那一张。
