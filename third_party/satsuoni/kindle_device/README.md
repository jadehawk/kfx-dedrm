# Satsuoni Kindle device source

This directory preserves the Kindle-device source files supplied with Satsuoni's KFX DeDRM tools v10.0.28, from `Other_Tools/KRFKeyExtractor/kindle_device` in the v10.0.28 source package.

## Scriptlet-specific change

`kindledecryptordevice.cpp` has one functional modification for this project: both references to the generated KUAL menu path were changed from `/mnt/us/extensions/kfxdedrm/menu.json` to `/mnt/us/extensions/kfxdedrm-scriptlet/menu.json`.

This keeps the Scriptlet scanner state separate from an installed original KUAL KFX DeDRM extension.

## Build status

The supplied v10.0.28 source package did not include the original cross-compilation command/toolchain configuration or the referenced `json.hpp` header. The four executables currently shipped by this project therefore remain the unchanged v10.0.28 binaries from Satsuoni's `kfxdedrmmobi.zip`.

Until these sources are rebuilt with compatible Kindle ARM soft-float and armhf toolchains, `src/kfxdedrm-scriptlet/bin/run_cmd.sh` provides a guarded compatibility bridge for scan operations. It temporarily backs up an existing original KUAL `menu.json`, allows the unchanged binary to generate its scan result, copies that result into the Scriptlet-specific menu file, and restores the original KUAL file immediately afterward.

Do not replace the distributed Kindle binaries with locally rebuilt versions unless their Kindle ABI/runtime compatibility has been verified on-device.
