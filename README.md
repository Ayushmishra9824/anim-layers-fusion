# Anim Layers for DaVinci Resolve Fusion

Animation layers for any Fusion node, similar to animation layers in After Effects or Maya.
Press **L** on a node to get a layer node with the same full set of controls.
Animate on the layer, and that animation is added on top of the base node's animation.
You can stack as many layers as you like.

```
Rectangle1  (base)       ─┐
Rectangle1_Layer1        ─┼─►  Rectangle1_Result  ─►  rest of your comp
Rectangle1_Layer2        ─┘
```

- **Base** (your original node): animate it as usual.
- **Layers** (orange): a fresh copy of the same node. Its default values mean "no change". Keyframe any control to add on top of the base, for example +100 px X, +20° angle, or 2× size.
- **Result** (green): the combined output, which replaces the base in your comp. Don't animate this one.

Layers are added together. Size, width, height and scale are multiplied instead, so a layer at 2× doubles whatever the base is doing.

## Install

**[⬇ Download AnimLayers.zip](https://github.com/Ayushmishra9824/anim-layers-fusion/releases/latest/download/AnimLayers.zip)** (latest release)

### Windows
1. Unzip the download.
2. Double-click **`Install (Windows).bat`**.
3. Restart DaVinci Resolve.

### macOS / Linux
1. Unzip the download.
2. macOS: right-click **`Install (Mac + Linux).command`** → **Open**, and confirm.
   Linux: run `sh "Install (Mac + Linux).command"` in a terminal.
3. Restart DaVinci Resolve.

### Manual install (any system)
Copy everything inside the `Fusion` folder into your Fusion user folder, and merge it with the folders already there:

| System  | Fusion user folder |
|---------|--------------------|
| Windows | `%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion` |
| macOS   | `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion` |
| Linux   | `~/.local/share/DaVinciResolve/Fusion` |

If you can't find the folder, open **Workspace → Console** on the Fusion page and run:
`print(app:MapPath("UserData:"))`

After installing, you should have:
```
Fusion/Config/AnimLayers.fu
Fusion/Modules/Lua/animlayers.lua
Fusion/Scripts/Comp/Anim Layers/Add Anim Layer.lua
Fusion/Scripts/Comp/Anim Layers/Remove Anim Layer.lua
```

## Use

Hotkeys work with the mouse over the **Nodes** panel on the Fusion page:

| Key | Selected node | What happens |
|-----|---------------|--------------|
| **L** | any node, layer or Result | Adds a new layer. The first time, it also creates the green Result. |
| **Shift+L** | a layer | Deletes that layer. |
| **Shift+L** | the base or Result | Merges all layers into keyframes on the base, and removes the layers and Result. |

You can also run the scripts from **Workspace → Scripts → Comp → Anim Layers**.

Tips:
- Keyframe the base and the layers normally. Every diamond in the Inspector works as usual.
- Mute a layer by setting its controls back to their defaults. To delete a layer, press Shift+L on it.
- Checkboxes, dropdowns and buttons can't be layered. On the Result they follow the base.
- Undo works for each L / Shift+L action.

## Uninstall
- Windows: run `"Install (Windows).bat" uninstall` from a command prompt.
- macOS / Linux: run `sh "Install (Mac + Linux).command" uninstall`.
- Or delete the four files listed above.

Before uninstalling, press Shift+L on each base node to bake its layers. Comps keep working without the scripts installed, but you won't be able to add or merge layers.

## Notes
- Tested on DaVinci Resolve Studio 21.1. Fusion scripts also run in the free version.
- If you already use **L** or **Shift+L** for something else, edit the key names in `Config/AnimLayers.fu`.

## License
MIT © 2026 Ayush. Free to use, change and share. See [LICENSE](LICENSE).
