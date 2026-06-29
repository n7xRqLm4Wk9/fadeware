-- LowHealthAlert module for FadeWare Bedwars
local LowHealthAlert
local HealthThreshold
local AlertSound
local alerted = false

LowHealthAlert = vape.Categories.Utility:CreateModule({
	Name = 'LowHealthAlert',
	Function = function(callback)
		if callback then
			LowHealthAlert:Clean(runService.Heartbeat:Connect(function()
				if entitylib.isAlive then
					local health = entitylib.character.Humanoid.Health
					local maxHealth = entitylib.character.Humanoid.MaxHealth
					local threshold = (HealthThreshold.Value / 100) * maxHealth
					if health <= threshold and health > 0 then
						if not alerted then
							alerted = true
							notif('LowHealthAlert', 'Health is low! ('..math.floor(health)..' HP)', 3, 'alert')
							if AlertSound.Enabled then
								local sound = Instance.new('Sound')
								sound.SoundId = 'rbxassetid://4590666217'
								sound.Volume = 1
								sound.Parent = workspace
								sound:Play()
								task.delay(2, function() sound:Destroy() end)
							end
						end
					else
						alerted = false
					end
				end
			end))
		end
	end,
	Tooltip = 'Alerts you when your health drops below a threshold',
})
HealthThreshold = LowHealthAlert:CreateSlider({
	Name = 'Threshold',
	Min = 1,
	Max = 99,
	Default = 30,
	Suffix = '%',
})
AlertSound = LowHealthAlert:CreateToggle({
	Name = 'Play sound',
	Default = true,
})
