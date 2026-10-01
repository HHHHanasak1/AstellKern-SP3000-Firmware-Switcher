# AstellKern-SP3000-Firmware-Switcher

**Customize the sound signature of your SP3000 series with this module.**  
**通过该模块可以根据你的喜好更换 SP3000 的调音**

Different firmware versions can have a noticeable impact on the music tone.
This module makes it easy to switch between firmware, allowing you to find the sound signature you prefer.

不同版本的固件在音色上会有明显差异。本模块可以方便地在固件之间切换，让你找到自己喜欢的调音。

> [!IMPORTANT]
> Since v1.1 this repository and its releases contain **no Astell&Kern partition data**. The `modelconf` images
> are Astell&Kern's data and are not redistributed here; you take them from your own device(s). The module only
> lists their sha256 values and refuses any image that does not match. See [Getting the modelconf images](#getting-the-modelconf-images).
>
> 自 v1.1 起，本仓库及其发布包**不再包含任何艾利和（Astell&Kern）分区数据**。`modelconf` 镜像属于艾利和的数据，这里不再分发，
> 需要你从自己的设备中提取。模块只记录它们的 sha256，不匹配的镜像一律拒绝写入。见[获取 modelconf 镜像](#获取-modelconf-镜像)。

> [!WARNING]
> This module writes to the `modelconf` partition and can change the active boot slot. It backs up the current
> `modelconf` before writing, but it does **not** check that the other slot holds a bootable firmware. Read
> [Before you start](#before-you-start) first. You use it at your own risk.
>
> 本模块会写入 `modelconf` 分区并可切换启动槽位。写入前会自动备份当前的 `modelconf`，但**不会**检查另一个槽位里是否有可启动的固件。
> 请先阅读[开始之前](#开始之前)。风险自负。

- [English](#english)
- [中文](#中文)

---

## English

### What it does

An interactive Magisk-format module (works with APatch / KernelSU / Magisk). Everything is driven by the volume
keys (Vol+ = Yes, Vol− = Next/Skip, Power = cancel).

1. **Checks** that `/dev/block/bootdevice/by-name/modelconf` is a block device whose partition name is
   `modelconf` and whose size is exactly 1 MiB, that the device is an SP3000 (`ro.boot.project_name` = `sp3000`)
   and that the current content looks like a modelconf (`androidboot.device.country=...` followed by zeros).
   If any check fails, `modelconf` is not written.
2. **Backs up** the current `modelconf` to `/data/adb/sp3k_modelconf/backup/` and
   `/sdcard/SP3000-modelconf/backup/`, and remembers its sha256 so that you can restore it later.
3. **Flash `modelconf`**: lists every verified image it finds and asks for each one. Answer "Next" on every entry
   to leave the partition untouched. After writing, the partition is read back and compared; on a mismatch the
   backup is written back.
4. **Switch boot slot**: shows the current slot (`_a` / `_b`), the firmware version and whether the other slot is
   bootable / marked successful, and if you agree, activates the other slot with the bundled `bootctl`.
5. **Reboot**: optionally reboots right away.

The module marks itself for removal (`remove` + `disable`) once it has run, so it does not stay installed.

Known images (sha256 in [`common/modelconf.sha256`](common/modelconf.sha256)):

| Image | Content |
| --- | --- |
| `modelconf_ufs_CN_SP3000.bin` | `androidboot.device.country=CN` |
| `modelconf_ufs_CNGD_SP3000.bin` | `androidboot.device.country=CN.GD` |
| `modelconf_ufs_CNWG_SP3000.bin` | `androidboot.device.country=CN.WG` |

An image is accepted only if it is exactly 1 MiB, has the modelconf layout, and its sha256 is either in that list
or is a dump that this module made of the same device (your own backups).

### Getting the modelconf images

1. **Your device's current image.** Every run of the module dumps it to `/sdcard/SP3000-modelconf/backup/`.
   Without installing the module: copy `common/modelconf.sh` and `common/modelconf.sha256` from the zip to `/sdcard/`, then:

   ```
   su -c "sh /sdcard/modelconf.sh dump"      # dump + check + pin as your own image
   su -c "sh /sdcard/modelconf.sh info"      # partition, current value, images found
   ```

   A plain `dd if=/dev/block/bootdevice/by-name/modelconf of=/sdcard/modelconf.bak` also works as a backup.
2. **The other variants** (CN, CN.GD, CN.WG) come from your own sources, for example:
   - another SP3000 unit you own (run the same `dump` there and copy the file over),
   - a full partition backup of your own device (EDL/9008 or a `dd` backup: take the 1 MiB `modelconf` partition),
   - the `common/*.bin` files of the old v1.0 zip, if you already have it.
3. Copy the images to **`/sdcard/SP3000-modelconf/`** (any file name ending in `.bin`, no spaces), then check them:

   ```
   su -c "sh /sdcard/modelconf.sh verify /sdcard/SP3000-modelconf/*.bin"
   ```

   Only lines starting with `OK` will be offered by the installer. You can also build your own zip with the
   images in `common/`; they are checked the same way.

Advanced: a dump from another unit with a different string (for example `CM.GD`) is not in the list. If you are
sure it is a genuine modelconf, you can add its sha256 to `/data/adb/sp3k_modelconf/user.sha256` yourself
(format: `<sha256>  <label>`). The size and layout checks still apply.

### Requirements

- Astell&Kern SP3000 with root (see [AstellKern-DAP-Root-Guide](https://github.com/HHHHanasak1/AstellKern-DAP-Root-Guide)).
  Other models (SP3000T/M) are refused for `modelconf`.
- Magisk v20.0 or newer, or APatch / KernelSU (the bundled `update-binary` checks for Magisk's `util_functions.sh`).

### Before you start

- **Keep a copy of your backup off the device.** The module makes one in `/sdcard/SP3000-modelconf/backup/`;
  copy it to your PC.
- **Only switch slot if the other slot has a firmware you can boot.** The module shows the slot state but does
  not stop you.
- Keep a way to reach fastboot/recovery in case the device does not boot.

### Install

1. Download the module zip from [Releases](../../releases) (v1.1 or newer; it contains no A&K data).
2. Put your images in `/sdcard/SP3000-modelconf/` (see above).
3. In your root manager, install the zip as a module (local zip) and follow the prompts.

### Build the zip yourself

```
zip -r AstellKern-SP3000-Firmware-Switcher.zip META-INF common install.sh module.prop
```

`.gitattributes` forces LF line endings on the scripts; keep it that way, CRLF breaks `/sbin/sh`.
`.gitignore` keeps `*.bin` / `*.img` out of the repository: never commit modelconf images.

`common/bootctl` is the AOSP `bootctl` (Apache-2.0); origin, hash and build steps are in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

---

## 中文

### 功能

一个交互式的 Magisk 格式模块（APatch / KernelSU / Magisk 均可），全程用音量键操作（音量＋ = 确认，音量− = 下一项/跳过，电源键 = 取消）。

1. **检查**：`/dev/block/bootdevice/by-name/modelconf` 必须是块设备，分区名为 `modelconf`，大小正好 1 MiB；设备必须是 SP3000
   （`ro.boot.project_name` = `sp3000`）；当前内容必须是 modelconf 格式（`androidboot.device.country=...` 后面全是 0）。
   任何一项不通过都不会写入 `modelconf`。
2. **备份**：把当前的 `modelconf` 备份到 `/data/adb/sp3k_modelconf/backup/` 和 `/sdcard/SP3000-modelconf/backup/`，
   并记录它的 sha256，之后可以用来恢复。
3. **刷写 `modelconf`**：列出找到的每个通过校验的镜像，逐个询问。每一项都选“下一项”即为不修改。写入后会读回比对，不一致则自动写回备份。
4. **切换启动槽位**：显示当前槽位（`_a` / `_b`）、固件版本以及另一个槽位是否可启动 / 是否标记为成功启动，确认后用内置的 `bootctl` 激活另一个槽位。
5. **重启**：可选择立即重启。

模块运行结束后会给自己打上 `remove` + `disable` 标记，不会一直留在系统里。

已知镜像（sha256 见 [`common/modelconf.sha256`](common/modelconf.sha256)）：

| 镜像 | 内容 |
| --- | --- |
| `modelconf_ufs_CN_SP3000.bin` | `androidboot.device.country=CN` |
| `modelconf_ufs_CNGD_SP3000.bin` | `androidboot.device.country=CN.GD` |
| `modelconf_ufs_CNWG_SP3000.bin` | `androidboot.device.country=CN.WG` |

只有满足以下条件的镜像才会被接受：大小正好 1 MiB、符合 modelconf 格式，并且 sha256 在上表中，或者是本模块在同一台设备上导出的镜像（你自己的备份）。

### 获取 modelconf 镜像

1. **本机当前的镜像**：模块每次运行都会导出到 `/sdcard/SP3000-modelconf/backup/`。不安装模块时：把 zip 里的 `common/modelconf.sh` 和 `common/modelconf.sha256` 拷到 `/sdcard/`，然后执行：

   ```
   su -c "sh /sdcard/modelconf.sh dump"      # 导出 + 校验 + 记录为本机镜像
   su -c "sh /sdcard/modelconf.sh info"      # 分区、当前值、找到的镜像
   ```

   直接用 `dd if=/dev/block/bootdevice/by-name/modelconf of=/sdcard/modelconf.bak` 也可以作为备份。
2. **其他变体**（CN、CN.GD、CN.WG）需要你从自己的来源获取，例如：
   - 你拥有的另一台 SP3000（在那台机器上同样执行 `dump`，再把文件拷过来）；
   - 你自己设备的完整分区备份（EDL/9008 或 `dd` 备份：取其中 1 MiB 的 `modelconf` 分区）；
   - 如果你手上还有旧版 v1.0 的 zip，可以用其中的 `common/*.bin`。
3. 把镜像放到 **`/sdcard/SP3000-modelconf/`**（文件名以 `.bin` 结尾，不要有空格），然后校验：

   ```
   su -c "sh /sdcard/modelconf.sh verify /sdcard/SP3000-modelconf/*.bin"
   ```

   只有以 `OK` 开头的镜像才会在安装时出现。你也可以把镜像放进 `common/` 自行打包，校验方式相同。

进阶：来自其他机器、字符串不同的镜像（例如 `CM.GD`）不在列表中。如果你确定它是真实的 modelconf，可以自行把它的 sha256 加到
`/data/adb/sp3k_modelconf/user.sha256`（格式：`<sha256>  <说明>`）。大小和格式检查仍然有效。

### 环境要求

- 已获取 Root 的艾利和 SP3000（参见 [AstellKern-DAP-Root-Guide](https://github.com/HHHHanasak1/AstellKern-DAP-Root-Guide)）。其他型号（SP3000T/M）不会写入 `modelconf`。
- Magisk v20.0 及以上，或 APatch / KernelSU（内置的 `update-binary` 会检查 Magisk 的 `util_functions.sh`）。

### 开始之前

- **把备份另存一份到设备以外。** 模块会在 `/sdcard/SP3000-modelconf/backup/` 生成备份，请拷到电脑上。
- **只有在另一个槽位里有能启动的固件时才切换槽位。** 模块会显示槽位状态，但不会阻止你。
- 请确保万一无法开机时，仍有办法进入 fastboot / recovery。

### 安装

1. 从 [Releases](../../releases) 下载模块 zip（v1.1 及以上，不含艾利和数据）。
2. 把你的镜像放到 `/sdcard/SP3000-modelconf/`（见上文）。
3. 在 root 管理器里以本地 zip 的方式安装模块，按提示操作。

### 自行打包

```
zip -r AstellKern-SP3000-Firmware-Switcher.zip META-INF common install.sh module.prop
```

`.gitattributes` 强制脚本使用 LF 换行，请保持不变，CRLF 会让 `/sbin/sh` 无法执行。
`.gitignore` 会把 `*.bin` / `*.img` 排除在仓库之外：请勿提交 modelconf 镜像。

`common/bootctl` 是 AOSP 的 `bootctl`（Apache-2.0），来源、哈希和编译方法见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

---

## License

[MIT](LICENSE) for the scripts. `common/bootctl`: Apache-2.0, see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
