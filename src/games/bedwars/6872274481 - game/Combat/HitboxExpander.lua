-- HitboxExpander module for FadeWare Bedwars
local HitboxExpander
local HitboxSize
local HitboxTransparency
local HitboxColor
local ShowHitbox

HitboxExpander = vape.Categories.Combat:CreateModule({
	Name = 'HitboxExpander',
	Function = function(callback)
		if callback then
			HitboxExpander:Clean(runService.Heartbeat:Connect(function()
				for _, ent in entitylib.list do
					if ent ~= entitylib.character and ent.Player and entitylib.isAlive(ent) then
						local root = ent.RootPart
						if root then
							local hitbox = root:FindFirstChild('FadeWareHitbox')
							if not hitbox then
								hitbox = Instance.new('Part')
								hitbox.Name = 'FadeWareHitbox'
								hitbox.Anchored = true
								hitbox.CanCollide = false
								hitbox.CanQuery = false
								hitbox.CanTouch = false
								hitbox.Material = Enum.Material.ForceField
								hitbox.Parent = root
							end
							hitbox.Size = Vector3.new(HitboxSize.Value, HitboxSize.Value, HitboxSize.Value)
							hitbox.CFrame = root.CFrame
							hitbox.Transparency = ShowHitbox.Enabled and HitboxTransparency.Value or 1
							hitbox.Color = HitboxColor.Value
						end
					end
				end
			end))
			HitboxExpander:Clean(function()
				for _, ent in entitylib.list do
					if ent.RootPart then
						local hitbox = ent.RootPart:FindFirstChild('FadeWareHitbox')
						if hitbox then hitbox:Destroy() end
					end
				end
			end)
		end
	end,
	Tooltip = 'Expands enemy hitboxes for easier hitting',
})
HitboxSize = HitboxExpander:CreateSlider({
	Name = 'Hitbox size',
	Min = 1,
	Max = 20,
	Default = 5,
	Suffix = ' studs',
})
HitboxTransparency = HitboxExpander:CreateSlider({
	Name = 'Transparency',
	Min = 0,
	Max = 1,
	Default = 0.5,
	Suffix = function(val)
		return math.floor(val * 100)..'%'
	end,
})
HitboxColor = HitboxExpander:CreateColorSlider({
	Name = 'Hitbox color',
	Default = Color3.fromRGB(255, 0, 0),
})
ShowHitbox = HitboxExpander:CreateToggle({
	Name = 'Show hitbox',
	Default = true,
})
