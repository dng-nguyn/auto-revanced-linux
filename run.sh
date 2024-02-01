#!/bin/bash

source .env

update_function() {
# Download patches, integrations and cli
echo "Downloading required files..."
curl -s https://api.github.com/repos/ReVanced/revanced-patches/releases/latest | grep "browser_download_url.*.jar" | cut -d : -f 2,3 | tr -d \" | wget --show-progress -qi - -O patch.jar || { echo "Unable to download patcher"; exit 1; }
curl -s https://api.github.com/repos/ReVanced/revanced-cli/releases/latest  | grep "browser_download_url.*.jar" | cut -d : -f 2,3 | tr -d \" | wget --show-progress -qi - -O cli.jar
curl -s https://api.github.com/repos/ReVanced/revanced-integrations/releases/latest  | grep "browser_download_url.*.apk" | cut -d : -f 2,3 | tr -d \" | wget --show-progress -qi - -O integrations.apk

# Get apkmd from source
curl -s https://api.github.com/repos/tanishqmanuja/apkmirror-downloader/releases/latest | grep "browser_download_url.*apkmd" | grep -v "apkmd.exe" | cut -d : -f 2,3 | tr -d \" | wget --show-progress -qi - -O apkmd
# Add execution permissions for apkmd
chmod +x ./apkmd
# Command to get the version
echo "Getting version..."
current_version="$(curl -s https://raw.githubusercontent.com/ReVanced/revanced-patches/main/patches.json | jq -r '.[] | select(.compatiblePackages) | select(.compatiblePackages[] | .name == "com.google.android.youtube") | .compatiblePackages[].versions | if . == null then [] else map(select(. != null and . != "")) end | select(length > 0) | max_by(. // "0" | split(".") | map(tonumber))' | awk 'NR==1 {print}')"

# Create a new JSON file with the updated version
cat <<EOL > download.json
{
  "options": {
    "arch": "arm64-v8a"
  },
  "apps": [
    {
      "name": "yt",
      "org": "google-inc",
      "repo": "youtube",
      "version": "$current_version"
    }
  ]
}
EOL

echo "Downloading youtube version "$current_version"..."
./apkmd download.json
mv ./downloads/yt.apk yt.apk
rm -fd downloads
echo "Patching youtube..."
java -jar cli.jar patch \
  --patch-bundle=patch.jar \
  --exclude="Spoof SIM country" \
  --exclude="Spoof Wi-Fi connection" \
  --exclude="Predictive back gesture" \
  --exclude="Enable Android debugging" \
  --exclude="Theme" \
  --exclude="Enable debugging" \
  --exclude="Always autorepeat" \
  --include="GmsCore Support" \
  --keystore=revanced.jks \
  -p \
  --merge=integrations.apk \
  yt.apk \
  -o revanced-$current_version.apk

echo "Finished! Output: revanced-$current_version.apk"

echo "$current_version" > version.txt
echo "Saved version.txt for further updates!"
# Optional: Install apk directly
# adb install revanced.apk
}

remove_files () {
echo "Cleaning files..."
rm -f patch.jar cli.jar integrations.apk download.json yt.apk apkmd
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

echo "Checking for updates..."

latest_version=$(curl -s https://raw.githubusercontent.com/ReVanced/revanced-patches/main/patches.json | jq -r '.[] | select(.compatiblePackages) | select(.compatiblePackages[] | .name == "com.google.android.youtube") | .compatiblePackages[].versions | if . == null then [] else map(select(. != null and . != "")) end | select(length > 0) | max_by(. // "0" | split(".") | map(tonumber))' | awk 'NR==1 {print}')
version_file="version.txt"

trap 'remove_files' EXIT

# Check if version.txt exists
if [ -e "$version_file" ]; then
    # Read the local version from the version.txt file
    local_version=$(cat "$version_file")

    # Check if local_version is empty
    if [ -z "$local_version" ]; then
        echo "version.txt is found, but it is empty. Executing the script..."
        nextcloud_run
    else
        # Compare versions
        if [ "$latest_version" \> "$local_version" ]; then
            echo "Updating to the latest version: $latest_version"
            nextcloud_run
        elif [ "$latest_version" = "$local_version" ]; then
            echo "You're running on the latest version: $latest_version!"
            exit
        else
            echo "You're running a newer version than expected: Current: $local_version, Source: $latest_version. Please double-check your existing version.txt!"
            exit 1
        fi
    fi
else
    echo "version.txt not found. Executing the script..."
    nextcloud_run
fi
