#!/usr/bin/env bash

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PREFIX="${HOME}/.local"
BUILD_DIR="${SRC_DIR}/build"
RIME_USER_DATA_DIR="${HOME}/.config/ibus/rime"
IBUS_COMPONENT_FILE="${INSTALL_PREFIX}/share/ibus/component/rime.xml"
IBUS_ENV_FILE="${HOME}/.config/environment.d/ibus-rime.conf"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'error: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

for command in gsettings; do
  require_command "${command}"
done

printf '%s\n' 'This removes the local Rime installation and the current user Rime data:'
printf '  %s\n' "${INSTALL_PREFIX}/lib/librime.so*"
printf '  %s\n' "${INSTALL_PREFIX}/lib/ibus-rime"
printf '  %s\n' "${INSTALL_PREFIX}/share/rime-data"
printf '  %s\n' "${INSTALL_PREFIX}/share/plum"
printf '  %s\n' "${RIME_USER_DATA_DIR}"
printf '  %s\n' "${BUILD_DIR}"

if [[ "${1:-}" != '--yes' ]]; then
  printf 'Continue? [y/N] '
  read -r answer
  [[ "${answer}" =~ ^[Yy]$ ]] || { echo 'Cancelled.'; exit 0; }
fi

printf '%s\n' '==> Removing the current user Rime input source'
current_sources="$(gsettings get org.gnome.desktop.input-sources sources 2>/dev/null || true)"
if [[ "${current_sources}" == *"'ibus', 'rime'"* ]]; then
  gsettings set org.gnome.desktop.input-sources sources "[('ibus', 'libpinyin')]" || true
fi

printf '%s\n' '==> Stopping IBus before removal'
systemctl --user stop org.freedesktop.IBus.session.GNOME.service 2>/dev/null || true

printf '%s\n' '==> Removing the installed files'
rm -rf \
  "${INSTALL_PREFIX}/lib/ibus-rime" \
  "${INSTALL_PREFIX}/share/ibus-rime" \
  "${INSTALL_PREFIX}/share/ibus/component/rime.xml" \
  "${INSTALL_PREFIX}/share/rime-data" \
  "${INSTALL_PREFIX}/share/plum" \
  "${INSTALL_PREFIX}/share/cmake/rime" \
  "${INSTALL_PREFIX}/lib/pkgconfig/rime.pc" \
  "${INSTALL_PREFIX}/include/rime_api.h" \
  "${INSTALL_PREFIX}/include/rime_api_deprecated.h" \
  "${INSTALL_PREFIX}/include/rime_api_stdbool.h" \
  "${INSTALL_PREFIX}/include/rime_levers_api.h" \
  "${INSTALL_PREFIX}/bin/rime-install" \
  "${INSTALL_PREFIX}/bin/rime_deployer" \
  "${INSTALL_PREFIX}/bin/rime_dict_manager" \
  "${INSTALL_PREFIX}/bin/rime_patch" \
  "${INSTALL_PREFIX}/bin/rime_table_decompiler"
rm -f \
  "${INSTALL_PREFIX}/lib/librime.so" \
  "${INSTALL_PREFIX}/lib/librime.so.1" \
  "${INSTALL_PREFIX}/lib/librime.so.1.17.0"
rm -rf \
  "${INSTALL_PREFIX}/share/locale/zh_CN/LC_MESSAGES/ibus-rime.mo" \
  "${INSTALL_PREFIX}/share/locale/zh_HK/LC_MESSAGES/ibus-rime.mo" \
  "${INSTALL_PREFIX}/share/locale/zh_TW/LC_MESSAGES/ibus-rime.mo"
rm -f "${IBUS_COMPONENT_FILE}" "${INSTALL_PREFIX}/bin/ibus-engine-rime-local" "${IBUS_ENV_FILE}"

printf '%s\n' '==> Removing user data and build output'
rm -rf "${RIME_USER_DATA_DIR}" "${BUILD_DIR}"

systemctl --user unset-environment IBUS_COMPONENT_PATH 2>/dev/null || true
systemctl --user start org.freedesktop.IBus.session.GNOME.service 2>/dev/null || true

printf '%s\n' 'Uninstall complete.'
