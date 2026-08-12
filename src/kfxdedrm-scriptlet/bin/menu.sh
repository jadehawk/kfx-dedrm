#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
BASE=$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)
[ -n "$BASE" ] || BASE="${KFXDEDRM_BASE:-/mnt/us/kfxdedrm-scriptlet}"
RUNNER="$BASE/bin/run_cmd.sh"
VERSION_FILE="$BASE/VERSION"
CONFIG_FILE="$BASE/config"
CONFIG_REQUEST="${KFXDEDRM_CONFIG_REQUEST:-/tmp/kfxdedrm-config-request}"
MENU_JSON="${KFXDEDRM_MENU_JSON:-/mnt/us/extensions/kfxdedrm-scriptlet/menu.json}"
BOOKS_FILE="/tmp/kfxdedrm-books.$$"
BOOKS_PER_PAGE=8
SCAN_PATH=""
FIRST_RUN=1

if [ -r "$VERSION_FILE" ]; then
    SCRIPTLET_VERSION=$(sed -n '1p' "$VERSION_FILE")
else
    SCRIPTLET_VERSION="unknown"
fi

cleanup() {
    rm -f "$BOOKS_FILE"
}
trap 'cleanup; exit 0' HUP INT TERM
trap 'cleanup' 0

clear_screen() {
    clear 2>/dev/null || printf '\033c'
}

wait_for_enter() {
    printf '\nPress Enter to continue...'
    IFS= read dummy
}

config_value() {
    key=$1
    [ -r "$CONFIG_FILE" ] || return 1
    sed -n "s/^${key}=//p" "$CONFIG_FILE" | sed -n '1p'
}

load_config() {
    [ -r "$CONFIG_FILE" ] || return 1
    value=$(config_value SCAN_PATH)
    [ -n "$value" ] || return 1
    [ -d "$value" ] || return 1
    SCAN_PATH=$value
    FIRST_RUN=0
    return 0
}

save_config() {
    [ -n "$SCAN_PATH" ] || return 1
    printf 'SCAN_PATH=%s\n' "$SCAN_PATH" > "$CONFIG_REQUEST"
}

load_config || true

if [ ! -x "$RUNNER" ]; then
    printf '\nKFX DeDRM launcher not found:\n%s\n\n' "$RUNNER"
    printf 'Press Enter to close...'
    read dummy
    exit 1
fi

extract_books() {
    [ -f "$MENU_JSON" ] || return 1

    awk '
        function decode(s) {
            gsub(/\\"/, "\"", s)
            return s
        }
        /^[[:space:]]*"name"[[:space:]]*:/ {
            name=$0
            sub(/^[[:space:]]*"name"[[:space:]]*:[[:space:]]*"/, "", name)
            sub(/",?[[:space:]]*$/, "", name)
            name=decode(name)
            next
        }
        /^[[:space:]]*"params"[[:space:]]*:[[:space:]]*"dedrm \\"/ {
            path=$0
            sub(/^[[:space:]]*"params"[[:space:]]*:[[:space:]]*"dedrm \\"/, "", path)
            sub(/",?[[:space:]]*$/, "", path)
            sub(/\\"$/, "", path)
            path=decode(path)
            print name "\t" path
        }
    ' "$MENU_JSON" | awk -F '\t' '{ print NR "\t" $0 }' > "$BOOKS_FILE"

    [ -s "$BOOKS_FILE" ]
}

choose_custom_scan_path() {
    printf '\nEnter full scan folder path:\n> '
    IFS= read custom
    case "$custom" in
        /mnt/us/*|/mnt/us)
            if [ -d "$custom" ]; then
                SCAN_PATH=$custom
                return 0
            fi
            printf '\nFolder does not exist: %s\n' "$custom"
            wait_for_enter
            ;;
        *)
            printf '\nPath must be under /mnt/us.\n'
            wait_for_enter
            ;;
    esac
    return 1
}

settings_menu() {
    while :; do
        clear_screen
        printf '%s\n' '============================================'
        printf '%s\n' '                Settings'
        printf '%s\n' '============================================'
        if [ -n "$SCAN_PATH" ]; then
            printf '\nSelected scan folder:\n  %s\n' "$SCAN_PATH"
        else
            printf '\nSelected scan folder: not configured\n'
            printf '%s\n' 'Choose a scan folder before saving.'
        fi
        printf '\nkterm path (automatically detected):\n  %s\n' "${KTERM_PATH:-unknown}"
        printf '%s\n' 'No kterm setting is required while this menu is working.'
        printf '\n'
        printf '%s\n' '1. Use /mnt/us/documents'
        printf '%s\n' '2. Use /mnt/us/documents/Items01'
        printf '%s\n' '3. Use /mnt/us/documents/Items02'
        printf '%s\n' '4. Enter custom scan folder'
        printf '%s\n' 'S. Save settings'
        printf '%s\n' 'B. Back'
        printf '%s\n' 'Q. Exit'
        printf '\nSelect an option: '
        IFS= read choice

        case "$choice" in
            1)
                if [ -d /mnt/us/documents ]; then
                    SCAN_PATH="/mnt/us/documents"
                else
                    printf '\nFolder does not exist.\n'
                    wait_for_enter
                fi
                ;;
            2)
                if [ -d /mnt/us/documents/Items01 ]; then
                    SCAN_PATH="/mnt/us/documents/Items01"
                else
                    printf '\nFolder does not exist.\n'
                    wait_for_enter
                fi
                ;;
            3)
                if [ -d /mnt/us/documents/Items02 ]; then
                    SCAN_PATH="/mnt/us/documents/Items02"
                else
                    printf '\nFolder does not exist.\n'
                    wait_for_enter
                fi
                ;;
            4) choose_custom_scan_path || true ;;
            s|S)
                if [ -z "$SCAN_PATH" ]; then
                    printf '\nChoose a scan folder before saving.\n'
                    wait_for_enter
                elif save_config; then
                    printf '\nSaving settings and reopening KFX DeDRM...\n'
                    exit 0
                else
                    printf '\nUnable to queue settings update.\n'
                    wait_for_enter
                fi
                ;;
            b|B)
                if [ "$FIRST_RUN" -eq 1 ]; then
                    printf '\nChoose and save a scan folder before leaving first-run setup.\n'
                    wait_for_enter
                else
                    return
                fi
                ;;
            q|Q) exit 0 ;;
        esac
    done
}
display_book_title() {
    title=$1
    mode=$2

    if [ "$mode" != "scantruncate" ]; then
        printf '%s\n' "$title"
        return
    fi

    title_file="/tmp/kfxdedrm-title.$"
    printf '%s' "$title" > "$title_file" || {
        printf '%s\n' "$title"
        return
    }

    # Count UTF-8 code points from lead bytes and calculate byte offsets only at
    # character boundaries. This avoids cutting a multibyte CJK character in half.
    offsets=$(od -An -v -tu1 "$title_file" 2>/dev/null | awk '
        {
            for (i = 1; i <= NF; i++) {
                b = $i + 0
                bytes++
                if (b < 128 || b >= 192) {
                    chars++
                    start[chars] = bytes
                }
            }
        }
        END {
            if (chars <= 40) {
                print chars, 0, 0
            } else {
                first_end = start[17] - 1
                last_start = start[chars - 16]
                print chars, first_end, last_start
            }
        }
    ')

    set -- $offsets
    char_count=${1:-0}
    first_end=${2:-0}
    last_start=${3:-0}

    if [ "$char_count" -le 40 ] 2>/dev/null || [ "$first_end" -le 0 ] 2>/dev/null || [ "$last_start" -le 0 ] 2>/dev/null; then
        cat "$title_file"
        printf '\n'
    else
        dd if="$title_file" bs=1 count="$first_end" 2>/dev/null
        printf '...'
        dd if="$title_file" bs=1 skip=$((last_start - 1)) 2>/dev/null
        printf '\n'
    fi

    rm -f "$title_file"
}

native_scan_mode() {
    if [ "$1" = "scantruncate" ]; then
        printf '%s\n' 'scan'
    else
        printf '%s\n' "$1"
    fi
}

show_books_menu() {
    scan_mode=$1

    if ! extract_books; then
        printf '\nNo scanned KFX books were found.\n'
        wait_for_enter
        return
    fi

    total=$(wc -l < "$BOOKS_FILE" | tr -d ' ')
    page=1
    pages=$(((total + BOOKS_PER_PAGE - 1) / BOOKS_PER_PAGE))
    tab=$(printf '\t')

    while :; do
        start=$(((page - 1) * BOOKS_PER_PAGE + 1))
        end=$((page * BOOKS_PER_PAGE))
        [ "$end" -gt "$total" ] && end=$total

        clear_screen
        printf '%s\n' '============================================'
        printf '%s\n' '              Found KFX Books'
        printf '%s\n' '============================================'
        printf 'Books: %s   Page: %s/%s\n\n' "$total" "$page" "$pages"

        sed -n "${start},${end}p" "$BOOKS_FILE" | while IFS="$tab" read number title book_path; do
            shown_title=$(display_book_title "$title" "$scan_mode")
            printf '%s. %s\n' "$number" "$shown_title"
        done

        printf '\n'
        [ "$page" -lt "$pages" ] && printf '%s\n' 'N. Next page'
        [ "$page" -gt 1 ] && printf '%s\n' 'P. Previous page'
        printf '%s\n' 'R. Rescan'
        printf '%s\n' 'B. Back to main menu'
        printf '%s\n' 'Q. Exit'
        printf '\nSelect a book: '
        IFS= read choice

        case "$choice" in
            n|N) [ "$page" -lt "$pages" ] && page=$((page + 1)) ;;
            p|P) [ "$page" -gt 1 ] && page=$((page - 1)) ;;
            r|R)
                clear_screen
                runner_mode=$(native_scan_mode "$scan_mode")
                "$RUNNER" "$runner_mode" "$SCAN_PATH"
                if [ $? -ne 0 ]; then
                    printf '\nScan failed.\n'
                    wait_for_enter
                    return
                fi
                if ! extract_books; then
                    printf '\nNo scanned KFX books were found.\n'
                    wait_for_enter
                    return
                fi
                total=$(wc -l < "$BOOKS_FILE" | tr -d ' ')
                page=1
                pages=$(((total + BOOKS_PER_PAGE - 1) / BOOKS_PER_PAGE))
                ;;
            b|B) return ;;
            q|Q) exit 0 ;;
            ''|*[!0-9]*) ;;
            *)
                if [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le "$total" ] 2>/dev/null; then
                    selected=$(sed -n "${choice}p" "$BOOKS_FILE")
                    book_path=$(printf '%s\n' "$selected" | cut -f3-)
                    book_title=$(printf '%s\n' "$selected" | cut -f2)
                    clear_screen
                    printf 'DeDRM: %s\n\n' "$book_title"
                    "$RUNNER" dedrm "$book_path"
                    wait_for_enter
                fi
                ;;
        esac
    done
}

scan_books() {
    scan_mode=$1
    clear_screen
    printf 'Scan folder: %s\n\n' "$SCAN_PATH"
    runner_mode=$(native_scan_mode "$scan_mode")
    "$RUNNER" "$runner_mode" "$SCAN_PATH"
    if [ $? -ne 0 ]; then
        printf '\nScan failed.\n'
        wait_for_enter
        return
    fi
    show_books_menu "$scan_mode"
}

credits_menu() {
    while :; do
        clear_screen
        printf '%s\n' '============================================'
        printf '%s\n' '                 Credits'
        printf '%s\n' '============================================'
        printf '\nKFX DeDRM Scriptlet\n'
        printf '%s\n' 'Jadehawk'
        printf '%s\n' 'https://github.com/jadehawk/kfx-dedrm'
        printf '\nDeDRM Tools\n'
        printf '%s\n' 'Satsuoni'
        printf '%s\n' 'https://github.com/Satsuoni/DeDRM_tools'
        printf '\n%s\n' 'B. Back'
        printf '\nSelect an option: '
        IFS= read choice
        case "$choice" in
            b|B) return ;;
            *) ;;
        esac
    done
}

if [ "$FIRST_RUN" -eq 1 ]; then
    settings_menu
fi

while :; do
    clear_screen
    printf '%s\n' '============================================'
    printf '              KFX DeDRM v%s\n' "$SCRIPTLET_VERSION"
    printf '%s\n' '    Jadehawk (Menu) & Satsuoni (DeDRM)'
    printf '%s\n' '        Satsuoni DeDRM Tools v10.0.28'
    printf '%s\n' '============================================'
    printf '\n'
    printf '%s\n' '1. DeDRM all KFX'
    printf '%s\n' '2. Create keyfile for KFX'
    printf '%s\n' '3. Scan configured folder'
    printf '%s\n' '4. Scan configured folder + truncate names'
    printf '%s\n' '5. Settings'
    printf '%s\n' '6. Credits'
    printf '%s\n' 'Q. Exit'
    printf '\nScan folder: %s\n' "$SCAN_PATH"
    printf '\nSelect an option: '

    IFS= read choice
    case "$choice" in
        1)
            clear_screen
            "$RUNNER"
            wait_for_enter
            ;;
        2)
            clear_screen
            "$RUNNER" keyfile
            wait_for_enter
            ;;
        3) scan_books scan ;;
        4) scan_books scantruncate ;;
        5) settings_menu ;;
        6) credits_menu ;;
        q|Q) exit 0 ;;
        *) ;;
    esac
done
