--!strict
local FlashlightController = require(script.Parent.FlashlightController)

FlashlightController.init()

-- Auto-toggle on at start for immediate immersive experience
task.delay(1, function()
	FlashlightController.toggle()
end)
