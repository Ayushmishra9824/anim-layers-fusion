-- Anim Layers for Fusion: copy a node's whole control panel as stackable animation layers.
--
--   Base (normal node)      ─┐
--   <Base>_Layer1 (copy)     ─┼─► <Base>_Result (its controls read base + layers) ─► comp
--   <Base>_Layer2 (copy)     ─┘
--
--   * L: the first time, a green <Base>_Result node of the same type takes the base's place in
--     the comp. Each L adds an orange <Base>_LayerN: a fresh node of the same type, so it has
--     the base's full control panel. Its fresh default values mean "no change".
--   * The base and the layers stay completely plain (nothing attached to their controls), so
--     they keyframe like any other node. All the linking lives on the Result: each of its
--     controls gets one native modifier (Calculation for numbers, Offset for positions) whose
--     operand reads   base + (layer1 - default) + (layer2 - default) ...
--     (size-like controls multiply instead). Checkboxes and dropdowns just follow the base.
--   * The expressions sit on those modifiers, never on the Result's own controls: in Resolve
--     21.1 an Ellipse mask with an expression on one of its controls stops rendering.
--   * Shift+L on a layer removes it; Shift+L on the base or Result merges everything back
--     into plain keyframes on the base.
--
-- Bookkeeping: base:GetData("AnimLayers") = { result = name, layers = { name, ... } };
-- layers/Result: GetData("AnimLayersOwner") = base name; modifiers on the Result:
-- GetData("AnimLayersMod") = Result name.

local AL = {}

local SKIP_PAGES = { Common = true }
local LAYERABLE = { SliderControl = true, ScrewControl = true, OffsetControl = true }
local MUL_IDS = {
	Size = true, XSize = true, YSize = true, Width = true, Height = true,
	Scale = true, XScale = true, YScale = true, ZScale = true,
}
local WIRE_TYPES = { Image = true, Mask = true, DataType3D = true }
local LINK_TYPES = { Number = true, Point = true, Text = true }
local PUBLISH_IDS = { PublishNumber = true, PublishPoint = true, PublishText = true }
local OURS = "_AL_"

local function nameOf(t)
	return t:GetAttrs().TOOLS_Name
end

local function flowOf(comp)
	return comp.CurrentFrame and comp.CurrentFrame.FlowView
end

local function outp(tool, id)
	for _, o in ipairs(tool:GetOutputList()) do
		if not id or o:GetAttrs().OUTS_ID == id then return o end
	end
end

local function num(v)
	return string.format("%.10g", v)
end

-- Inputs anywhere in the comp fed by any output of `tool`.
local function downstreamOf(tool)
	local list = {}
	for _, o in ipairs(tool:GetOutputList()) do
		local oid = o:GetAttrs().OUTS_ID
		for _, inp in ipairs(o:GetConnectedInputs() or {}) do
			list[#list + 1] = { inp = inp, outId = oid }
		end
	end
	return list
end

-- Controls that get linked: Number / Point / Text inputs shown in the Inspector.
local function linkable(a)
	return LINK_TYPES[a.INPS_DataType]
		and a.INPID_InputControl
		and not a.INPB_Passive
		and not SKIP_PAGES[a.INPS_ICS_ControlPage or ""]
		and not a.INPS_ID:find("%.")
end

local function layerable(a)
	return (a.INPS_DataType == "Number" or a.INPS_DataType == "Point") and LAYERABLE[a.INPID_InputControl]
end

function AL.getData(tool)
	return tool:GetData("AnimLayers")
end

function AL.ownerOf(comp, tool)
	local o = tool:GetData("AnimLayersOwner")
	if o then
		local t = comp:FindTool(o)
		if t then return t end
	end
	return tool
end

function AL.isLayer(comp, tool)
	local o = tool:GetData("AnimLayersOwner")
	return o ~= nil and tool:GetData("AnimLayersRole") ~= "result"
end

-- Older versions published every base/layer control, which made Fusion show them as driven
-- (lit keyframe buttons) and blocked normal keyframing. Hand each control back its own
-- animation or value and delete the Publish modifier.
local function unpublish(comp, tool)
	local t = comp.CurrentTime
	for _, inp in ipairs(tool:GetInputList()) do
		local src = inp:GetConnectedOutput()
		local st = src and src:GetTool()
		local sa = st and st:GetAttrs()
		if sa and PUBLISH_IDS[sa.TOOLS_RegID] and sa.TOOLS_Name:find(OURS, 1, true) then
			local vsrc = st.Value:GetConnectedOutput()
			local v = st.Value[t]
			inp:ConnectTo(nil)
			if vsrc then
				inp:ConnectTo(vsrc)
			elseif v ~= nil then
				pcall(function() inp[t] = v end)
			end
			st:Delete()
		end
	end
end

-- Attach a modifier to tool[id] the native way (like right-click > Modify With) and tag it.
-- Free-standing modifiers made with AddTool don't evaluate when wired into a control.
-- The modifier keeps Fusion's default name: renaming a tool makes Fusion rewrite that name in
-- every expression in the comp, and default names like "Offset1" are also control names
-- (Text+ has an Offset1 control), so a rename would corrupt other links.
local function modifierOn(tool, id, regId)
	tool:AddModifier(id, regId)
	local o = tool[id]:GetConnectedOutput()
	local m = o and o:GetTool()
	if m then m:SetData("AnimLayersMod", nameOf(tool)) end
	return m
end

-- Remove every modifier we put on the Result (older versions named them "<Result>_AL_...").
local function clearChains(comp, res)
	for _, inp in ipairs(res:GetInputList()) do
		if linkable(inp:GetAttrs()) and inp:GetConnectedOutput() then inp:ConnectTo(nil) end
	end
	local rname = nameOf(res)
	local prefix = rname .. OURS
	for _, t in pairs(comp:GetToolList()) do
		if t:GetData("AnimLayersMod") == rname or nameOf(t):sub(1, #prefix) == prefix then t:Delete() end
	end
end

-- Drop layers whose nodes are gone (and anything we made for them).
local function prune(comp, data)
	local kept = {}
	for _, name in ipairs(data.layers) do
		if comp:FindTool(name) then
			kept[#kept + 1] = name
		else
			local prefix = name .. OURS
			for _, t in pairs(comp:GetToolList()) do
				if t:GetAttrs().TOOLS_Name:sub(1, #prefix) == prefix then t:Delete() end
			end
		end
	end
	data.layers = kept
end

-- The layers that change control `id`: { name, neutral }.
local function partsFor(layers, id)
	local parts = {}
	for _, layer in ipairs(layers) do
		local neutral = layer:GetData("AnimLayersNeutral_" .. id)
		if layer[id] and neutral ~= nil then parts[#parts + 1] = { name = nameOf(layer), neutral = neutral } end
	end
	return parts
end

local function isMul(id, parts)
	return MUL_IDS[id] and parts[1] and type(parts[1].neutral) == "number" and math.abs(parts[1].neutral) > 1e-9
end

-- Rebuild every control on the Result from the base and the current layers.
function AL.rebuild(comp, owner)
	local data = AL.getData(owner)
	local res = data and data.result and comp:FindTool(data.result)
	if not res then return end
	prune(comp, data)
	owner:SetData("AnimLayers", data)

	local layers = {}
	for _, n in ipairs(data.layers) do layers[#layers + 1] = comp:FindTool(n) end
	unpublish(comp, owner)
	for _, layer in ipairs(layers) do unpublish(comp, layer) end
	clearChains(comp, res)

	-- Some controls (buttons, ranges, Text+ justification toggles...) refuse modifiers; Fusion
	-- still creates one, unconnected. Note what exists now so those can be swept up below.
	local before = {}
	for _, t in pairs(comp:GetToolList()) do before[nameOf(t)] = true end

	local bname = nameOf(owner)
	local ct = comp.CurrentTime
	for _, inp in ipairs(owner:GetInputList()) do
		local a = inp:GetAttrs()
		local id = a.INPS_ID
		if linkable(a) and res[id] and a.INPID_InputControl ~= "ButtonControl" then
			local parts = layerable(a) and partsFor(layers, id) or {}
			local base = bname .. "." .. id
			if a.INPS_DataType == "Point" then
				local x, y = base .. ".X", base .. ".Y"
				for _, p in ipairs(parts) do
					local l = p.name .. "." .. id
					x = x .. " + (" .. l .. ".X - " .. num(p.neutral[1]) .. ")"
					y = y .. " + (" .. l .. ".Y - " .. num(p.neutral[2]) .. ")"
				end
				local m = modifierOn(res, id, "Offset")
				if m then
					m.Mode = 0
					m.Offset = { 0, 0 }
					m.Position:SetExpression("Point(" .. x .. ", " .. y .. ")")
				end
			elseif a.INPS_DataType == "Number" then
				local e = base
				local mul = isMul(id, parts)
				for _, p in ipairs(parts) do
					local l = p.name .. "." .. id
					if mul then
						e = e .. " * (" .. l .. " / " .. num(p.neutral) .. ")"
					else
						e = e .. " + (" .. l .. " - " .. num(p.neutral) .. ")"
					end
				end
				local m = modifierOn(res, id, "Calculation")
				if m then
					m.Operator = 0
					m.SecondOperand = 0
					m.FirstOperand:SetExpression(e)
				end
			else
				local m = modifierOn(res, id, "PublishText")
				if m then m.Value:SetExpression(base) end
			end
			-- Couldn't link it: copy the base's value once instead.
			if not res[id]:GetConnectedOutput() and a.INPID_InputControl ~= "RangeControl" then
				local v = inp[ct]
				if v ~= nil then pcall(function() res[id] = v end) end
			end
		end
	end
	for _, t in pairs(comp:GetToolList()) do
		if not before[nameOf(t)] and not t:GetData("AnimLayersMod") then t:Delete() end
	end
end

-- Create the green Result: same type as the base, takes over the base's downstream links.
local function createResult(comp, owner, data)
	local a = owner:GetAttrs()
	local name = a.TOOLS_Name
	local flow = flowOf(comp)
	local x, y = 0, 0
	if flow then x, y = flow:GetPos(owner) end
	local links = downstreamOf(owner)

	comp:SetActiveTool(nil)
	local res = comp:AddTool(a.TOOLS_RegID, false, x, y + 1.5)
	res:SetAttrs({ TOOLS_Name = name .. "_Result" })
	res.TileColor = { R = 0.25, G = 0.72, B = 0.35 }
	res.Comments = "Result of " .. name .. " + its anim layers. Connect this to your comp; "
		.. "animate " .. name .. " and its orange layers, not this node."
	res:SetData("AnimLayersOwner", name)
	res:SetData("AnimLayersRole", "result")

	local t = comp.CurrentTime
	for _, inp in ipairs(owner:GetInputList()) do
		local ia = inp:GetAttrs()
		local rin = res[ia.INPS_ID]
		if rin then
			if WIRE_TYPES[ia.INPS_DataType] then
				-- Share the base's image inputs, and disconnect any auto-wiring on the Result.
				local src = inp:GetConnectedOutput()
				rin:ConnectTo(src)
			elseif ia.INPS_DataType == "FuID" and ia.INPS_ICS_ControlPage ~= "Common" then
				local v = inp[t]
				if v ~= nil then pcall(function() res[ia.INPS_ID] = v end) end
			end
		end
	end
	for _, l in ipairs(links) do
		local o = outp(res, l.outId)
		if o then l.inp:ConnectTo(o) end
	end
	data.result = nameOf(res)
	return res
end

-- Add a layer to the base of `tool`. Returns layer, owner.
function AL.addLayer(comp, tool)
	local owner = AL.ownerOf(comp, tool)
	local data = AL.getData(owner) or { layers = {} }
	comp:StartUndo("Add Anim Layer")

	local res = data.result and comp:FindTool(data.result)
	if not res then res = createResult(comp, owner, data) end
	prune(comp, data)

	local flow = flowOf(comp)
	local x, y = 0, 0
	if flow then x, y = flow:GetPos(owner) end
	local n = #data.layers + 1
	comp:SetActiveTool(nil)
	local layer = comp:AddTool(owner:GetAttrs().TOOLS_RegID, false, x + 1.2 * n, y - 1.5)
	layer:SetAttrs({ TOOLS_Name = nameOf(owner) .. "_Layer" .. n })
	layer.TileColor = { R = 0.95, G = 0.55, B = 0.15 }
	layer.Comments = "Anim Layer " .. n .. " of " .. nameOf(owner) .. ": same controls as the base. "
		.. "Animate it; its changes from the default values add on top of the base. Don't connect it to anything."
	layer:SetData("AnimLayersOwner", nameOf(owner))
	-- A layer is never wired into the comp.
	for _, inp in ipairs(layer:GetInputList()) do
		if WIRE_TYPES[inp:GetAttrs().INPS_DataType] and inp:GetConnectedOutput() then inp:ConnectTo(nil) end
	end
	-- Remember the fresh default of each control: that value means "no change".
	local t = comp.CurrentTime
	for _, inp in ipairs(layer:GetInputList()) do
		local a = inp:GetAttrs()
		if linkable(a) and layerable(a) then
			local v = inp[t]
			if type(v) == "table" then v = { v[1], v[2] } end
			layer:SetData("AnimLayersNeutral_" .. a.INPS_ID, v)
		end
	end

	data.layers[#data.layers + 1] = nameOf(layer)
	owner:SetData("AnimLayers", data)
	AL.rebuild(comp, owner)
	comp:EndUndo(true)
	return layer, owner
end

-- Remove one layer and rebuild.
function AL.removeLayer(comp, layer)
	local owner = AL.ownerOf(comp, layer)
	local data = AL.getData(owner)
	if not data then return false end
	comp:StartUndo("Remove Anim Layer")
	layer:Delete()
	prune(comp, data)
	owner:SetData("AnimLayers", data)
	AL.rebuild(comp, owner)
	comp:EndUndo(true)
	return true
end

local function sameValue(a, b)
	if type(a) == "table" then
		return math.abs(a[1] - b[1]) < 1e-7 and math.abs(a[2] - b[2]) < 1e-7
	end
	return math.abs(a - b) < 1e-7
end

-- Bake base + layers into plain keyframes on the base, then remove the Result and layers.
-- Values are computed from the base and layer controls directly (they are plain controls);
-- reading the Result through its modifiers from a script can return stale values.
function AL.merge(comp, tool)
	local owner = AL.ownerOf(comp, tool)
	local data = AL.getData(owner)
	local res = data and data.result and comp:FindTool(data.result)
	if not res then return false end
	local ca = comp:GetAttrs()
	local first, last = ca.COMPN_GlobalStart, ca.COMPN_GlobalEnd
	comp:StartUndo("Merge Anim Layers")

	prune(comp, data)
	local layers = {}
	for _, n in ipairs(data.layers) do layers[#layers + 1] = comp:FindTool(n) end
	unpublish(comp, owner)
	for _, layer in ipairs(layers) do unpublish(comp, layer) end

	local samples = {}
	for _, inp in ipairs(owner:GetInputList()) do
		local a = inp:GetAttrs()
		local id = a.INPS_ID
		local parts = linkable(a) and layerable(a) and partsFor(layers, id) or {}
		if #parts > 0 then
			local mul = isMul(id, parts)
			local s, changed = {}, false
			for f = first, last do
				local v = owner[id][f]
				if type(v) == "table" then v = { v[1], v[2] } end
				for _, p in ipairs(parts) do
					local lv = comp:FindTool(p.name)[id][f]
					if type(v) == "table" then
						v[1] = v[1] + lv[1] - p.neutral[1]
						v[2] = v[2] + lv[2] - p.neutral[2]
						if not sameValue({ lv[1], lv[2] }, p.neutral) then changed = true end
					elseif mul then
						v = v * (lv / p.neutral)
						if not sameValue(lv, p.neutral) then changed = true end
					else
						v = v + (lv - p.neutral)
						if not sameValue(lv, p.neutral) then changed = true end
					end
				end
				s[#s + 1] = { f, v }
			end
			-- Controls no layer touched keep the base's own keyframes untouched.
			if changed then samples[id] = { type = a.INPS_DataType, s = s } end
		end
	end

	-- Move the comp back onto the base and delete everything we added.
	for _, l in ipairs(downstreamOf(res)) do
		local o = outp(owner, l.outId)
		if o then l.inp:ConnectTo(o) end
	end
	clearChains(comp, res)
	res:Delete()
	for _, layer in ipairs(layers) do layer:Delete() end
	data.layers = {}

	for id, info in pairs(samples) do
		local s = info.s
		local constant = true
		for i = 2, #s do
			if not sameValue(s[i][2], s[1][2]) then constant = false break end
		end
		owner[id]:ConnectTo(nil)
		if constant then
			owner[id] = s[1][2]
		else
			owner:AddModifier(id, info.type == "Point" and "XYPath" or "BezierSpline")
			for i, smp in ipairs(s) do
				local prev, nxt = s[i - 1], s[i + 1]
				local hold = prev and nxt and sameValue(prev[2], smp[2]) and sameValue(nxt[2], smp[2])
				if not hold then owner[id][smp[1]] = smp[2] end
			end
			local ct = comp.CurrentTime
			if ct >= first and ct <= last then owner[id][ct] = s[ct - first + 1][2] end
		end
	end
	owner:SetData("AnimLayers", nil)
	comp:EndUndo(true)
	return true
end

return AL
