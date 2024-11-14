#!/bin/bash

cd "$(dirname "$0")"
source .env

CURRENT_TIME=$(date +'<t:%s:F>')

update_function() {
# Download patches, integrations and cli
echo "Downloading required files..."
curl -s https://api.github.com/repos/ReVanced/revanced-patches/releases/latest | grep "browser_download_url.*.rvp" | grep -v ".asc"  | cut -d : -f 2,3 | tr -d \" | wget --show-progress -qi - -O patch.rvp
curl -s https://api.github.com/repos/ReVanced/revanced-cli/releases/latest  | grep  "browser_download_url.*.jar" | grep -v ".asc" | cut -d : -f 2,3 | tr -d \" | wget --show-progress -qi - -O cli.jar

# Get apkmd from source
curl -s https://api.github.com/repos/tanishqmanuja/apkmirror-downloader/releases/latest | grep "browser_download_url.*apkmd" | grep -v "apkmd.exe" | cut -d : -f 2,3 | tr -d \" | wget --show-progress -qi - -O apkmd
# Add execution permissions for apkmd
chmod +x ./apkmd
# Command to get the version
echo "Getting version..."
current_version=$(java -jar cli.jar list-versions patch.rvp -f com.google.android.youtube | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n 1)


# Create a new JSON file with the updated version
cat <<EOL > download.json
{
  "options": {
    "arch": "arm64-v8a"
  },
  "apps": [
    {
      "org": "google-inc",
      "repo": "youtube",
      "outFile": "yt",
      "version": "$current_version"
    }
  ]
}
EOL

echo "Downloading youtube version "$current_version"..."
./apkmd download.json

echo "Patching youtube..."
java -jar cli.jar patch yt.apk \
  --patches=patch.rvp \
  --keystore=revanced.jks \
  --purge \
  -o revanced-$current_version.apk

echo "Finished! Output: revanced-$current_version.apk"

echo "$current_version" > version.txt
echo "Saved version.txt for further updates!"
# Optional: Install apk directly
# adb install revanced.apk
}

remove_files () {
echo "Cleaning files..."
rm -f patch.rvp cli.jar integrations.apk download.json yt.apk apkmd
# remove ReVanced cache
rm -rf revanced*-resource-cache
rm -f apkmd
# This is used for signing the apk. If planned to continue updating, consider keeping this file.
rm -f revanced*options.json
}

nextcloud_upload () {
echo "Uploading to Nextcloud...."
curl ${NEXTCLOUD_INSTANCE_URL}/remote.php/dav/files/revanced/ \
  -u "${NEXTCLOUD_USERNAME}:${NEXTCLOUD_PASSWORD}" \
  -X PUT \
  -s \
  -# \
  -T ./revanced-$current_version.apk
}

nextcloud_delete_old () {

file="version.txt"

if [ -e "$file" ]; then
    version=$(<version.txt)
    echo "version.txt found. Deleting old APKS on Nextcloud..."
    curl ${NEXTCLOUD_INSTANCE_URL}/remote.php/dav/files/revanced/revanced-$version.apk \
    -u ${NEXTCLOUD_USERNAME}:${NEXTCLOUD_PASSWORD} \
    -X DELETE \
    -# \
    -s
else
    echo "No $file found. Not deleting anything..."
fi
  #----------IT IS IMPORTANT THAT IT IS DELETED BEFORE UPLOADING/PATCHING------------#
}

nextcloud_link () {
path="revanced-$current_version.apk"
shareType=3  # 0 for user, 1 for group, 3 for public link, and so on

download_link=$(curl "${NEXTCLOUD_INSTANCE_URL}/ocs/v2.php/apps/files_sharing/api/v1/shares" \
  -X POST \
  -H "OCS-APIRequest: true" \
  -u "${NEXTCLOUD_USERNAME}:${NEXTCLOUD_PASSWORD}" \
  -d "path=${path}" \
  -s \
  -d "shareType=${shareType}" | grep -oP '<url>\K.*?(?=<\/url>)' | sed 's|$|/download|')

}

discord_webhook () {
#----------IT IS IMPORTANT THAT IT IS DONE AFTER UPLOADING/PATCHING------------#
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

curl "$DISCORD_WEBHOOK_URL" \
  -X POST \
  -d '{"content":"<@334641468159295490>","embeds":[{"type":"rich","title":"New ReVanced version available!","description":"New YouTube ReVanced version '"$current_version"' has just been patched! It is recommended to update as soon as possible! \n[Click here to download the ReVanced APK]('"$download_link"')","color":"12602822","timestamp":"'$timestamp'"}]}' \
  -s \
  -H "Content-Type: application/json"
}

# Change directory to current (for better compatibility with cron):
cd "$(dirname "${BASH_SOURCE[0]}")"
# Remove files before installation:
remove_files


nextcloud_run () {
nextcloud_delete_old
update_function
nextcloud_upload
nextcloud_link
discord_webhook
remove_files
}

normal_run () {
update_function
remove_files
}

execute_script () {
    if [ -z "$NEXTCLOUD_INSTANCE_URL" ] || [ -z "$NEXTCLOUD_USERNAME" ] || [ -z "$NEXTCLOUD_PASSWORD" ] || [ -z "$DISCORD_WEBHOOK_URL" ]; then
		echo "Missing variables. Executing locally."
		normal_run
    else
		echo "Running with Nextcloud and Discord."
		echo "$CURRENT_TIME Executing ReVanced script..." | curl -d "content=$(cat -)" -X POST $DISCORD_WEBHOOK_LOGS
		nextcloud_run
    fi
}

echo "Checking for updates..."

latest_version=$(curl -s https://raw.githubusercontent.com/ReVanced/revanced-patches/refs/heads/main/patches/src/main/kotlin/app/revanced/patches/youtube/ad/video/VideoAdsPatch.kt | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n 1)
version_file="version.txt"

trap 'remove_files' EXIT

# Check if DISCORD_WEBHOOK_LOGS is set and not empty
log() {
    if [ -n "$DISCORD_WEBHOOK_LOGS" ]; then
        echo "$1" | curl -d "content=$(cat -)" -X POST $DISCORD_WEBHOOK_LOGS
    else
        echo "$1"
    fi
}

# Check for version.txt
if [ -e "$version_file" ]; then
    # Read the local version from the version.txt file
    local_version=$(cat "$version_file")

    # Check if local_version is empty
    if [ -z "$local_version" ]; then
        log "version.txt is found, but it is empty. Executing the script..."
        execute_script
    else
        # Compare versions
        if [ "$latest_version" \> "$local_version" ]; then
            log "Updating to the latest version: $latest_version"
            execute_script
        elif [ "$latest_version" = "$local_version" ]; then
            log "You're running on the latest version: $latest_version!"
            exit
        else
            log "You're running a newer version than expected: Current: $local_version, Source: $latest_version. Please double-check your existing version.txt!"
            exit 1
        fi
    fi
else
    log "version.txt not found. Executing the script..."
    execute_script
fi

if [ "$DELETE_AFTER_UPLOAD" == "true" ]; then
    # Remove files if the var is true
    log "Removing local APK (Uploaded via Nextcloud)...."
    rm -rf revanced-$current_version.apk
fi
