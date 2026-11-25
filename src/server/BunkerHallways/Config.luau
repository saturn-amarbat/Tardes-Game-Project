--!strict
return table.freeze({
	Seed = 7419,
	Origin = CFrame.new(0, 38, -160),
	Doorway = Vector2.new(8, 9),
	Height = 12,
	StreamTimeout = 1.5,
	-- Full, Short, or Skip. The server still streams, locks, and lands the party.
	FallMode = "Full",
})
