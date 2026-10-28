# HealthPet（健康陪伴宠物）· iOS 基础框架 v0.1

原生 SwiftUI，iOS 17+。宠物形象 v1 是「面包人」(toast)，但角色只是一层「皮肤」，可以随时替换。

## 跑起来

1. 安装 XcodeGen：`brew install xcodegen`
2. 在仓库根目录运行 `xcodegen generate`，打开生成的 `HealthPet.xcodeproj`
3. 在 Xcode 的 Signing 里选你的 Apple 开发者团队（HealthKit 需要签名）
4. 模拟器默认使用 **Demo data**（模拟器里没有健康数据）；在「Settings → Debug」可以切换四种心情看效果
5. 真机默认读 Apple Health，在「Settings → Connect」授权

核心逻辑的单元测试：`cd Packages/PetCore && swift test`（或在 Xcode 里 ⌘U）。

## 3D 面包人

首页的面包人是 3D 的，用苹果自带的 SceneKit 播放，没有第三方依赖。模型是「拆件绑骨」的刚体角色（身体、两只手、两只脚），带三段动画：待机放松 `idle`、开心跳 `happy`（拍拍时播放）、鞠躬 `bow`（打开首页时打招呼）。呼吸、漂浮、挥手、拍拍时的小跳是代码做的，会跟着心情变快变慢，睡觉时变暗变慢。

模型更新后重新导出（需要 Blender 3.4+）：

```
/Applications/Blender.app/Contents/MacOS/Blender -b --python tools/export_toast_rig.py -- \
  "<pet-3d/06_拆件绑骨 文件夹>" HealthPet/Resources/Models
```

「走路」动画会往前走（不是原地），暂时没用。

## 结构

```
Packages/PetCore/          与平台无关的核心逻辑（不依赖 HealthKit / SwiftUI，可单独测试）
  HealthSnapshot           统一的「每日健康数据」：步数、睡眠、HRV、静息心率、Whoop 恢复分
  PersonalBaseline         个人 30 天基线；HRV 只和同一种算法比较（Apple=SDNN，Whoop=RMSSD）
  PetStateEngine           健康数据 → 宠物状态（golden / burnt / soggy / fresh）
  Memories                 「共同回忆」相册的自动触发规则（第一次 2 万步、30/100/365 天纪念日）
HealthPet/                 iOS App
  Health/                  数据源适配器：HealthKit（已实现）、Whoop（走后端，待建）、Demo
  Character/               角色皮肤协议 + 面包人皮肤（换角色只需新增一个 CharacterSkin）
                           Toast3DSkin = 3D 面包人（默认），ToastSkin = 旧的 2D 图片版
  Resources/Models/        3D 面包人的网格、动画和贴图（由 tools/export_toast_rig.py 生成）
tools/                     从 pet-3d 的 GLB 导出 3D 面包人的 Blender 脚本
  Features/                首页 / 回忆相册 / 设置
```

## 已按设计基线落实的规则

- 首页不显示任何分数，点一下宠物（或右上角 Today）才看到数字
- 宠物的反应都相对于「你自己的平常水平」，不跟大众标准比
- 只有步数的用户也能得到正常的宠物状态
- 宠物在睡觉时间自动入睡，不需要手动点「一起睡」
- 每种状态下面包人的脸都是开心的

## 还没做 / 下一步

- Whoop：需要一个后端来完成 OAuth 和接收 webhook（client secret 不能放在 App 里）
- 入睡时间：目前是固定 23:00–7:00，之后改为根据真实入睡时间学习 + 手机闲置判断
- 本地存储目前用 UserDefaults，数据多了再换 SwiftData
- 后台刷新、通知、宠物之间的社交互动
