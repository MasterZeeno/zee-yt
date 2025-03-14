#!/bin/sh

MODDIR=${0%/*}
AUTHOR="Zee"
CURRENT_VERSION=$(cat "$MODDIR/CURRENT_VERSION" 2>/dev/null || echo "v0.0.0")
LATEST_VERSION=

to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

show_msg() {
    echo " - $1"
    [ "${2:-0}" -eq 1 ] && echo
}

check_dependencies() {
    missing_cmds=""

    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_cmds="$missing_cmds $cmd"
        fi
    done

    if [ -n "$missing_cmds" ]; then
        show_msg "Missing dependencies: $missing_cmds" 1

        for mgr in apt pacman pkg dnf yum zypper brew; do
            if command -v "$mgr" >/dev/null 2>&1; then
                case "$mgr" in
                    apt) install_cmd="$mgr update && $mgr install -y" ;;
                    pacman) install_cmd="$mgr -Sy --noconfirm" ;;
                    brew) install_cmd="$mgr install" ;;
                    *) install_cmd="$mgr install -y" ;;
                esac
                break
            fi
        done

        if [ -z "$install_cmd" ]; then
            show_msg "Error: No supported package manager found. Install manually: $missing_cmds"
            return 1
        fi

        show_msg "Installing missing dependencies using $mgr..." 1
        sh -c "$install_cmd $missing_cmds" || { show_msg "Error: Failed to install dependencies"; return 1; }

        show_msg "All dependencies installed successfully."
    fi
}

get_version() {
    FIELD="${2:-1}"
    echo "$1" | grep -oE '[0-9]+' | awk "NR==$FIELD"
}

get_latest_info() {
    INFO_TYPE="${1:-version}"
    REPO_TYPE="${2:-monet-og}"
    JSON_URL="https://raw.githubusercontent.com/selfmusing/RVX-Lite-Modules/main/rvx-yt/$REPO_TYPE.json"

    JSON_DATA=$(curl -fsSL "$JSON_URL") || return 1

    VALUE=$(echo "$JSON_DATA" | awk -F'"' "/\"$INFO_TYPE\":/ { print \$4 }")

    [ -n "$VALUE" ] && echo "$VALUE" || { show_msg "Error: Unable to retrieve $INFO_TYPE."; return 1; }
}

needs_update() {
    REPO_TYPE="${1:-monet-og}"
    LATEST_VERSION=$(get_latest_info) || exit 1

    # Extract version components
    CURRENT_MAJOR=$(get_version "$CURRENT_VERSION" 1); CURRENT_MINOR=$(get_version "$CURRENT_VERSION" 2); CURRENT_PATCH=$(get_version "$CURRENT_VERSION" 3)
    LATEST_MAJOR=$(get_version "$LATEST_VERSION" 1); LATEST_MINOR=$(get_version "$LATEST_VERSION" 2); LATEST_PATCH=$(get_version "$LATEST_VERSION" 3)

    # Default to 0 if a part is missing
    CURRENT_MAJOR=${CURRENT_MAJOR:-0} CURRENT_MINOR=${CURRENT_MINOR:-0} CURRENT_PATCH=${CURRENT_PATCH:-0}
    LATEST_MAJOR=${LATEST_MAJOR:-0} LATEST_MINOR=${LATEST_MINOR:-0} LATEST_PATCH=${LATEST_PATCH:-0}

    # Version comparison using case (POSIX-friendly)
    case 1 in
        $((CURRENT_MAJOR < LATEST_MAJOR)) | \
        $((CURRENT_MAJOR == LATEST_MAJOR && CURRENT_MINOR < LATEST_MINOR)) | \
        $((CURRENT_MAJOR == LATEST_MAJOR && CURRENT_MINOR == LATEST_MINOR && CURRENT_PATCH < LATEST_PATCH)))
            show_msg "Update available: $LATEST_VERSION (Current: $CURRENT_VERSION)" 1
            return 1
            ;;
    esac

    show_msg "You're using the latest version ($CURRENT_VERSION)."
    return 0
}

download_and_extract() {
    RELEASE_TYPE="${1:-monet_og}"
    TEMPORARY_DIR="$MODDIR/tmp"

    [ -d "$TEMPORARY_DIR" ] || mkdir -p "$TEMPORARY_DIR" || { show_msg "Error: No permissions to create '$TEMPORARY_DIR'."; return 1; }

    ZIP_URL=$(get_latest_info zipUrl)
    [ -z "$ZIP_URL" ] && { show_msg "Error: No valid download URL found."; return 1; }

    ZIP_NAME="${ZIP_URL##*/}"
    ZIP_FILE="$TEMPORARY_DIR/$ZIP_NAME"

    show_msg "Downloading: $ZIP_NAME ($LATEST_VERSION)..." 1
    
    # for i in 1 2 3; do
    #     curl -L --progress-bar -o "$ZIP_FILE" "$ZIP_URL" && break
    #     show_msg "Retrying in $((2**i)) seconds... ($i/3)" 1
    #     sleep $((2**i))
    # done

    for i in 1 2 3; do
        curl -L --progress-bar -o "$ZIP_FILE" "$ZIP_URL" && break
        show_msg "Retrying ($i/3)..." 1
        sleep 2
    done

    [ -f "$ZIP_FILE" ] || { show_msg "Error: Downloaded file not found: $ZIP_FILE"; return 1; }

    show_msg "Extracting to: $(realpath "$TEMPORARY_DIR")" 1
    if unzip -o "$ZIP_FILE" -d "$TEMPORARY_DIR" > /dev/null; then
        rm -f "$ZIP_FILE"
        show_msg "Download and extraction completed successfully."
        echo "$LATEST_VERSION" > "$MODDIR/CURRENT_VERSION"
    else
        show_msg "Error: Failed to unzip '$ZIP_FILE'."
        return 1
    fi
}

replace_inline() {
    local file="$1"
    local title="$2"
    local replace="$3"

    [ -f "$file" ] || return 1
    sed -i "s|^${title}=.*|${title}=${replace}|" "$file"
}

edit_module() {
    local mod_prop="${MODDIR}/tmp/module.prop"
    
    [ -f "$mod_prop" ] || return 1  # Exit if file doesn't exist

    for item in "id=$(to_lower "$AUTHOR")_yt" "name=$AUTHOR YouTube Lite" "author=$AUTHOR" \
    "description=$AUTHOR YouTube Lite Magisk module" "updateJson=https://raw.githubusercontent.com/MasterZeeno/zee-yt/main/monet-og.json"; do
        replace_inline "$mod_prop" "${item%=*}" "${item##*=}"
    done
}

# Ensure dependencies are available
check_dependencies curl unzip || exit 1

# if ! needs_update "monet-og"; then
#     download_and_extract "$LATEST_VERSION"
# fi

# echo "v19.44.38" > "$MODDIR/CURRENT_VERSION"

edit_module