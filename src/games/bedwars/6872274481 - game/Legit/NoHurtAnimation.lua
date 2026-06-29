-- NoHurtAnimation module for FadeWare Bedwars
local NoHurtAnimation
local RemoveColor
local RemoveAnimation

NoHurtAnimation = vape.Categories.Legit:CreateModule({
	Name = 'NoHurtAnimation',
	Function = function(callback)
		if callback then
			NoHurtAnimation:Clean(runService.Heartbeat:Connect(function()
				if entitylib.isAlive then
					local hum = entitylib.character.Humanoid
					if RemoveColor.Enabled then
						for _, v in entitylib.character.Character:GetChildren() do
							if v:IsA('BodyColors') then
								v.HeadColor = BrickColor.new('Medium stone grey')
								v.LeftArmColor = BrickColor.new('Medium stone grey')
								v.RightArmColor = BrickColor.new('Medium stone grey')
								v.TorsoColor = BrickColor.new('Medium stone grey')
								v.LeftLegColor = BrickColor.new('Medium stone grey')
								v.RightLegColor = BrickColor.new('Medium stone grey')
							end
						end
					end
					if RemoveAnimation.Enabled then
						if hum:GetState() == Enum.HumanoidStateType.Physics then
							hum:ChangeState(Enum.HumanoidStateType.GettingUp)
						end
					end
				end
			end))
		end
	end,
	Tooltip = 'Removes the hurt animation and color flash when taking damage',
})
RemoveColor = NoHurtAnimation:CreateToggle({
	Name = 'Remove color flash',
	Default = true,
})
RemoveAnimation = NoHurtAnimation:CreateToggle({
	Name = 'Remove animation',
	Default = true,
})
