-- TexturePack module for FadeWare Bedwars
-- Changes sword and item textures
local TexturePack
local SwordTexture
local SwordMesh

local function applyTextureToTool(tool)
	if not tool or not tool:IsA('Tool') then return end
	for _, v in tool:GetDescendants() do
		if v:IsA('MeshPart') then
			if SwordTexture.Value ~= '' then
				v.TextureID = SwordTexture.Value
			end
			if SwordMesh.Value ~= '' then
				v.MeshId = SwordMesh.Value
			end
		elseif v:IsA('SpecialMesh') then
			if SwordTexture.Value ~= '' then
				v.TextureId = SwordTexture.Value
			end
			if SwordMesh.Value ~= '' then
				v.MeshId = SwordMesh.Value
			end
		elseif v:IsA('SurfaceAppearance') then
			if SwordTexture.Value ~= '' then
				v.ColorMap = SwordTexture.Value
			end
		end
	end
end

local function applyToAllTools()
	if not lplr.Character then return end
	for _, v in lplr.Character:GetChildren() do
		if v:IsA('Tool') then
			applyTextureToTool(v)
		end
	end
	for _, v in lplr.Backpack:GetChildren() do
		if v:IsA('Tool') then
			applyTextureToTool(v)
		end
	end
end

TexturePack = vape.Categories.Legit:CreateModule({
	Name = 'TexturePack',
	Function = function(callback)
		if callback then
			applyToAllTools()
			TexturePack:Clean(lplr.CharacterAdded:Connect(function(char)
				task.wait(0.5)
				applyToAllTools()
				TexturePack:Clean(char.ChildAdded:Connect(function(child)
					if child:IsA('Tool') then
						task.wait(0.1)
						applyTextureToTool(child)
					end
				end))
			end))
			if lplr.Character then
				TexturePack:Clean(lplr.Character.ChildAdded:Connect(function(child)
					if child:IsA('Tool') then
						task.wait(0.1)
						applyTextureToTool(child)
					end
				end))
			end
			TexturePack:Clean(lplr.Backpack.ChildAdded:Connect(function(child)
				if child:IsA('Tool') then
					applyTextureToTool(child)
				end
			end))
			task.spawn(function()
				repeat
					if TexturePack.Enabled then
						applyToAllTools()
					end
					task.wait(2)
				until not TexturePack.Enabled
			end)
		end
	end,
	Tooltip = 'Changes sword and item textures. Set custom texture/mesh IDs below.',
})
SwordTexture = TexturePack:CreateTextBox({
	Name = 'Sword Texture ID',
	Default = '',
	Placeholder = 'rbxassetid://...',
	Darker = true,
})
SwordMesh = TexturePack:CreateTextBox({
	Name = 'Sword Mesh ID',
	Default = '',
	Placeholder = 'rbxassetid://...',
	Darker = true,
})
