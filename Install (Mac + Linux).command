#!/bin/sh
# Installs Anim Layers into DaVinci Resolve's Fusion folder for the current user.
# Run "sh 'Install (Mac + Linux).command' uninstall" to remove it.
cd "$(dirname "$0")" || exit 1

case "$(uname)" in
	Darwin) DEST="$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion" ;;
	*)      DEST="$HOME/.local/share/DaVinciResolve/Fusion" ;;
esac

if [ "$1" = "uninstall" ]; then
	rm -f "$DEST/Config/AnimLayers.fu" "$DEST/Modules/Lua/animlayers.lua"
	rm -rf "$DEST/Scripts/Comp/Anim Layers"
	echo "Anim Layers removed. Restart DaVinci Resolve."
	exit 0
fi

echo "Installing Anim Layers to:"
echo "  $DEST"
mkdir -p "$DEST" && cp -R Fusion/. "$DEST/" || {
	echo "Install failed. Copy the contents of the Fusion folder into the path above by hand."
	exit 1
}
echo
echo "Done. Restart DaVinci Resolve, then press L in the Fusion Nodes panel."
