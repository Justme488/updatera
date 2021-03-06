#!/usr/bin/env bash

# Main script written by Sanaki - https://gist.github.com/Sanaki
# original install locations:
# /home/user/bin/retroarch
# /home/user/bin/updatera
# /home/user/src/libretro-super
# /home/user/.config/retroarch

# Install location changed, and shortcuts added by justme4888 - https://github.com/Justme488/build-retroarch
# new install locations:
# /home/user/.local/bin/retroarch
# /home/user/.local/bin/updatera
# /home/user/.local/src/libretro-super
# /home/user/.config/retroarch
# /home/user/.local/share/applications/retroarch.desktop
# /home/user/.local/share/applications/update-retroarch.desktop

# Known non-working (YMMV): Dosbox SVN CE (Dosbox Core is now preferred anyway), Emux (requires a special build recipe)
# Partial Reference: https://libretro.readthedocs.io/en/latest/development/retroarch/compilation/linux-and-bsd/

# FORCE when set to YES will build regardless of changes
# NOCLEAN when set to 1 will prevent make clean before each build. Do not use NOCLEAN on core recipes or cores won't pull changes. Due to this situation I recommend against building MAME as part of this script.
# EXIT_ON_ERROR determines if the build stops on errors
# SINGLE_CORE can be set to a core name to bypass building the entire recipe (core set)

# Find out where this script is
HERE=$(pwd)

# Cores to be built, exporting the libretro_cores env var will use that list instead. For most people, ~/.bashrc will suffice for this.
[[ -z "$libretro_cores" ]] && libretro_cores="atari800 bluemsx citra dolphin duckstation fbneo fceumm flycast gambatte genesis_plus_gx gpsp handy mednafen_pce_fast mednafen_psx_hw mednafen_psx mednafen_vb mednafen_wswan melonds mesen mgba mupen64plus_next neocd nestopia opera parallel_n64 pcsx_rearmed picodrive ppsspp prosystem snes9x stella virtualjaguar yabause"

# Support users with modified XDG_CONFIG_HOME location
[[ -z "$XDG_CONFIG_HOME" ]] && XDG_CONFIG_HOME="$HOME/.config"

# Create a build-retroarch log file if building for first time, or create update-retroarch log file
if [[ ! -f "$HOME/.local/bin/update-retroarch" ]]; then
  exec 3>&1 1>> "$HOME/.config/build-retroarch.log"
else
  if [[ ! -f "$HOME/.config/update-retroarch.log" ]]; then
    rm -f "$XDG_CONFIG_HOME"/update-retroarch*.log
    exec 3>&1 1>> "$HOME/.config/update-retroarch.log"
  else  
    exec 3>&1 1>> "$HOME/.config/update-retroarch.log"
  fi
fi

# Clone or update the libretro-super repo
mkdir -p ~/.local/src
cd ~/.local/src
git clone https://github.com/libretro/libretro-super.git --depth 1 2> >(grep -v 'already exists and is not an empty directory' >&2) || (cd libretro-super ; git pull)
cd libretro-super

# Build retroarch
FORCE=NO EXIT_ON_ERROR=1 ./libretro-buildbot-recipe.sh recipes/linux/retroarch-linux-x64
mkdir -p ~/.local/bin
ln -fT ~/.local/src/libretro-super/retroarch/retroarch ~/.local/bin/retroarch

# Generate custom recipe for cores
truncate -s 0 recipes/linux/custom-cores-x64
for core in $libretro_cores; do
	sed -n "/^$core\s/p" recipes/linux/cores-linux-x64-generic >> recipes/linux/custom-cores-x64
done
ln -f recipes/linux/cores-linux-x64-generic.conf recipes/linux/custom-cores-x64.conf

# Build cores
FORCE=NO EXIT_ON_ERROR=0 ./libretro-buildbot-recipe.sh recipes/linux/custom-cores-x64

# Hardlink cores into default core directory used by retroarch (generating directories if needed, overwriting existing cores)
mkdir -p "$XDG_CONFIG_HOME"/retroarch/cores
ln -f ~/.local/src/libretro-super/dist/unix/*.so "$XDG_CONFIG_HOME"/retroarch/cores/

# Clone/pull and symlink PPSSPP assets if requested. Clone size is ~14MiB.
# This doesn't pull submodules, because they're large and aren't needed for assets. If you want to build standalone as well, you'll need to pull those separately.
if [[ "$libretro_ppsspp_assets" -eq 1 ]]; then
	cd ~/.local/src
	git clone https://github.com/hrydgard/ppsspp.git --depth 1 2> >(grep -v 'already exists and is not an empty directory' >&2) || (cd ppsspp ; git pull)
	mkdir -p "$XDG_CONFIG_HOME"/retroarch/system
	ln -sfT ~/.local/src/ppsspp/assets "$XDG_CONFIG_HOME"/retroarch/system/PPSSPP
fi

# Clone/pull and symlink dolphin assets if requested. Clone size is ~40MiB.
if [[ "$libretro_dolphin_assets" -eq 1 ]]; then
	cd ~/.local/src
	git clone https://github.com/dolphin-emu/dolphin.git --depth 1 2> >(grep -v 'already exists and is not an empty directory' >&2) || (cd dolphin ; git pull)
	mkdir -p "$XDG_CONFIG_HOME"/retroarch/system/dolphin-emu
	ln -sfT ~/.local/src/dolphin/Data/Sys "$XDG_CONFIG_HOME"/retroarch/system/dolphin-emu/Sys
fi

# Symlink assets and other files into the default config directory
ln -sfT ~/.local/src/libretro-super/retroarch/media/assets "$XDG_CONFIG_HOME"/retroarch/assets
ln -sfT ~/.local/src/libretro-super/retroarch/media/autoconfig "$XDG_CONFIG_HOME"/retroarch/autoconfig
mkdir -p "$XDG_CONFIG_HOME"/retroarch/database
#ln -sfT ~/.local/src/libretro-super/retroarch/media/libretrodb/cursors "$XDG_CONFIG_HOME"/retroarch/database/cursors
ln -sfT ~/.local/src/libretro-super/retroarch/media/libretrodb/rdb "$XDG_CONFIG_HOME"/retroarch/database/rdb
ln -sfT ~/.local/src/libretro-super/retroarch/media/overlays "$XDG_CONFIG_HOME"/retroarch/overlay
mkdir -p "$XDG_CONFIG_HOME"/retroarch/shaders
ln -sfT ~/.local/src/libretro-super/retroarch/media/shaders_cg "$XDG_CONFIG_HOME"/retroarch/shaders/shaders_cg
ln -sfT ~/.local/src/libretro-super/retroarch/media/shaders_glsl "$XDG_CONFIG_HOME"/retroarch/shaders/shaders_glsl
ln -sfT ~/.local/src/libretro-super/retroarch/media/shaders_slang "$XDG_CONFIG_HOME"/retroarch/shaders/shaders_slang

# Symlink cheats without touching core-specific cheat files
mkdir -p "$XDG_CONFIG_HOME"/retroarch/cheats
for i in ~/.local/src/libretro-super/retroarch/media/libretrodb/cht/*; do
	ln -sfT "$i" "$XDG_CONFIG_HOME"/retroarch/cheats/"${i##*/}"
done

# Lock all cores added via this script (allows using online updater to "update all cores" without overwrite)
for i in ~/src/libretro-super/dist/unix/*.so; do
	touch "$XDG_CONFIG_HOME"/retroarch/cores/"${i##*/}".lck
done

# Replace core info in default config with git core info
if [[ "$(ls "$XDG_CONFIG_HOME"/retroarch/cores/*.info 2>/dev/null)" ]]; then
  rm "$XDG_CONFIG_HOME"/retroarch/cores/*.info
fi
cp ~/.local/src/libretro-super/dist/info/*.info "$XDG_CONFIG_HOME"/retroarch/cores/

# Move script to $HOME/.local/bin, if not already there

if [[ ! -f "$HOME/.local/bin/update-retroarch" ]]; then
  cd "$HERE"
  mv build-retroarch "$HOME"/.local/bin/update-retroarch
fi

# Create folder $HOME/.local/share/applications for the shortcuts, if it doesn't exist
if [[ ! -d "$HOME/.local/share/applications" ]]; then
  mkdir "$HOME"/.local/share/applications
fi

# create a shortcut in menu for Retroarch in "Games" if it doesn't exist
if [[ ! -f "$HOME/.local/share/applications/retroarch.desktop" ]]; then
  cd ~/.local/share/applications
  touch retroarch.desktop
  echo "[Desktop Entry]" >> retroarch.desktop
  echo "Type=Application" >> retroarch.desktop
  echo "Encoding=UTF-8" >> retroarch.desktop
  echo "Name=Retroarch" >> retroarch.desktop
  echo "Comment=Retroarch" >> retroarch.desktop
  echo "Exec=retroarch" >> retroarch.desktop
  echo "Icon=$HOME/.local/src/libretro-super/retroarch/media/retroarch.icns" >> retroarch.desktop
  echo "Terminal=false" >> retroarch.desktop
  echo "Categories=Game;" >> retroarch.desktop
  chmod +x retroarch.desktop
fi

# Create a shortcut in menu for updating retroarch in "Applications" if it doesn't exist
if [[ ! -f "$HOME/.local/share/applications/update-retroarch.desktop" ]]; then
  cd ~/.local/share/applications
  touch update-retroarch.desktop
  echo "[Desktop Entry]" >> update-retroarch.desktop
  echo "Type=Application" >> update-retroarch.desktop
  echo "Encoding=UTF-8" >> update-retroarch.desktop
  echo "Name=Update Retroarch" >> update-retroarch.desktop
  echo "Comment=Update Retroarch" >> update-retroarch.desktop
  echo "Exec=update-retroarch" >> update-retroarch.desktop
  echo "Icon=$HOME/.local/src/libretro-super/retroarch/media/retroarch.icns" >> update-retroarch.desktop
  echo "Terminal=true" >> update-retroarch.desktop
  echo "Categories=Utility;" >> update-retroarch.desktop
  chmod +x update-retroarch.desktop
fi

# See if $HOME/.local/bin was already in PATH
if [[ "$PATH" != *"$HOME/.local/bin"* ]]; then
  clear
  echo "$HOME/.local/bin was not found in your PATH"
  echo ""
  echo "Please restart your computer"
  echo ""
  read -p "Press any key to exit..." -n1 -s
fi
