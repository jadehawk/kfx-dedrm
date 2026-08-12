#!/bin/sh

BASE="/mnt/us/kfxdedrm-scriptlet"
RUNNER="$BASE/bin/run_cmd.sh"
MENU_JSON="/mnt/us/extensions/kfxdedrm-scriptlet/menu.json"
BOOKS_FILE="/tmp/kfxdedrm-books.$$"
BOOKS_PER_PAGE=8

cleanup() {
    rm -f "$BOOKS_FILE"
}
trap 'cleanup; exit 0' HUP INT TERM
trap 'cleanup' 0

if [ ! -x "$RUNNER" ]; then
    printf '\nKFX DeDRM launcher not found:\n%s\n\n' "$RUNNER"
    printf 'Press Enter to close...'
    read dummy
    exit 1
fi

clear_screen() {
    clear 2>/dev/null || printf '\033c'
}

wait_for_enter() {
    printf '\nPress Enter to continue...'
    IFS= read dummy
}

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
            printf '%s. %s\n' "$number" "$title"
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
            n|N)
                [ "$page" -lt "$pages" ] && page=$((page + 1))
                ;;
            p|P)
                [ "$page" -gt 1 ] && page=$((page - 1))
                ;;
            r|R)
                clear_screen
                "$RUNNER" "$scan_mode"
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
            b|B)
                return
                ;;
            q|Q)
                exit 0
                ;;
            ''|*[!0-9]*)
                ;;
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
    "$RUNNER" "$scan_mode"
    if [ $? -ne 0 ]; then
        printf '\nScan failed.\n'
        wait_for_enter
        return
    fi
    show_books_menu "$scan_mode"
}

while :; do
    clear_screen
    printf '%s\n' '============================================'
    printf '%s\n' '              KFX DeDRM v0.2.0'
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
            clear_screen
            "$RUNNER"
            wait_for_enter
            ;;
        2)
            clear_screen
            "$RUNNER" keyfile
            wait_for_enter
            ;;
        3)
            scan_books scan
            ;;
        4)
            scan_books scantruncate
            ;;
        q|Q)
            exit 0
            ;;
        *)
            ;;
    esac
done
