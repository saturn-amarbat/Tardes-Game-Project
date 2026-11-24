--!strict
local FlashlightController = require(script.FlashlightController)
require(script.FlashlightReplicaClient).init()
require(script.PrologueController).init()
require(script.ObjectiveHUD).init()

FlashlightController.init()

-- Auto-toggle flashlight on after spawn delay.
task.delay(1, function()
	FlashlightController.toggle()
end)
