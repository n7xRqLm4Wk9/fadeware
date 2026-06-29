-- AutoQueue module for FadeWare Bedwars
local AutoQueue
local QueueMode
local QueueDelay

AutoQueue = vape.Categories.Utility:CreateModule({
	Name = 'AutoQueue',
	Function = function(callback)
		if callback then
			task.spawn(function()
				repeat
					if AutoQueue.Enabled then
						local inGameVal = false
						pcall(function()
							inGameVal = bedwars.Store and bedwars.Store:getState().Game.matchState ~= 0 or false
						end)
						if not inGameVal then
							task.wait(QueueDelay.Value)
							pcall(function()
								if bedwars.QueueController then
									bedwars.QueueController:EnterQueue(QueueMode.Value)
								end
							end)
							notif('AutoQueue', 'Queued for '..QueueMode.Value, 3)
						end
					end
					task.wait(5)
				until not AutoQueue.Enabled
			end)
		end
	end,
	Tooltip = 'Automatically queues for a new Bedwars game when in the lobby',
})
QueueMode = AutoQueue:CreateDropdown({
	Name = 'Game Mode',
	List = {'bedwars', 'bedwars_test', 'castle', 'capture'},
	Default = 'bedwars',
})
QueueDelay = AutoQueue:CreateSlider({
	Name = 'Queue delay',
	Min = 1,
	Max = 30,
	Default = 5,
	Suffix = 's',
})
