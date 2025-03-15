#!/bin/sh

MODDIR=${0%/*}
AUTHOR='MasterZeeno'
ALIAS="zee"
REPO="${ALIAS}-yt"
SITE="https://raw.githubusercontent.com"
ORIG_AUTHOR="selfmusing"
ORIG_REPO="RVX-Lite-Modules"
ORIG_REPO_ID="rvx-yt"
TEMPORARY_DIR="$MODDIR/tmp"
TAG_NAME=$(date +'%Y%m%d')
HAS_RELEASE_FILE=false
LATEST_VERSION=
VERSION_CODE=
JSON_DATA=

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

toupper() {
  echo "$@" | tr '[:lower:]' '[:upper:]'
}

show_msg() {
    echo " - $1"
    [ "${2:-0}" -eq 1 ] && echo
}

prepend_v() {
    str="$1"
    [ -n "$str" ] || return 1
    case "$str" in
        v*) echo "$str" ;;
        *)  echo "v$str" ;;
    esac
}

get_field() {
    FIELD="${2:-1}"
    echo "$1" | grep -oE '[0-9]+' | awk "NR==$FIELD"
}

get_latest_info() {
    INFO_TYPE="${1:-version}"
    if [ -z "$JSON_DATA" ]; then
        JSON_DATA=$(curl -fsSL "$ORIG_JSON_URL") || return 1
    fi
    echo "$JSON_DATA" | jq -r ".$INFO_TYPE" || { show_msg "Error: Unable to retrieve $INFO_TYPE."; return 1; }
}

needs_update() {
    LATEST_VERSION=$(prepend_v "$(get_latest_info)") || exit 1
    VERSION_CODE=$(get_latest_info versionCode) || exit 1

    # Extract version components
    CURRENT_MAJOR=$(get_field "$CURRENT_VERSION" 1); CURRENT_MINOR=$(get_field "$CURRENT_VERSION" 2); CURRENT_PATCH=$(get_field "$CURRENT_VERSION" 3)
    LATEST_MAJOR=$(get_field "$LATEST_VERSION" 1); LATEST_MINOR=$(get_field "$LATEST_VERSION" 2); LATEST_PATCH=$(get_field "$LATEST_VERSION" 3)

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
    [ -d "$TEMPORARY_DIR" ] || mkdir -p "$TEMPORARY_DIR" || { show_msg "Error: No permissions to create '$TEMPORARY_DIR'."; return 1; }
    
    ZIP_URL=$(get_latest_info zipUrl) || exit 1
    [ -z "$ZIP_URL" ] && { show_msg "Error: No valid download URL found."; return 1; }

    ZIP_FILE="$TEMPORARY_DIR/$RELEASE_FILE"

    show_msg "Downloading: $RELEASE_FILE ($LATEST_VERSION)..." 1

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
    else
        show_msg "Error: Failed to unzip '$ZIP_FILE'."
        return 1
    fi
}

is_folder_not_empty() {
    [ -d "$1" ] || return 1  # Check if directory exists
    find "$1" -mindepth 1 -print -quit | grep -q .
}

edit_module() {
    if is_folder_not_empty "$TEMPORARY_DIR"; then
    
        MOD_PROP="$TEMPORARY_DIR/module.prop"
        CONFIG_FILE="$TEMPORARY_DIR/config"
        
        PATH_NAME="$(toupper "$ALIAS")PATH"
        TO_MATCH='VERSION='
        TO_APPEND='VERSION=$(PREPEND_V "$VERSION")'
        TO_DELETE='Join t.me'
        
        for file in customize service uninstall; do
            file="$TEMPORARY_DIR/${file}.sh"
            if [ -s "$file" ]; then
                CONTENTS=$(cat "$file")
                MODIFIED=0
        
                if ! echo "$CONTENTS" | grep -qF "$TO_APPEND"; then
                    CONTENTS=$(echo "$CONTENTS" | sed "s|.*${TO_MATCH}.*|& $TO_APPEND|")
                fi
        
                NEW_CONTENTS=$(echo "$CONTENTS" | sed -e "/.*${TO_DELETE}.*/d" \
                                                      -e "s|rvhc|$REPO|g" \
                                                      -e "s|${APK_PATH}|${NEW_APK_PATH}|g" \
                                                      -e "s|/data/adb/.*.apk|/data/adb/$REPO/${ALIAS}.apk|g" \
                                                      -e "s|RVPATH=.*|$PATH_NAME=/data/adb/$REPO/${ALIAS}.apk|g" \
                                                      -e "s|RVPATH|$PATH_NAME|g")
        
                if [ "$NEW_CONTENTS" != "$CONTENTS" ]; then
                    CONTENTS="$NEW_CONTENTS"
                    MODIFIED=1
                fi
        
                if [ "$MODIFIED" -eq 1 ]; then
                    echo "$CONTENTS" > "$file"
                    show_msg "Success: '$file' - edited."
                else
                    show_msg "Skipping: '$file' - already edited."
                fi
            fi
        done
        
        if [ -s "$CONFIG_FILE" ]; then
            CONTENTS=$(cat "$CONFIG_FILE" | sed "s|^PKG_VER=.*|PKG_VER=$LATEST_VERSION|")
            CONFIG_FX="PREPEND_V() { case \"\$1\" in v*) echo \"\$1\" ;; *) echo \"v\$1\" ;; esac; }"
            if ! echo "$CONTENTS" | grep -qF "$CONFIG_FX"; then
                CONTENTS="$CONTENTS\n$CONFIG_FX"
                show_msg "Success: '$CONFIG_FILE' - edited."
            else
                show_msg "Skipping: '$CONFIG_FILE' - already edited."
            fi
            echo "$CONTENTS" > "$CONFIG_FILE"
        fi
        
        if [ -s "$MOD_PROP" ]; then
            CONTENTS=$(cat "$MOD_PROP")
            for item in "id=$REPO" "name=$AUTHOR YouTube Lite" \
                       "author=$AUTHOR" "description=$AUTHOR YouTube Lite Magisk module" \
                       "updateJson=$SITE/$AUTHOR/$REPO/main/$REPO/${REPO_TYPE}.json"; do
                search="${item%=*}"
                replace="${item##*=}"
                if ! echo "$CONTENTS" | grep -qF "$item"; then
                    CONTENTS=$(echo "$CONTENTS" | sed "s|^$search=.*|$search=$replace|")
                    show_msg "Success: '$item' - edited."
                else
                    show_msg "Skipping: '$item' - already edited."
                fi
            done
            echo "$CONTENTS" > "$MOD_PROP"
        fi
        
        cd "$TEMPORARY_DIR"
        zip -r "$RELEASE_FILE" . || { show_msg "Error: Unable to create ${REPO_TYPE}.zip."; return 1; }
        cd ..
        mv -f "$TEMPORARY_DIR/$RELEASE_FILE" "$MODDIR/$RELEASE_FILE"
        rm -rf "$TEMPORARY_DIR"
        HAS_RELEASE_FILE=true
    fi
}

edit_json() {
    if [ ! -f "$JSON_FILE" ]; then
        show_msg "Error: $JSON_FILE not found!"
        return 1
    fi

    # Run jq safely
    jq --arg version "$LATEST_VERSION" \
       --argjson versionCode "$VERSION_CODE" \
       --arg zipUrl "https://github.com/$AUTHOR/$REPO/releases/download/$TAG_NAME/$RELEASE_FILE" \
       '.version = $version | .versionCode = $versionCode | .zipUrl = $zipUrl' \
       "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"

    if [ $? -eq 0 ]; then
        show_msg "Success: Updated JSON file."
    else
        show_msg "Error: Failed to update JSON file."
        return 1
    fi
}

update() {
    REPO_TYPE="${1:-monet}-og"
    ORIG_JSON_URL="$SITE/$ORIG_AUTHOR/$ORIG_REPO/main/$ORIG_REPO_ID/${REPO_TYPE}.json"
    JSON_FILE="$MODDIR/$REPO/${REPO_TYPE}.json"
    RELEASE_FILE="${REPO}-${REPO_TYPE}.zip"
    
    check_dependencies curl unzip jq || exit 1
    
    CURRENT_VERSION=$(prepend_v "$(jq -r '.version' "$JSON_FILE")")
    
    if ! needs_update; then
        download_and_extract
        edit_module
        edit_json
    fi
}
