#!/bin/sh

SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
BASE=$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)
[ -n "$BASE" ] || BASE="${KFXDEDRM_BASE:-/mnt/us/extensions/kfxdedrm-scriptlet}"
RUNNER="$BASE/bin/run_cmd.sh"
VERSION_FILE="$BASE/VERSION"
CONFIG_FILE="$BASE/config"
CONFIG_REQUEST="${KFXDEDRM_CONFIG_REQUEST:-/tmp/kfxdedrm-config-request}"
MENU_JSON="${KFXDEDRM_MENU_JSON:-/mnt/us/extensions/kfxdedrm-scriptlet/menu.json}"
BOOKS_FILE="/tmp/kfxdedrm-books.$$"
BOOKS_PER_PAGE=8
SCAN_PATH="/mnt/us/documents"
DEDRM_OUTPUT="/mnt/us/dedrm"
KEYFILE_OUTPUT="/mnt/us/dedrm/keyfile.txt"
SETTINGS_REQUIRED=0

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
    [ -r "$CONFIG_FILE" ] || {
        [ -d "$SCAN_PATH" ] || SETTINGS_REQUIRED=1
        return 1
    }

    value=$(config_value SCAN_PATH)
    [ -n "$value" ] && SCAN_PATH=$value
    value=$(config_value DEDRM_OUTPUT)
    [ -n "$value" ] && DEDRM_OUTPUT=$value
    value=$(config_value KEYFILE_OUTPUT)
    [ -n "$value" ] && KEYFILE_OUTPUT=$value

    [ -d "$SCAN_PATH" ] || SETTINGS_REQUIRED=1
    return 0
}

save_config() {
    [ -n "$SCAN_PATH" ] || return 1
    [ -n "$DEDRM_OUTPUT" ] || return 1
    [ -n "$KEYFILE_OUTPUT" ] || return 1
    {
        printf 'SCAN_PATH=%s\n' "$SCAN_PATH"
        printf 'DEDRM_OUTPUT=%s\n' "$DEDRM_OUTPUT"
        printf 'KEYFILE_OUTPUT=%s\n' "$KEYFILE_OUTPUT"
    } > "$CONFIG_REQUEST"
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

choose_custom_dedrm_output() {
    printf '\nEnter full DeDRMed books output folder:\n> '
    IFS= read custom
    case "$custom" in
        /mnt/us/*|/mnt/us)
            DEDRM_OUTPUT=$custom
            return 0
            ;;
        *)
            printf '\nPath must be under /mnt/us.\n'
            wait_for_enter
            ;;
    esac
    return 1
}

choose_custom_keyfile_output() {
    printf '\nEnter full keyfile output path, including filename:\n> '
    IFS= read custom
    case "$custom" in
        /mnt/us/*)
            case "$custom" in
                */) printf '\nEnter a filename, not only a folder.\n'; wait_for_enter ;;
                *) KEYFILE_OUTPUT=$custom; return 0 ;;
            esac
            ;;
        *)
            printf '\nPath must be under /mnt/us.\n'
            wait_for_enter
            ;;
    esac
    return 1
}

scan_folder_menu() {
    while :; do
        clear_screen
        printf '%s\n' '============================================'
        printf '%s\n' '              Scan Folder'
        printf '%s\n' '============================================'
        printf '\nCurrent:\n  %s\n\n' "$SCAN_PATH"
        printf '%s\n' 'Scan roots are recursive.'
        printf '\n'
        printf '%s\n' '1. /mnt/us/documents'
        printf '%s\n' '2. /mnt/us/documents/Items01'
        printf '%s\n' '3. /mnt/us/documents/Items02'
        printf '%s\n' '4. /mnt/us/documents/Downloads'
        printf '%s\n' '5. /mnt/us/documents/Downloads/Items01'
        printf '%s\n' '6. /mnt/us/documents/Downloads/Items02'
        printf '%s\n' '7. Enter custom scan folder'
        printf '%s\n' 'B. Back'
        printf '\nSelect an option: '
        IFS= read choice
        case "$choice" in
            1) candidate="/mnt/us/documents" ;;
            2) candidate="/mnt/us/documents/Items01" ;;
            3) candidate="/mnt/us/documents/Items02" ;;
            4) candidate="/mnt/us/documents/Downloads" ;;
            5) candidate="/mnt/us/documents/Downloads/Items01" ;;
            6) candidate="/mnt/us/documents/Downloads/Items02" ;;
            7) choose_custom_scan_path || true; continue ;;
            b|B) return ;;
            *) continue ;;
        esac
        if [ -d "$candidate" ]; then
            SCAN_PATH=$candidate
        else
            printf '\nFolder does not exist:\n%s\n' "$candidate"
            wait_for_enter
        fi
    done
}

dedrm_output_menu() {
    while :; do
        clear_screen
        printf '%s\n' '============================================'
        printf '%s\n' '          DeDRMed Books Output'
        printf '%s\n' '============================================'
        printf '\nCurrent:\n  %s\n\n' "$DEDRM_OUTPUT"
        printf '%s\n' '1. Use default /mnt/us/dedrm'
        printf '%s\n' '2. Enter custom output folder'
        printf '%s\n' 'B. Back'
        printf '\nSelect an option: '
        IFS= read choice
        case "$choice" in
            1) DEDRM_OUTPUT="/mnt/us/dedrm" ;;
            2) choose_custom_dedrm_output || true ;;
            b|B) return ;;
            *) ;;
        esac
    done
}

keyfile_output_menu() {
    while :; do
        clear_screen
        printf '%s\n' '============================================'
        printf '%s\n' '             Keyfile Output'
        printf '%s\n' '============================================'
        printf '\nCurrent:\n  %s\n\n' "$KEYFILE_OUTPUT"
        printf '%s\n' '1. Use default /mnt/us/dedrm/keyfile.txt'
        printf '%s\n' '2. Enter custom keyfile path'
        printf '%s\n' 'B. Back'
        printf '\nSelect an option: '
        IFS= read choice
        case "$choice" in
            1) KEYFILE_OUTPUT="/mnt/us/dedrm/keyfile.txt" ;;
            2) choose_custom_keyfile_output || true ;;
            b|B) return ;;
            *) ;;
        esac
    done
}

kterm_info_menu() {
    clear_screen
    printf '%s\n' '============================================'
    printf '%s\n' '             kterm Information'
    printf '%s\n' '============================================'
    printf '\nAutomatically detected path:\n  %s\n' "${KTERM_PATH:-unknown}"
    case "${KTERM_PATH:-}" in
        /mnt/us/extensions/*)
            printf '\nKeyboard-compatible location detected.\n'
            ;;
        *)
            printf '\nWARNING: kterm was found outside /mnt/us/extensions.\n'
            printf '%s\n' 'The terminal may open, but the on-screen keyboard may be unavailable.'
            printf '%s\n' 'Recommended location: /mnt/us/extensions/kterm/bin/kterm'
            ;;
    esac
    printf '\nKterm has a hidden touch menu.\n'
    printf '%s\n' 'Use a two-finger (dual-touch) swipe to open it.'
    printf '%s\n' 'From there you can increase/decrease font size,'
    printf '%s\n' 'reverse colors, toggle the keyboard, reset the terminal, or quit.'
    printf '%s\n' 'Use the kterm menu for font size; the launch font-size option is not reliable.'
    wait_for_enter
}

settings_menu() {
    while :; do
        clear_screen
        printf '%s\n' '============================================'
        printf '%s\n' '                Settings'
        printf '%s\n' '============================================'
        if [ "$SETTINGS_REQUIRED" -eq 1 ]; then
            printf '\nNOTICE: The configured scan folder does not exist.\n'
            printf '%s\n' 'Choose a valid scan folder and save settings.'
        fi
        printf '\n1. Scan Folder\n   %s\n' "$SCAN_PATH"
        printf '\n2. DeDRMed Books Output\n   %s\n' "$DEDRM_OUTPUT"
        printf '\n3. Keyfile Output\n   %s\n' "$KEYFILE_OUTPUT"
        printf '\n4. kterm Information\n'
        printf '\n%s\n' 'S. Save settings'
        printf '%s\n' 'B. Back'
        printf '%s\n' 'Q. Exit'
        printf '\nSelect an option: '
        IFS= read choice

        case "$choice" in
            1) scan_folder_menu ;;
            2) dedrm_output_menu ;;
            3) keyfile_output_menu ;;
            4) kterm_info_menu ;;
            s|S)
                if [ ! -d "$SCAN_PATH" ]; then
                    printf '\nSelected scan folder does not exist:\n%s\n' "$SCAN_PATH"
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
                if [ "$SETTINGS_REQUIRED" -eq 1 ]; then
                    printf '\nA valid scan folder must be saved before leaving Settings.\n'
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
                    "$RUNNER" dedrm "$book_path" "$DEDRM_OUTPUT"
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

if [ "$SETTINGS_REQUIRED" -eq 1 ]; then
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
            "$RUNNER" dedrm_all "$SCAN_PATH" "$DEDRM_OUTPUT"
            wait_for_enter
            ;;
        2)
            clear_screen
            "$RUNNER" keyfile "$SCAN_PATH" "$KEYFILE_OUTPUT"
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
