#!/bin/sh

# Scriptlet-compatible wrapper derived from the original KUAL run_cmd.sh.
# Keeps the original executable selection and feedback behavior, but removes
# the hardcoded /mnt/us/extensions path and Bash-only syntax.

SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
[ -n "$SCRIPT_DIR" ] || SCRIPT_DIR="/mnt/us/extensions/kfxdedrm-scriptlet/bin"
SCRIPTLET_MENU="/mnt/us/extensions/kfxdedrm-scriptlet/menu.json"

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

# New Scriptlet-aware binaries accept both the recursive scan root and the
# complete menu.json output path. Point scan results directly at our menu so
# the original KUAL extension remains untouched.
case "$1" in
    scan|scantruncate)
        if [ ! -f "$SCRIPTLET_MENU" ]; then
            echo "Scriptlet menu template not found: $SCRIPTLET_MENU"
            exit 1
        fi
        "$executable" "$1" "$2" "$SCRIPTLET_MENU"
        exit $?
        ;;
esac

# kterm is the interactive UI, so let the executable write directly to the
# terminal instead of replaying every line through the legacy KUAL/FBInk path.
"$executable" "$@"
exit $?
