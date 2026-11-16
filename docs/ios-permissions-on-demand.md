# 权限按需申请对照表（iOS）

原则：**权限跟着功能走，不跟着启动走。** 冷启动不弹任何一个系统询问；
用户触发哪个功能，才在那个入口申请那一项。

## 启动路径

启动落在**户型页**（主导航最左），它只读「方位」，不需要相机、不需要动作传感器、
不需要经纬度以外的任何东西。因此冷启动的调用链是：

```
RootContentView.body.onAppear
  └─ updateResourceUsage()            // 不再无条件 motion.start()
       ├─ SensorPolicy.needsHeadingUpdates(.floorplan) = true  → 只启磁航向
       ├─ SensorPolicy.needsDeviceMotion(.floorplan)  = false → 不启动作传感器
       └─ CompassMotionManager.start() → 不再主动 requestWhenInUseAuthorization
```

结果：零弹窗。磁航向本身不需要定位授权，所以户型页的罗盘叠透照样能实时转。

## 逐项对照

| 权限 | Info.plist 键 | 触发时机 | 拒绝后的表现 | 代码位置 |
| --- | --- | --- | --- | --- |
| 相机 | `NSCameraUsageDescription` | 切到 AR 页（`isActive` 变真） | AR 勘测不可用，户型页不受影响 | `ARVisionView.checkCameraPermission()` |
| 位置（使用期间） | `NSLocationWhenInUseUsageDescription` | ① 切到 AR 页（磁偏角→真北）② 首次导出户型报告（真太阳时） | 只显示磁北；真太阳时留空 | `CompassMotionManager.requestLocationPermissionIfNeeded()`，调用点见 AR 页 `onAppear/onChange` 与 `FloorplanView.exportFloorplanReport()` |
| 运动与健身 | `NSMotionUsageDescription` | 切到 AR 页（俯仰/横滚、AR 姿态） | 姿态类读数停更 | `SensorPolicy.needsDeviceMotion` → `setDeviceMotionEnabled` |
| 相册（写入） | `NSPhotoLibraryAddUsageDescription` | 保存勘测快照或长图时 | 无法保存到相册 | `ARVisionView` 里 `PHPhotoLibrary.requestAuthorization(for: .addOnly)` |
| 相册（读取） | 已移除 | — | — | 户型图导入改用 `PHPickerViewController`（系统进程选择，不需要授权） |
| 通知 | 无需 Info.plist 键 | 用户主动打开「节气提醒」或「吉日提醒」 | 提醒不排程，页面提示去设置 | `BaZhaiEngine.setSolarTermNotifications` 等 |

## 三处具体改动

1. `Info.plist` 删掉 `NSPhotoLibraryUsageDescription`。户型图导入原本用
   `UIImagePickerController`，那要求「访问所有照片」；换成 PHPicker 后应用根本拿不到
   未选中的照片，这条用途说明保留只会让审核追问「为什么需要读整个相册」。
2. `CompassMotionManager.start()` 不再自动请求位置授权。它原先在每次启动都问，
   而真正需要经纬度的只有磁偏角与真太阳时两处。现在只「已经授权才开 GPS」，
   需要时由功能入口调用 `requestLocationPermissionIfNeeded()`（仅在 `.notDetermined` 时问）。
3. `RootContentView` 不再在 `onAppear` 里无条件 `motion.start()`，改由
   `updateResourceUsage()` 按当前页面的需要决定起哪一路传感器。

## 有意保留的行为

- 用户已经拒绝过的权限**不再重复询问**（`requestLocationPermissionIfNeeded` 有
  `.notDetermined` 守卫），恢复入口在设置页的「请求定位权限 / 打开系统设置」。
- 多窗口同时在前台时仍按 `SensorPolicy` 全开传感器：两个窗口各按自己的 Tab 置位会互相覆盖，
  宁可多耗电，也不让另一个窗口的罗盘停摆。
