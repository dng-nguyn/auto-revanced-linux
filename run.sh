#!/bin/bash
### PLEASE LOOK THROUGH THE SCRIPT BEFORE EXECUTING!!! ###
# Download patches, integrations and cli
echo "Downloading files..."
curl -s https://api.github.com/repos/ReVanced/revanced-patches/releases/latest | grep "browser_download_url.*.jar" | cut -d : -f 2,3 | tr -d \" | wget -qi - -O patch.jar
curl -s https://api.github.com/repos/ReVanced/revanced-cli/releases/latest  | grep "browser_download_url.*.jar" | cut -d : -f 2,3 | tr -d \" | wget -qi - -O cli.jar
curl -s https://api.github.com/repos/ReVanced/revanced-integrations/releases/latest  | grep "browser_download_url.*.apk" | cut -d : -f 2,3 | tr -d \" | wget -qi - -O integrations.apk

# Command to get the version
echo "Getting version..."
version_command=$(java -jar cli.jar list-versions -f com.google.android.youtube patch.jar | awk '/^[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+/{print $1; exit}')

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
      "version": "$version_command"
    }
  ]
}
EOL
echo "Downloading youtube version "$version_command"..."
./apkmd download.json
mv ./downloads/yt.apk yt.apk
echo "Patching youtube..."
java -jar cli.jar patch \
  --patch-bundle patch.jar \
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
echo "Cleaning residual files..."
rm patch.jar cli.jar integrations.apk download.json yt.apk
rm -d downloads
# remove ReVanced cache
rm -rd revanced-resource-cache
# This is used for signing the apk. If planned to continue updating, consider keeping this file.
#rm revanced.keystore
# Optional: Install apk directly
#adb install revanced.apk
