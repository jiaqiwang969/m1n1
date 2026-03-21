# 在当前 Redroid/Asahi 基线上安装中国 App

这份说明只针对本仓库当前已经验证过的环境，不是通用 Redroid 教程。

## 先认清当前主线

当前仓库的推荐基线只有一条：

- `16K` Asahi host
- `4K` microVM guest
- Redroid 运行在 `4K` guest 里

对应环境：

- host: `wjq@192.168.1.107`
- guest dir: `/home/wjq/vm4k/ubuntu24k`
- guest page size: `4096`
- Guest4K image: `localhost/redroid4k-root:alsa-hal-ranchu-exp2`
- Guest4K container: `redroid16kguestprobe`
- Guest4K ADB: `127.0.0.1:5556`
- Guest4K VNC: `127.0.0.1:5901`
- operator: `redroid/scripts/redroid_guest4k_107.sh`

当前 Guest4K 里和抖音直接相关的轻量动作有：

- `douyin-install`
- `douyin-start`
- `douyin-diagnose`

当前这条基线已经验证到：

- `init.svc.vendor.hwcomposer-3=running`
- `init.svc.surfaceflinger=running`
- `sys.boot_completed=1`
- Guest4K 音频链路可用：
  - QEMU HDA -> guest ALSA -> Android AudioFlinger -> PipeWire
  - `redroid_guest4k_107.sh restart` 会把 guest `/dev/snd/*` 修成 `root:audio(1005) 0660`
  - `redroid_guest4k_107.sh restart-preserve-data` 可在保留 `/data` 的前提下重建容器，并继续先执行 guest `setenforce 0`
  - 这里不能再误用 `1041`，因为那是 `audioserver` 的 UID，不是实际播放进程持有的 GID

所以如果你要继续做中国 App 安装和运行验证，默认就应该从 Guest4K 开始。

## 什么时候还提 direct-host 16K

旧的直跑 `16K` 路线没有被删除，但它已经不是推荐主线。

它现在只在一种情况下还值得提：

- 你明确要复用旧脚本里还没迁移到 Guest4K 的抖音专项 helper

这些旧 helper 还在：

- `douyin-compat`
- `douyin-libtnet-status`
- `douyin-libtnet-install`
- `douyin-libtnet-verify`
- `douyin-libtnet-restore`
- `phone-mode`

除此之外，不要再把直跑 `16K` 当成新工作的默认入口。

## 1. 先把 Guest4K 拉到已知正确状态

```bash
export SUDO_PASS='...'

zsh redroid/scripts/redroid_guest4k_107.sh vm-start
zsh redroid/scripts/redroid_guest4k_107.sh restart
zsh redroid/scripts/redroid_guest4k_107.sh verify
```

如果你已经装好了 App，不想清空 Guest4K 里的 `/data`，改用：

```bash
zsh redroid/scripts/redroid_guest4k_107.sh restart-preserve-data
zsh redroid/scripts/redroid_guest4k_107.sh verify
```

期望结果：

- guest `getconf PAGE_SIZE=4096`
- `adb connect 127.0.0.1:5556` 正常
- `sys.boot_completed=1`
- `127.0.0.1:5901` 返回 `RFB` banner

## 2. 安装 APK

推荐先用脚本入口。

如果 APK 在你当前这台电脑上：

```bash
LOCAL_DOUYIN_APK_PATH=/path/to/douyin.apk \
zsh redroid/scripts/redroid_guest4k_107.sh douyin-install
```

如果 APK 已经在宿主机 `192.168.1.107:/tmp/douyin.apk`：

```bash
zsh redroid/scripts/redroid_guest4k_107.sh douyin-install
```

它底层最终仍然会在 `107` 上执行 `adb install -r`。

如果你要直接手敲命令，也可以这样做：

```bash
ssh wjq@192.168.1.107 \
  "adb connect 127.0.0.1:5556 >/dev/null 2>&1 || true; \
   adb -s 127.0.0.1:5556 install -r /tmp/douyin.apk"
```

如果 APK 在本地电脑，先传到 `192.168.1.107:/tmp/` 再安装。

## 3. 首次启动并看真实状态

先走脚本入口：

```bash
zsh redroid/scripts/redroid_guest4k_107.sh douyin-start
zsh redroid/scripts/redroid_guest4k_107.sh douyin-diagnose
```

其中：

- `douyin-start` 会做 `force-stop` + `am start -W`
- `douyin-diagnose` 会收集：
  - 包路径
  - pid
  - `topResumedActivity`
  - `dumpsys media.audio_flinger`
  - `dumpsys audio`
  - 过滤后的 `logcat`
  - host PipeWire 上的 `qemu` sink-input

如果你要直接手敲启动命令，也可以这样做：

```bash
ssh wjq@192.168.1.107 \
  "adb connect 127.0.0.1:5556 >/dev/null 2>&1 || true; \
   adb -s 127.0.0.1:5556 shell am force-stop com.ss.android.ugc.aweme >/dev/null 2>&1 || true; \
   adb -s 127.0.0.1:5556 shell am start -W -n com.ss.android.ugc.aweme/.splash.SplashActivity"
```

然后重点看：

- 是否真的进入目标 Activity
- 进程是否还能存活
- 是否出现新的 native crash
- 是否只是被系统兼容提示挡住

## 4. 如果你必须借用旧的 direct-host helper

只有在你明确需要旧脚本内建动作时，再临时回到直跑 `16K`：

```bash
export SUDO_PASS='...'

zsh redroid/scripts/redroid_root_safe_107.sh restart
zsh redroid/scripts/redroid_root_safe_107.sh verify
zsh redroid/scripts/redroid_root_safe_107.sh douyin-compat
zsh redroid/scripts/redroid_root_safe_107.sh douyin-libtnet-install
zsh redroid/scripts/redroid_root_safe_107.sh phone-mode
```

这条路径要记住两点：

- 它是旧自动化入口，不是当前推荐运行时
- 旧路径上的结论不能自动等价为 Guest4K 上的最终结论

## 5. 当前对抖音的项目判断

当前已经明确的点：

- 安装 APK 不是问题
- VNC 点击注入不是问题
- Guest4K 基座已经能稳定 boot
- 现在应该优先在真正 boot 完成的 `4K` 基线上重跑抖音

当前还没有完成的点：

- 把旧的抖音专项 helper 全部迁到 Guest4K
- 在 Guest4K 上把抖音运行路径重新走完一遍
- 根据 Guest4K 上的新 crash / log，再决定后续到底是媒体、渲染、兼容性还是反虚拟化问题

## 6. 当前不该再重复走的老路

已经不该再继续押注的方向：

- 直跑 `4K` Redroid 镜像来对抗 `16K` host 内核
- 在 guest 里使用 `--network host`
- 把单独 `vkms` 暴露当成 Guest4K 主线
- 继续把 direct-host `16K` 当成默认主线

Guest4K 现在之所以能 boot，不是因为“换了个镜像标签试出来了”，而是因为：

- HWC 的 DRM 节点探测顺序被修正
- full `/dev/dri` 暴露后，HWC 可以选中 `virtio_gpu`
- SurfaceFlinger 终于拿到了真正的初始显示配置
