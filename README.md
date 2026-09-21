# AstellKern-SP3000-Firmware-Switcher

**Customize the sound signature of your SP3000 series with this module.**  
**通过该模块可以根据你的喜好更换 SP3000 的调音**

Different firmware versions can have a noticeable impact on the music tone.
This module makes it easy to switch between firmware, allowing you to find the sound signature you prefer.

不同版本的固件在音色上会有明显差异。本模块可以方便地在固件之间切换，让你找到自己喜欢的调音。

> [!WARNING]
> This module writes to the `modelconf` partition and can change the active boot slot. It does **not** back anything up and does **not** check that the other slot holds a bootable firmware. Read [Before you start](#before-you-start) first. You use it at your own risk.
>
> 本模块会直接写入 `modelconf` 分区并可切换启动槽位，**不会**自动备份，也**不会**检查另一个槽位里是否有可启动的固件。请先阅读[开始之前](#before-you-start)。风险自负。

- [English](#english)
- [中文](#中文)

---

## English

### What it does

An interactive Magisk-format module. Everything is driven by the volume keys (Vol+ = Yes, Vol− = Next/Skip, Power = cancel).

1. **Flash `modelconf`** – asks, in order, whether to write one of three variants to `/dev/block/bootdevice/by-name/modelconf`. Answer "Next" three times to leave it untouched.

   | File | Content written |
   | --- | --- |
   | `common/modelconf_ufs_CN_SP3000.bin` | `androidboot.device.country=CN` |
   | `common/modelconf_ufs_CNGD_SP3000.bin` | `androidboot.device.country=CN.GD` |
   | `common/modelconf_ufs_CNWG_SP3000.bin` | `androidboot.device.country=CN.WG` |

2. **Switch boot slot** – shows the current slot (`_a` / `_b`) and firmware version, and if you agree, activates the other slot with the bundled `bootctl`.
3. **Reboot** – optionally reboots right away.

The module marks itself for removal (`remove` + `disable`) once it has run, so it does not stay installed.

### Requirements

- Astell&Kern SP3000 series with root (see [AstellKern-DAP-Root-Guide](https://github.com/HHHHanasak1/AstellKern-DAP-Root-Guide)).
- Magisk v20.0 or newer (the bundled `update-binary` refuses to run otherwise).
- A `modelconf` block device at `/dev/block/bootdevice/by-name/modelconf`; the installer aborts if it is missing.

### Before you start

- **Back up `modelconf`.** The installer shows the current value but does not save it. From a root shell:

  ```
  dd if=/dev/block/bootdevice/by-name/modelconf of=/sdcard/modelconf.bak
  ```

- **Only switch slot if the other slot has a firmware you can boot.** The module does not verify this.
- Keep a way to reach fastboot/recovery in case the device does not boot.

### Install

1. Download `SP3K_Fucker_1.0.zip` from [Releases](../../releases).
2. In your root manager, install it as a module (local zip).
3. Follow the on-screen prompts with the volume keys.

### Build the zip yourself

The zip must contain these entries at its root:

```
zip -r AstellKern-SP3000-Firmware-Switcher.zip META-INF common install.sh module.prop
```

`.gitattributes` forces LF line endings on the scripts; keep it that way, CRLF breaks `/sbin/sh`.

---

## 中文

### 功能

一个交互式的 Magisk 格式模块，全程用音量键操作（音量＋ = 确认，音量− = 下一项/跳过，电源键 = 取消）。

1. **刷写 `modelconf`**：依次询问是否把三个变体之一写入 `/dev/block/bootdevice/by-name/modelconf`。连续选三次“下一项”即为不修改。

   | 文件 | 写入内容 |
   | --- | --- |
   | `common/modelconf_ufs_CN_SP3000.bin` | `androidboot.device.country=CN` |
   | `common/modelconf_ufs_CNGD_SP3000.bin` | `androidboot.device.country=CN.GD` |
   | `common/modelconf_ufs_CNWG_SP3000.bin` | `androidboot.device.country=CN.WG` |

2. **切换启动槽位**：显示当前槽位（`_a` / `_b`）和固件版本，确认后用内置的 `bootctl` 激活另一个槽位。
3. **重启**：可选择立即重启。

模块运行结束后会给自己打上 `remove` + `disable` 标记，不会一直留在系统里。

### 环境要求

- 已获取 Root 的艾利和 SP3000 系列（参见 [AstellKern-DAP-Root-Guide](https://github.com/HHHHanasak1/AstellKern-DAP-Root-Guide)）。
- Magisk v20.0 及以上（内置的 `update-binary` 低于此版本会拒绝运行）。
- 存在块设备 `/dev/block/bootdevice/by-name/modelconf`，否则安装程序会中止。

### 开始之前

- **先备份 `modelconf`。** 安装程序只会显示当前值，不会保存。在 root shell 里执行：

  ```
  dd if=/dev/block/bootdevice/by-name/modelconf of=/sdcard/modelconf.bak
  ```

- **只有在另一个槽位里有能启动的固件时才切换槽位。** 模块不会验证这一点。
- 请确保万一无法开机时，仍有办法进入 fastboot / recovery。

### 安装

1. 从 [Releases](../../releases) 下载 `SP3K_Fucker_1.0.zip`。
2. 在你的 root 管理器里以本地 zip 的方式安装模块。
3. 按屏幕提示用音量键操作。

### 自行打包

zip 的根目录必须包含以下条目：

```
zip -r AstellKern-SP3000-Firmware-Switcher.zip META-INF common install.sh module.prop
```

`.gitattributes` 强制脚本使用 LF 换行，请保持不变，CRLF 会让 `/sbin/sh` 无法执行。

---

## License

[MIT](LICENSE)
