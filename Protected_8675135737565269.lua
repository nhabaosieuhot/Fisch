local NPCs = game:GetService("Workspace"):FindFirstChild("NPCs")
if not NPCs then return end
local Players = game:GetService("Players")

local function randomChar()
    local groups = {
        {48, 57},   -- 0–9
        {65, 90},   -- A–Z
        {97, 122}   -- a–z
    }
    local group = groups[math.random(1, #groups)]
    return string.char(math.random(group[1], group[2]))
end

function lol()
	local Store = NPCs:GetChildren()
	if #Store < 1 then return end
	for i=1,#Store do
		local Model = Store[i]
		if Players:GetPlayerFromCharacter(Model) then continue end
		local fakePlayer = Instance.new("Player")
		local final = ''
		for i=1,math.random(4,6) do
			final = randomChar() .. final
		end
		local userId = math.random(1000,10000)
		fakePlayer.Name = "rotterygose " .. final
		fakePlayer.DisplayName = final
		fakePlayer.UserId = userId
		fakePlayer.CharacterAppearanceId = userId
		fakePlayer.Character = Model
		pcall(function() fakePlayer.Parent = game.Players end)
		task.wait()
	end
end

lol()

NPCs.ChildAdded:Connect(function(child)
	local fakePlayer = Instance.new("Player")
	local final = ''
	for i=1,math.random(4,6) do
		final = randomChar() .. final
	end
	local userId = math.random(1000,10000)
	fakePlayer.Name = final
	fakePlayer.DisplayName = final
	fakePlayer.UserId = userId
	fakePlayer.CharacterAppearanceId = userId
	fakePlayer.Character = child
	pcall(function() fakePlayer.Parent = game.Players end)
end)

NPCs.ChildRemoved:Connect(function(child)
	local player = Players:GetPlayerFromCharacter(child)
	if player then player:Destroy() end
end)
