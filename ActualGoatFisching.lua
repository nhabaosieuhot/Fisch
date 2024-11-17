_G.Toggle = false
local function getCasting()
    local cached = tick()
    local pressed = false
    local lastAutocast = 0
    
    while true do
        local success, err = pcall(function()
            while true do
                if not _G.Toggle then 
                    if pressed then
                        mouse1release()
                        pressed = false
                    end
                    wait()
                    continue
                end
                
                local current = tick()
                local players = findfirstchild(Game, "Players")
                if not players then wait() continue end
                
                local localplayer = getlocalplayer()
                if not localplayer then wait() continue end
                
                local Character = getcharacter(localplayer)
                if Character then
                    local Tools = findfirstchildofclass(Character, "Tool")
                    if Tools and string.match(getname(Tools), "Rod") then
                        local RluaCharacter = game.Players.localPlayer.Character
                        if RluaCharacter and type(RluaCharacter) == "table" then
                            local RLuaTool = RluaCharacter:FindFirstChildOfClass("Tool")
                            if RLuaTool and string.match(RLuaTool.Name, "Rod") then
                                local RLuaValues = RLuaTool:FindFirstChild("values")
                                if RLuaValues and type(RLuaValues) == "table" then
                                    local RluaCast = RLuaValues:FindFirstChild("casted")
                                    if RluaCast and type(RluaCast) == "table" then
                                        _G.CastedValue = RluaCast.Value
                                    end
                                end
                                
                                if _G.CastedValue == false then
                                    pressed = false
                                end
                                
                                if _G.CastedValue ~= true then
                                    if not pressed then
                                        mouse1press()
                                        pressed = true
                                        cached = tick()
                                    end
                                    
                                    local humanoidRootPart = findfirstchild(Character, "HumanoidRootPart")
                                    if humanoidRootPart then
                                        local power = findfirstchild(humanoidRootPart, "power")
                                        if power then
                                            local powerbar = findfirstchild(power, "powerbar")
                                            if powerbar then
                                                local bar = findfirstchild(powerbar, "bar")
                                                if bar then
                                                    local success, perfect_value = pcall(function()
                                                        return getmemoryvalue(bar, 0x308, "float")
                                                    end)
                                                    
                                                    if success and perfect_value then
                                                        current = tick()
                                                        
                                                        if (perfect_value >= 0.98 and perfect_value <= 1) or perfect_value == 0 then
                                                            if pressed then
                                                                mouse1release()
                                                                pressed = false
                                                                cached = current
                                                            end
                                                        elseif pressed then
                                                            local holdTime = current - cached
                                                            if holdTime >= 5 then
                                                                mouse1release()
                                                                pressed = false
                                                                cached = current
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    if current - cached > 50 then
                        if current - lastAutocast > 5 then
                            mouse1press()
                            wait(0.5)
                            mouse1release()
                            pressed = false
                            cached = current
                            lastAutocast = current
                        end
                    end
                end
                wait()
            end
        end)
        
        if not success then
            warn("Casting Error:", err)
            if pressed then
                mouse1release()
            end
            pressed = false
            wait(1)
        end
    end
end

local function Shake()
    local backslashpressed = false
    
    while true do
        local success, err = pcall(function()
            while true do
                if not _G.Toggle then 
                    if backslashpressed then
                        keyrelease(0xDC)
                        backslashpressed = false
                    end
                    wait()
                    continue 
                end
                
                local PlayerGui = game.Players.localPlayer:FindFirstChild("PlayerGui")
                if PlayerGui and type(PlayerGui) == "table" then
                    local shakeui = PlayerGui:FindFirstChild("shakeui")
                    if shakeui and type(shakeui) == "table" then
                        if not backslashpressed then
                            keypress(0xDC)
                            backslashpressed = true
                        end
                        
                        keypress(0x53)    
                        keyrelease(0x53)
                        
                        keypress(0x0D)    
                        keyrelease(0x0D)
                    else
                        if backslashpressed then
                            keyrelease(0xDC)
                            backslashpressed = false
                        end
                    end
                end
                wait(0.3)
            end
        end)
        
        if not success then
            warn("Shake Error:", err)
            wait(1)
        end
    end
end

local function Reeling()
    local cached = tick()
    
    while true do
        local success, err = pcall(function()
            while true do
                if not _G.Toggle then 
                    wait()
                    continue 
                end
                
                local localplayer = getlocalplayer()
                if not localplayer then wait() continue end
                
                local playerGui = findfirstchild(localplayer, "PlayerGui")
                if not playerGui then wait() continue end
                
                local current = tick()
                local reel = findfirstchild(playerGui, "reel")
                if not reel then 
                    cached = current
                    wait() 
                    continue 
                end
                
                local bar = findfirstchild(reel, "bar")
                if not bar then 
                    cached = current
                    wait() 
                    continue 
                end
                
                if current - cached > 1.2 then
                    local playerbar = findfirstchild(bar, "playerbar")
                    local fish = findfirstchild(bar, "fish")
                    
                    if playerbar and fish then
                        local success, fishX = pcall(function()
                            return getmemoryvalue(fish, 0x2f0, "float")
                        end)
                        
                        if success and fishX then
                            local clampedX = math.clamp(fishX, 0.15, 0.9)
                            pcall(function()
                                setmemoryvalue(playerbar, 0x2f0, "float", clampedX)
                            end)
                        end
                    end
                end
                wait()
            end
        end)
        
        if not success then
            warn("Reeling Error:", err)
            wait(1)
        end
    end
end


local function startScript()
    local functions = {
        {name = "Casting", func = getCasting},
        {name = "Shake", func = Shake},
        {name = "Reeling", func = Reeling}
    }
    
    for _, funcData in ipairs(functions) do
        spawn(function()
            local success, err = pcall(function()
                funcData.func()
            end)
            
            if not success then
                warn(funcData.name, "crashed with error [This shit never happening ong fr]:", err)
                wait(2)
            end
        end)
    end
end
local Text1 = Drawing.new("Text")
local Text2 = Drawing.new("Text")
local Screen = getscreendimensions()
Text1.Text = "On | Press [F1]"
Text2.Text = "Off | Press [F1]"
Text1.Size = 14
Text2.Size = 14
Text1.Visible = true
Text2.Visible = true
Text1.Font = 2
Text2.Font = 2
Text1.Position = {0, Screen.y/2}
Text2.Position = {0, Screen.y/2 + 14}
local function keycheck()
    local cached = tick()
    while true do
        local current = tick()
        for _, key in ipairs(getpressedkeys()) do
            if key == "F1" and current - cached > 0.8 then
                _G.Toggle = not _G.Toggle
                cached = current
            end
            if _G.Toggle then
                Text1.Color = {0,255,0}
                Text2.Color = {255,0,0}
            else
                Text1.Color = {255,0,0}
                Text2.Color = {0,255,0}
            end
            wait(0.1)
        end
        wait()
    end
end

spawn(keycheck)



pcall(startScript)
