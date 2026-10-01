# Third-party notices

## common/bootctl

- What: the AOSP `bootctl` command-line wrapper for the boot control HAL
  (`android.hardware.boot@1.0`), source `platform/system/extras`, directory `bootctl/` (`bootctl.cpp`).
  It is not Astell&Kern software. The stock SP3000 firmware ships the boot HAL
  (`android.hardware.boot@1.0-impl.so`, `bootctrl.trinket.so`) but no `bootctl` command, so the module brings one.
- Binary: arm64 PIE, ELF note "Android 27" (built in an Android 8.1 platform tree), links only
  `libhidlbase`, `libhidltransport`, `libhwbinder`, `libutils`, `android.hardware.boot@1.0`, `libc++`, `libc`, `libm`, `libdl`.
- sha256 `7609b881109a1737d168ca4f41ae1bb7b0a43cea077450ac822798e9e2f3663b` (md5 `0375163c4e7a54c93ca143308fe02f79`).
  `install.sh` refuses to run a `bootctl` with any other hash; if you build your own, update `BOOTCTL_SHA256`.
- Licence: Apache License 2.0, Copyright (C) 2016 The Android Open Source Project.
  Full text: https://www.apache.org/licenses/LICENSE-2.0

### Building it yourself

In an AOSP checkout whose boot HAL is still HIDL 1.0 (android-8.1.0 ... android-10.0.0 tags; newer
`bootctl` versions need boot HAL 1.1/1.2 or AIDL, which the stock SP3000 firmware does not have):

```
source build/envsetup.sh
lunch aosp_arm64-userdebug
m bootctl
# result: out/target/product/generic_arm64/system/bin/bootctl
```

Then put the result at `common/bootctl` and set `BOOTCTL_SHA256` in `install.sh` to its sha256.
