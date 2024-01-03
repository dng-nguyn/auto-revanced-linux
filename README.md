# auto-revanced-linux
A non-interactive, fully automated YouTube ReVanced patcher and installer, straight from latest releases.
# HOW TO USE:
### PLEASE TAKE A LOOK AT THE SCRIPT FIRST BEFORE EXECUTING!!!
Install dependencies: `curl` , `wget` , `jq` , `git` , Java Runtime `jre-openjdk` version >11 will work. `jre-openjdk-headless` will throw an error.

Distribution specific:

Alpine Linux: 
```sh
sudo apk update && sudo apk add git wget curl jq openjdk18
```
Arch-based:
```sh
sudo pacman -S curl wget git jq jre-openjdk-headless
```
Debian-based:
```sh
sudo apt update && sudo apt install git wget curl jq openjdk-17-jre
```
## Installation:

Clone into this repository:
```sh
git clone https://github.com/dng-nguyn/auto-revanced-linux.git
cd auto-revanced-linux
```
Add execution permission for the script if required:
```sh
chmod +x ./run.sh
```
Execute the script:
```sh
./run.sh
```
A `revanced.apk` will be built for you.
## Credits
[ReVanced](https://github.com/revanced) For making all of this possible

[apkmirror-downloader](https://github.com/tanishqmanuja/apkmirror-downloader) For providing a way to download apks with a specified version straight from apkmirror

##To do:
Support for Termux (why? more like why not)
Implement fail safes or error exiting instead of executing everything
