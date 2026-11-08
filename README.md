# HealthPet（健康陪伴宠物）

原生 SwiftUI，iOS 17+。App 是 **HealthPet 3D**（3D方案：切片宠物 + v3「干净版」界面），代码和使用说明在 [`HealthPet3D/README.md`](HealthPet3D/README.md)。

## 仓库结构

```
HealthPet3D/         iOS App（scheme HealthPet3D）
Packages/PetCore/    与平台无关的规则和计算（不依赖 HealthKit / SwiftUI，可单独测试：cd Packages/PetCore && swift test）
backend/             Supabase 后端（Whoop 登录、同步）
Config/              构建配置（Supabase 地址和公开 key）
project.yml          XcodeGen 工程描述：xcodegen generate 生成 HealthPet.xcodeproj
```

## 2D 旧版（已停用）

2026-11-08 起 2D 版 HealthPet（早餐系 2D Q 版宠物、首页 v3.1）是废案，不再维护，代码已从 main 删掉。
最后一版保存在 Git 标签 **`2d-final`**（提交 `4030628`，当时 2D 和 3D 两个 App 都能编译）。需要时可以这样找回：

```
git checkout 2d-final        # 只看看，不影响 main
```

2D 版的设计稿和图片在项目文件「健康宠物/旧2D方案/」和 Figma「健康宠物/旧2D方案」里。
