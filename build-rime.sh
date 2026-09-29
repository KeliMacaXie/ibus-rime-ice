#!/usr/bin/env bash

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SRC_DIR}/build"
INSTALL_PREFIX="${HOME}/.local"

LIBRIME_SOURCE="${SRC_DIR}/librime"
PLUM_SOURCE="${SRC_DIR}/plum"
IBUS_RIME_SOURCE="${SRC_DIR}/ibus-rime"

LIBRIME_BUILD="${BUILD_DIR}/librime-local"
RIME_DATA_DIR="${BUILD_DIR}/rime-data"
IBUS_RIME_BUILD="${BUILD_DIR}/ibus-rime"
SYSTEM_RIME_DATA_DIR="${INSTALL_PREFIX}/share/rime-data"
PLUM_INSTALL_DIR="${INSTALL_PREFIX}/share/plum"
PLUM_INSTALL_BIN="${INSTALL_PREFIX}/bin/rime-install"
IBUS_COMPONENT_DIR="${INSTALL_PREFIX}/share/ibus/component"
IBUS_COMPONENT_FILE="${IBUS_COMPONENT_DIR}/rime.xml"
IBUS_ENGINE="${INSTALL_PREFIX}/lib/ibus-rime/ibus-engine-rime"
IBUS_ENGINE_WRAPPER="${INSTALL_PREFIX}/bin/ibus-engine-rime-local"
IBUS_ENV_FILE="${HOME}/.config/environment.d/ibus-rime.conf"
RIME_USER_DATA_DIR="${HOME}/.config/ibus/rime"
RIME_USER_BUILD_DIR="${RIME_USER_DATA_DIR}/build"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'error: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

for command in cmake bash; do
  require_command "${command}"
done

for directory in "${LIBRIME_SOURCE}" "${PLUM_SOURCE}" "${IBUS_RIME_SOURCE}"; do
  [[ -d "${directory}" ]] || {
    printf 'error: source directory not found: %s\n' "${directory}" >&2
    exit 1
  }
done

mkdir -p "${BUILD_DIR}" "${RIME_DATA_DIR}"

printf '%s\n' '==> Building librime'
cmake -S "${LIBRIME_SOURCE}" -B "${LIBRIME_BUILD}" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
  -DBUILD_MERGED_PLUGINS=OFF \
  -DENABLE_EXTERNAL_PLUGINS=ON \
  -DBUILD_TEST=OFF
cmake --build "${LIBRIME_BUILD}" --parallel
cmake --install "${LIBRIME_BUILD}"

printf '%s\n' '==> Installing plum'
install -d "${PLUM_INSTALL_DIR}" "${INSTALL_PREFIX}/bin"
cp -a "${PLUM_SOURCE}/." "${PLUM_INSTALL_DIR}/"
rm -rf "${PLUM_INSTALL_DIR}/.git"
install -m 0755 "${PLUM_SOURCE}/rime-install" \
  "${PLUM_INSTALL_DIR}/rime-install"
cat > "${PLUM_INSTALL_BIN}" <<EOF
#!/usr/bin/env bash
exec env plum_dir="${PLUM_INSTALL_DIR}" \
  "${PLUM_INSTALL_DIR}/rime-install" "\$@"
EOF
chmod 0755 "${PLUM_INSTALL_BIN}"

printf '%s\n' '==> Installing rime-ice full recipe with plum'
rime_dir="${RIME_DATA_DIR}" "${PLUM_INSTALL_BIN}" \
  iDvel/rime-ice:others/recipes/full
install -d "${SYSTEM_RIME_DATA_DIR}"
cp -a "${RIME_DATA_DIR}/." "${SYSTEM_RIME_DATA_DIR}/"

printf '%s\n' '==> Building ibus-rime'
cmake -S "${IBUS_RIME_SOURCE}" -B "${IBUS_RIME_BUILD}" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="${INSTALL_PREFIX}" \
  -DRime_DIR="${INSTALL_PREFIX}/share/cmake/rime" \
  -DRIME_DATA_DIR="${SYSTEM_RIME_DATA_DIR}" \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
  -DCMAKE_INSTALL_LIBEXECDIR=lib
cmake --build "${IBUS_RIME_BUILD}" --parallel
cmake --install "${IBUS_RIME_BUILD}"

printf '%s\n' '==> Registering ibus-rime with IBus'
install -d "${IBUS_COMPONENT_DIR}" "$(dirname "${IBUS_ENV_FILE}")"
cat > "${IBUS_ENGINE_WRAPPER}" <<EOF
#!/usr/bin/env bash
export LD_LIBRARY_PATH="${INSTALL_PREFIX}/lib\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}"
exec "${IBUS_ENGINE}" --ibus "\$@"
EOF
chmod 0755 "${IBUS_ENGINE_WRAPPER}"
sed "s#<exec>.*</exec>#<exec>${IBUS_ENGINE_WRAPPER}</exec>#" \
  "${IBUS_RIME_BUILD}/rime.xml" > "${IBUS_COMPONENT_FILE}"
cat > "${IBUS_ENV_FILE}" <<EOF
IBUS_COMPONENT_PATH=${IBUS_COMPONENT_DIR}:/usr/share/ibus/component
EOF
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user set-environment \
    "IBUS_COMPONENT_PATH=${IBUS_COMPONENT_DIR}:/usr/share/ibus/component"
fi

printf '%s\n' '==> Deploying Rime data for the current user'
mkdir -p "${RIME_USER_DATA_DIR}" "${RIME_USER_BUILD_DIR}"
env LD_LIBRARY_PATH="${INSTALL_PREFIX}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
  "${INSTALL_PREFIX}/bin/rime_deployer" --build \
  "${RIME_USER_DATA_DIR}" "${SYSTEM_RIME_DATA_DIR}" "${RIME_USER_BUILD_DIR}"
(cd "${RIME_USER_DATA_DIR}" && \
  env LD_LIBRARY_PATH="${INSTALL_PREFIX}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
  "${INSTALL_PREFIX}/bin/rime_deployer" --set-active-schema rime_ice)

if command -v systemctl >/dev/null 2>&1 && systemctl --user is-active --quiet org.freedesktop.IBus.session.GNOME.service; then
  systemctl --user restart org.freedesktop.IBus.session.GNOME.service
fi

printf '\nBuild complete.\n'
printf '  install:    %s\n' "${INSTALL_PREFIX}"
printf '  plum:       %s\n' "${PLUM_INSTALL_BIN}"
printf '  plum stage: %s\n' "${RIME_DATA_DIR}"
printf '  rime data:  %s\n' "${SYSTEM_RIME_DATA_DIR}"
printf '  user data:  %s\n' "${RIME_USER_DATA_DIR}"
