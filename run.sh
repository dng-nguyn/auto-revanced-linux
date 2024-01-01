#!/bin/bash
### PLEASE LOOK THROUGH THE SCRIPT BEFORE EXECUTING!!! ###

update_function() {
# Download patches, integrations and cli
echo "Downloading required files..."
curl -s https://api.github.com/repos/ReVanced/revanced-patches/releases/latest | grep "browser_download_url.*.jar" | cut -d : -f 2,3 | tr -d \" | wget --show-progress -qi - -O patch.jar
curl -s https://api.github.com/repos/ReVanced/revanced-cli/releases/latest  | grep "browser_download_url.*.jar" | cut -d : -f 2,3 | tr -d \" | wget --show-progress -qi - -O cli.jar
curl -s https://api.github.com/repos/ReVanced/revanced-integrations/releases/latest  | grep "browser_download_url.*.apk" | cut -d : -f 2,3 | tr -d \" | wget --show-progress -qi - -O integrations.apk

# Get apkmd from source
curl -s https://api.github.com/repos/tanishqmanuja/apkmirror-downloader/releases/latest | grep "browser_download_url.*apkmd" | grep -v "apkmd.exe" | cut -d : -f 2,3 | tr -d \" | wget --show-progress -qi - -O apkmd
# Add execution permissions for apkmd
chmod +x apkmd
# Command to get the version
echo "Getting version..."
current_version=$(java -jar cli.jar list-versions -f com.google.android.youtube patch.jar | grep -oP '\d+\.\d+\.\d+' | sed 's/^\s*//' | sort -V | tail -n 1)

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
  --merge=integrations.apk \
  yt.apk \
  -o revanced.apk

echo "Finished! Output: revanced.apk"

echo "$current_version" > version.txt
echo "Saved version.txt for further updates!"
# Optional: Install apk directly
# adb install revanced.apk
}

remove_files () {
echo "Cleaning files..."
rm -f patch.jar cli.jar integrations.apk download.json yt.apk apkmd
rm -fd downloads
# remove ReVanced cache
rm -rf revanced-resource-cache
# This is used for signing the apk. If planned to continue updating, consider keeping this file.
#rm revanced.keystore
}
# Remove files before installation:
remove_files

echo "Checking for updates..."

latest_version="$(curl -s https://raw.githubusercontent.com/ReVanced/revanced-patches/main/patches.json | jq -r '.[] | select(.compatiblePackages) | select(.compatiblePackages[] | .name == "com.google.android.youtube") | .compatiblePackages[].versions | if . == null then [] else map(select(. != null and . != "")) end | select(length > 0) | max_by(. // "0" | split(".") | map(tonumber))' | awk 'NR==1 {print}')"
version_file="version.txt"

# Check if version.txt exists
if [ -e "$version_file" ]; then
    # Read the local version from the version.txt file
    local_version=$(cat "$version_file")

    # Check if local_version is empty
    if [ -z "$local_version" ]; then
        echo "version.txt is found, but it is empty. Executing the script..."
        update_function
        remove_files
    else
        # Compare versions
        if [ "$latest_version" \> "$local_version" ]; then
            echo "Updating to the latest version: $latest_version"
            update_function
            remove_files
        elif [ "$latest_version" = "$local_version" ]; then
            echo "You're running on the latest version: $latest_version!"
            exit
        else
            echo "You're running a newer version than expected: Current: $local_version, Source: $latest_version. Please double-check your version.txt!"
            exit 1
        fi
    fi
else
    echo "version.txt not found. Executing the script..."
    update_function
    remove_files
fi
