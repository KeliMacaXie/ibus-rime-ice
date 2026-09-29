# ibus-rime-ice

Build a user-local IBus Rime installation from the upstream `ibus-rime`,
`librime`, and `plum` repositories, with the full iDvel/rime-ice recipe.

## What this project does

`build-rime.sh` builds and installs:

- `librime` to `~/.local`, including its shared library and deploy tools.
- Plum to `~/.local/share/plum`, with a `~/.local/bin/rime-install` command.
- The `iDvel/rime-ice:others/recipes/full` data to `~/.local/share/rime-data`.
- `ibus-rime` to `~/.local`, then registers its component for the current user's IBus session.
- Rime's compiled user data under `~/.config/ibus/rime` and selects `rime_ice` as
  the active schema.

The project build output is kept in `build/` beside the scripts. It is ignored by
Git.

## Get the source

Clone the project and initialize its three top-level submodules without recursion:

```bash
git clone git@github.com:KeliMacaXie/ibus-rime-ice.git
cd ibus-rime-ice
git submodule update --init
```

The top-level `librime` and `plum` submodules are the copies used by the build
script. `ibus-rime` also declares its own `librime` and `plum` submodules at
different nested paths. Do not initialize recursively: those nested copies are
not used and would duplicate the same projects.

If you already cloned the repository with its submodules recursively, only the
top-level submodules are needed by this project:

```bash
git submodule update --init ibus-rime librime plum
```

## Dependencies

The build requires a C/C++ toolchain, CMake, Ninja, pkg-config, gettext, and the
development packages for IBus, libnotify, Boost, glog, LevelDB, marisa,
OpenCC, and yaml-cpp. On Debian or Ubuntu, install the corresponding packages
before building. Package names vary slightly by release; common names include:

```bash
sudo apt install build-essential cmake ninja-build pkg-config gettext \
  libibus-1.0-dev libnotify-dev libboost-all-dev libgoogle-glog-dev \
  libleveldb-dev libmarisa-dev libopencc-dev libyaml-cpp-dev
```

The Plum recipe fetches iDvel/rime-ice from GitHub, so the first build needs
network access. To skip updating an already downloaded Plum package, run with
`no_update=1`.

## Build and install

Run from the checkout, or invoke the script by its full path:

```bash
./build-rime.sh
```

The script uses its own location to find the three top-level source directories,
so the current working directory does not matter. It installs only under
`$HOME/.local` and writes the current user's IBus/Rime configuration under
`$HOME/.config`; it does not install files into `/usr` or `/usr/local`.

For a repeat build without fetching updates to the existing Plum package:

```bash
no_update=1 ./build-rime.sh
```

After a successful build, `rime-install` is available from
`~/.local/bin/rime-install`. For example, to update the ice recipe in the
installed shared data directory:

```bash
rime_dir="$HOME/.local/share/rime-data" \
  "$HOME/.local/bin/rime-install" iDvel/rime-ice:others/recipes/full
```

Then deploy the updated data and restart IBus:

```bash
"$HOME/.local/bin/rime_deployer" --build \
  "$HOME/.config/ibus/rime" \
  "$HOME/.local/share/rime-data" \
  "$HOME/.config/ibus/rime/build"
ibus restart
```

The build script also restarts the GNOME IBus user service when it is active.
If the component is not visible immediately after installation, log out and
back in so the desktop session loads `~/.config/environment.d/ibus-rime.conf`.

## Uninstall

Run the uninstall script and confirm its prompt:

```bash
./uninstall-rime.sh
```

It removes this project's user-local installation, build output, and the
current user's IBus Rime data. The script does not remove system-provided IBus
or librime packages.

## Verify

```bash
ibus list-engine | grep -i rime
ldd "$HOME/.local/lib/ibus-rime/ibus-engine-rime" | grep librime
test -f "$HOME/.config/ibus/rime/build/rime_ice.table.bin"
```

The engine should be listed as `rime`, its librime dependency should resolve
from `~/.local/lib`, and the ice table cache should exist after deployment.
