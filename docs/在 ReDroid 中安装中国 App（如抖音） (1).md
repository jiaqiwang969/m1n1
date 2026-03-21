# 在 ReDroid 中安装中国 App（如抖音）

ReDroid 是一个基于 Docker 的云端 Android 容器方案。由于其默认镜像不包含 Google Play 或国内应用市场，安装抖音等国内 App 需要手动操作。以下是几种主流方法：

## 方法一：直接通过 ADB 安装 APK（推荐）

这是最简单直接的方式。

**步骤：**

1. **获取抖音 APK 安装包**
   从可信来源下载 APK，例如：
   - [APKPure](https://apkpure.com)
   - [豌豆荚官网](https://www.wandoujia.com)
   - 抖音官网直接下载

2. **确保 ReDroid 容器正在运行**
   ```bash
   docker run -itd --rm --memory-swappiness=0 \
     --privileged \
     -v ~/data:/data \
     -p 5555:5555 \
     redroid/redroid:12.0.0-latest
   ```

3. **通过 ADB 连接容器**
   ```bash
   adb connect localhost:5555
   adb devices  # 确认连接成功
   ```

4. **安装 APK**
   ```bash
   adb install -r /path/to/douyin.apk
   ```

5. **启动 App（可选）**
   ```bash
   adb shell monkey -p com.ss.android.ugc.aweme 1
   ```

## 方法二：集成应用市场（如 F-Droid 或第三方市场）

可以在 ReDroid 中安装国内应用市场，然后通过市场下载 App。

**推荐的国内应用市场 APK：**
- 酷安（CoolApk）
- 华为应用市场
- 小米应用商店

安装方式同方法一，先用 ADB 安装市场 APK，再在市场内搜索下载抖音。

## 方法三：使用 scrcpy 可视化操作

安装 [scrcpy](https://github.com/Genymobile/scrcpy) 可以将 ReDroid 的画面投射到桌面，方便可视化操作：

```bash
# 安装 scrcpy（Ubuntu）
sudo apt install scrcpy

# 连接并投屏
adb connect localhost:5555
scrcpy
```

## 常见问题与注意事项

| 问题 | 解决方案 |
|------|----------|
| App 闪退 / 无法启动 | 抖音等 App 可能检测 root/虚拟环境，可尝试使用 `redroid` 的 Magisk 模块或 `shamiko` 隐藏 root |
| 缺少 Google 框架 | 部分 App 依赖 GMS，可集成 [MindTheGapps](https://github.com/MindTheGapps) 或 OpenGApps |
| 性能问题 | 确保宿主机开启 KVM 加速（`--device /dev/kvm`）|
| 网络问题 | 确保容器网络配置正确，国内 App 一般不需要特殊网络 |
| ARM App 在 x86 主机上无法运行 | 使用带 `houdini`（ARM 转译）的 ReDroid 镜像，如 `redroid:11.0.0_64only-latest` 配合 `redroid_arm_support` |

## 启用 ARM 转译（重要）

抖音等国内 App 通常包含 ARM 原生库，若宿主机是 x86 架构，需启用 ARM 转译：

```bash
# 使用支持 ARM 转译的镜像启动
docker run -itd --rm --memory-swappiness=0 \
  --privileged \
  -v ~/data:/data \
  -p 5555:5555 \
  redroid/redroid:12.0.0-latest \
  androidboot.redroid_gpu_mode=guest \
  ro.product.cpu.abilist=x86_64,x86,arm64-v8a,armeabi-v7a,armeabi
```

或参考 [redroid-doc](https://github.com/remote-android/redroid-doc) 中关于 `libndk_translation` 或 `libhoudini` 的集成说明。

**总结：** 最推荐的方式是直接从抖音官网或 APKPure 下载 APK，然后用 `adb install` 安装。如果遇到闪退，大概率是 ARM 转译或环境检测问题，按上述方案逐一排查即可。
