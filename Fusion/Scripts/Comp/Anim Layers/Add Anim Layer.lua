-- Add Anim Layer (hotkey L in the Nodes panel): select a node, one of its layers or its
-- Result, and a wired layer is inserted just before the Result.
local AL = dofile(fusion:MapPath("LuaModules:animlayers.lua"))
local comp = comp or fusion.CurrentComp

local sel = comp.ActiveTool
if not sel then
	for _, t in pairs(comp:GetToolList(true)) do sel = t break end
end
if not sel then
	print("[Anim Layers] Select a node first, then press L.")
	return
end

local layer, owner = AL.addLayer(comp, sel)
if not layer then
	print("[Anim Layers] " .. owner:GetAttrs().TOOLS_Name .. " has no image output to layer.")
	return
end

local flow = comp.CurrentFrame and comp.CurrentFrame.FlowView
if flow then
	flow:Select()
	flow:Select(layer, true)
end
comp:SetActiveTool(layer)
print("[Anim Layers] Added " .. layer:GetAttrs().TOOLS_Name)
