-- AutoGapple module for FadeWare Bedwars
local AutoGapple
local HealthThreshold
local Delay

AutoGapple = vape.Categories.Utility:CreateModule({
	Name = 'AutoGapple',
	Function = function(callback)
		if callback then
			task.spawn(function()
				repeat
					if AutoGapple.Enabled and entitylib.isAlive then
						local health = entitylib.character.Humanoid.Health
						local maxHealth = entitylib.character.Humanoid.MaxHealth
						local threshold = (HealthThreshold.Value / 100) * maxHealth
						if health <= threshold and health > 0 then
							local inventory = bedwars.getInventory and bedwars.getInventory(lplr) or nil
							if inventory then
								for _, item in inventory.items do
									local itemName = item.itemType or ''
									if itemName:lower():find('apple') or itemName:lower():find('heal') or itemName:lower():find('potion') then
										pcall(function()
											if item.tool then
												switchItem(item.tool, 0)
												task.wait(0.1)
												if bedwars.ConsumeController then
													local consumeRemote = bedwars.Client:Get(remotes.ConsumeItem)
													if consumeRemote then
														consumeRemote:CallServerAsync({item = item})
													end
												end
											end
										end)
										task.wait(Delay.Value)
										break
									end
								end
							end
						end
					end
					task.wait(0.5)
				until not AutoGapple.Enabled
			end)
		end
	end,
	Tooltip = 'Automatically eats golden apples when health is low',
})
HealthThreshold = AutoGapple:CreateSlider({
	Name = 'Health threshold',
	Min = 1,
	Max = 99,
	Default = 50,
	Suffix = '%',
})
Delay = AutoGapple:CreateSlider({
	Name = 'Consume delay',
	Min = 1,
	Max = 10,
	Default = 2,
	Suffix = 's',
})
