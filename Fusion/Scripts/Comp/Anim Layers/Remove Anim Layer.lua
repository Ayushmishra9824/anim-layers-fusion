-- Shift+L: on an orange layer, remove that layer. On the base or its green Result, merge
-- all layers into plain keyframes on the base and remove the Result and layers.
local AL = dofile(fusion:MapPath("LuaModules:animlayers.lua"))
local comp = comp or fusion.CurrentComp

local sel = comp.ActiveTool
if not sel then
	for _, t in pairs(comp:GetToolList(true)) do sel = t break end
end
if not sel then
	print("[Anim Layers] Select a layer (to remove it) or the base/Result (to merge).")
	return
end

local name = sel:GetAttrs().TOOLS_Name
if AL.isLayer(comp, sel) then
	if AL.removeLayer(comp, sel) then print("[Anim Layers] Removed " .. name) end
else
	local owner = AL.ownerOf(comp, sel)
	if AL.merge(comp, owner) then
		comp:SetActiveTool(owner)
		print("[Anim Layers] Merged all layers into " .. owner:GetAttrs().TOOLS_Name)
	else
		print("[Anim Layers] " .. name .. " has no anim layers.")
	end
end
