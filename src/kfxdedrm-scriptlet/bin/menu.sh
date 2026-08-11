#!/bin/sh

BASE="/mnt/us/kfxdedrm-scriptlet"
RUNNER="$BASE/bin/run_cmd.sh"

if [ ! -x "$RUNNER" ]; then
    printf '\nKFX DeDRM launcher not found:\n%s\n\n' "$RUNNER"
    printf 'Press Enter to close...'
    read dummy
    exit 1
fi

while :; do
    clear 2>/dev/null || printf '\033c'
    printf '%s\n' '============================================'
    printf '%s\n' '              KFX DeDRM v0.1.0'
    printf '%s\n' '    Jadehawk (Menu) & Satsuoni (DeDRM)'
    printf '%s\n' '        Satsuoni DeDRM Tools v10.0.28'
    printf '%s\n' '============================================'
    printf '\n'
    printf '%s\n' '1. DeDRM all KFX'
    printf '%s\n' '2. Create keyfile for KFX'
    printf '%s\n' '3. Scan documents folder'
    printf '%s\n' '4. Scan documents + truncate names'
    printf '%s\n' 'Q. Exit'
    printf '\nSelect an option: '

    IFS= read choice

    case "$choice" in
        1)
            clear 2>/dev/null || printf '\033c'
            "$RUNNER"
            ;;
        2)
            clear 2>/dev/null || printf '\033c'
            "$RUNNER" keyfile
            ;;
        3)
            clear 2>/dev/null || printf '\033c'
            "$RUNNER" scan
            ;;
        4)
            clear 2>/dev/null || printf '\033c'
            "$RUNNER" scantruncate
            ;;
        q|Q)
            exit 0
            ;;
        *)
            printf '\nUnknown option: %s\n' "$choice"
            ;;
    esac

    printf '\nPress Enter to return to the menu...'
    IFS= read dummy
 done
