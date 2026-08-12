#!/bin/sh

# Scriptlet-compatible wrapper derived from the original KUAL run_cmd.sh.
# Keeps the original executable selection and feedback behavior, but removes
# the hardcoded /mnt/us/extensions path and Bash-only syntax.

SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
[ -n "$SCRIPT_DIR" ] || SCRIPT_DIR="/mnt/us/kfxdedrm-scriptlet/bin"
SCRIPTLET_MENU="/mnt/us/extensions/kfxdedrm-scriptlet/menu.json"
LEGACY_DIR="/mnt/us/extensions/kfxdedrm"
LEGACY_MENU="$LEGACY_DIR/menu.json"

if [ -d /etc/upstart ]; then
    INIT_TYPE="upstart"
    export INIT_TYPE
    [ -f /etc/upstart/functions ] && . /etc/upstart/functions
else
    INIT_TYPE="sysv"
    export INIT_TYPE
    [ -f /etc/rc.d/functions ] && . /etc/rc.d/functions
fi

FBINK_BIN="true"
for my_dir in /var/tmp /mnt/us/koreader /mnt/us/libkh/bin /mnt/us/linkss/bin /mnt/us/linkfonts/bin /mnt/us/usbnet/bin; do
    my_fbink="${my_dir}/fbink"
    if [ -x "$my_fbink" ]; then
        FBINK_BIN="$my_fbink"
        break
    fi
done

has_fbink() {
    [ "$FBINK_BIN" != "true" ]
}

eips_print_bottom_centered() {
    if [ $# -lt 2 ]; then
        echo "not enough arguments passed to eips_print_bottom_centered"
        return
    fi

    kh_eips_string=$1
    kh_eips_y_shift_up=$2
    [ -n "$kh_eips_string" ] || kh_eips_string=" "

    if [ -z "$EIPS_NO_SLEEP" ]; then
        usleep 150000 2>/dev/null || sleep 1
    fi

    if has_fbink; then
        "$FBINK_BIN" -qpm -y $((-4 - kh_eips_y_shift_up)) "$kh_eips_string"
    else
        eips 0 0 "$kh_eips_string" >/dev/null 2>&1
    fi
}

logmsg() {
    if [ "$INIT_TYPE" = "sysv" ] && command -v msg >/dev/null 2>&1; then
        msg "kfxdedrm: $1" "I"
    elif [ "$INIT_TYPE" = "upstart" ] && command -v f_log >/dev/null 2>&1; then
        f_log I kfxdedrm wrapper "" "$1"
    fi
    echo "$1"
}

check_exec() {
    candidate=$1
    if [ -x "$candidate" ] && "$candidate" test >/dev/null 2>&1; then
        echo "$candidate"
        return 0
    fi
    return 1
}

executable=$(check_exec "$SCRIPT_DIR/kfxdedrmhf_c11")
[ -n "$executable" ] || executable=$(check_exec "$SCRIPT_DIR/kfxdedrmhf_old")
[ -n "$executable" ] || executable=$(check_exec "$SCRIPT_DIR/kfxdedrm_old")
[ -n "$executable" ] || executable=$(check_exec "$SCRIPT_DIR/kfxdedrm_c11")

if [ -z "$executable" ]; then
    eips_print_bottom_centered "No working executable found" 1
    exit 1
fi

echo "$executable"

# v10.0.28's released binaries still write scan results to the original KUAL
# path. The forked source in this repository targets kfxdedrm-scriptlet instead.
# Until rebuilt binaries are bundled, make the legacy menu path a temporary
# compatibility target, capture its generated book list, then restore/remove it.
run_scan() {
    scan_command=$1
    scan_path=$2
    legacy_dir_created=0
    legacy_menu_existed=0
    backup="/tmp/kfxdedrm-menu.$$.bak"

    if [ ! -f "$SCRIPTLET_MENU" ]; then
        echo "Scriptlet menu template not found: $SCRIPTLET_MENU"
        return 1
    fi

    if [ ! -d "$LEGACY_DIR" ]; then
        mkdir "$LEGACY_DIR" || return 1
        legacy_dir_created=1
    fi

    if [ -f "$LEGACY_MENU" ]; then
        cp "$LEGACY_MENU" "$backup" || return 1
        legacy_menu_existed=1
    fi

    restore_legacy_menu() {
        if [ "$legacy_menu_existed" -eq 1 ] && [ -f "$backup" ]; then
            cp "$backup" "$LEGACY_MENU"
        else
            rm -f "$LEGACY_MENU"
        fi
        rm -f "$backup"
        if [ "$legacy_dir_created" -eq 1 ]; then
            rmdir "$LEGACY_DIR" 2>/dev/null || true
        fi
    }

    trap 'restore_legacy_menu; exit 130' HUP INT TERM

    cp "$SCRIPTLET_MENU" "$LEGACY_MENU" || {
        restore_legacy_menu
        trap - HUP INT TERM
        return 1
    }

    if [ -n "$scan_path" ]; then
        "$executable" "$scan_command" "$scan_path"
    else
        "$executable" "$scan_command"
    fi
    status=$?

    # An unpatched v10.0.28 binary updates LEGACY_MENU. A rebuilt Scriptlet
    # binary updates SCRIPTLET_MENU directly. Only copy from the legacy path
    # when it actually contains generated per-book DeDRM entries.
    if grep -q '"params"[[:space:]]*:[[:space:]]*"dedrm ' "$LEGACY_MENU" 2>/dev/null; then
        cp "$LEGACY_MENU" "$SCRIPTLET_MENU" || status=1
    fi

    restore_legacy_menu
    trap - HUP INT TERM
    return "$status"
}

case "$1" in
    scan|scantruncate)
        run_scan "$1"
        exit $?
        ;;
esac

# kterm is the interactive UI, so let the executable write directly to the
# terminal instead of replaying every line through the legacy KUAL/FBInk path.
"$executable" "$@"
exit $?
