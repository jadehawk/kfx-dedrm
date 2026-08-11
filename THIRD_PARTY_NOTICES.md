# Third-Party Notices

This repository and its release archives contain components that are not covered by the repository's GNU General Public License v3.0.

## Satsuoni KFX DeDRM binaries

The `kfxdedrm*` executables under `src/kfxdedrm-scriptlet/bin/` originate from Satsuoni's KFX DeDRM implementation. They are redistributed in this project with permission from Satsuoni and retain their original authorship. The repository-level GNU General Public License v3.0 does not relicense these binaries.

## kterm 2.6

kterm is Copyright its upstream authors and contributors and is licensed under GNU GPL version 3 or, at your option, any later version.

Upstream project: https://github.com/bfabiszewski/kterm
Upstream version: 2.6
Bundled Kindle package: kterm-kindle-2.6-armhf.zip

The unmodified upstream Kindle package is stored under `third_party/kterm/package/` for release assembly. A copy of kterm's GPL license is stored at `third_party/kterm/COPYING`, and the corresponding upstream v2.6 source archive is stored at `third_party/kterm/kterm-v2.6-source.zip`. This same kterm 2.6 source corresponds to the bundled armhf build; armhf refers to how kterm was compiled for the Kindle, not to a different source archive.

The generated Kindle release installs kterm as the separate application `/mnt/us/extensions/kterm`. kfx-dedrm invokes that separate executable as its interactive terminal; kterm remains governed by its own GPL license.
