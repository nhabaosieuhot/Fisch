SET_SCHEDULER_TIMEOUT(false)
local UIHelper = {
    windows = {},
    currentWindowId = nil,
    mouseService = nil,
    activeDropdownId = nil,
    activeInputId = nil, -- Tracks the currently focused input field {windowId, elementIndex}
    lastPressedKeys = {},
    caretBlinkTimer = 0,
    caretVisible = true,
    uiClickConsumedThisFrame = false,
    
    areAllWindowsVisible = true,
    toggleKey = "Delete", 
    wasToggleKeyPressedLastFrame = false,
    
    mousePosition = {x=0, y=0},
    leftCurrentlyPressed = false,
    wasLeftPressedLastFrame = false,

    defaultTitleBarColor = {41, 74, 122},
    hoverTitleBarColor = {61, 94, 142},
    draggingTitleBarColor = {81, 114, 162},
    defaultWindowBgColor = {15, 15, 15},

    defaultToggleOutlineColor = {100, 100, 100},
    defaultToggleOffColor = {50, 50, 50},    
    defaultToggleOnColor = {70, 130, 180},  
    defaultTextColor = {255, 255, 255},

    defaultDropdownBgColor = {50, 50, 50},         
    defaultDropdownOutlineColor = {100, 100, 100},  
    defaultDropdownTextColor = {220, 220, 220},     
    defaultDropdownArrowColor = {200, 200, 200},    
    defaultDropdownItemHoverBgColor = {70, 90, 110},
    defaultDropdownSelectedItemTextColor = {120, 180, 255}, 
    defaultDropdownOpenOutlineColor = {100, 150, 200}, 

    defaultButtonBgColor = {80, 80, 80},
    defaultButtonHoverBgColor = {100, 100, 100},
    defaultButtonTextColor = {255, 255, 255},

    defaultInputBgColor = {30, 30, 30},
    defaultInputTextColor = {220, 220, 220},
    defaultInputPlaceholderColor = {100, 100, 100},
    defaultInputBorderColor = {80, 80, 80},
    defaultInputFocusedBorderColor = {100, 150, 200},
    defaultInputCaretColor = {200, 200, 200},
}

local DEFAULT_PADDING = 5

local function GetTextWidth(text, size)
    -- Placeholder: Implement this function to return the width of the text
    -- based on the font and size used in your game engine.
    return (#text * size * 0.6) -- Rough estimate
end

local function IsWithinRegion(pos, regionObject)
    if not regionObject then return false end
    local regionSize = RetOB(regionObject, "Size")
    local regionPosition = RetOB(regionObject, "Position")
    if not regionSize or not regionPosition then return false end

    local topLeft = regionPosition
    local bottomRight = {x = regionPosition.x + regionSize.x, y = regionPosition.y + regionSize.y}
    
    return (pos.x >= topLeft.x and pos.x <= bottomRight.x and pos.y >= topLeft.y and pos.y <= bottomRight.y)
end

function UIHelper:_SetPropertyIfChanged(ob, propName, newValue, cache, cacheKey)
    if not ob or not cache then return end 

    local oldVal = cache[cacheKey]
    local changed = false

    if type(newValue) == "table" then
        if type(oldVal) ~= "table" then 
            changed = true
        else
            if #newValue ~= #oldVal then
                changed = true
            else
                for i = 1, #newValue do
                    if type(newValue[i]) == "table" and type(oldVal[i]) == "table" then
                        if #newValue[i] ~= #oldVal[i] then
                            changed = true; break
                        end
                        for j=1, #newValue[i] do
                             if newValue[i][j] ~= oldVal[i][j] then changed = true; break end
                        end
                        if changed then break end
                    elseif newValue[i] ~= oldVal[i] then
                        changed = true
                        break
                    end
                end
            end
        end
    else 
        if oldVal ~= newValue then
            changed = true
        end
    end

    if changed then
        SetOB(ob, propName, newValue)
        if type(newValue) == "table" then
            local copy = {}
            for i = 1, #newValue do
                if type(newValue[i]) == "table" then 
                    local subCopy = {}
                    for j=1, #newValue[i] do subCopy[j] = newValue[i][j] end
                    copy[i] = subCopy
                else
                    copy[i] = newValue[i]
                end
            end
            cache[cacheKey] = copy 
        else
            cache[cacheKey] = newValue
        end
    end
end

function UIHelper:Initialize(options)
    local opts = options or {}
    self.mouseService = opts.mouseServiceInstance or findservice(Game, "MouseService")

    if not self.mouseService then
        print("UIHelper Error: MouseService instance not provided and could not be found.")
        return false
    end
    self.toggleKey = opts.toggleKey or self.toggleKey 
    self.areAllWindowsVisible = true
    self.wasToggleKeyPressedLastFrame = false
    return true
end

function UIHelper:UpdateInputState(mouseX, mouseY, isLeftPressed)
    self.mousePosition = {x = mouseX, y = mouseY}
    self.leftCurrentlyPressed = isLeftPressed
end

function UIHelper:BeginFrame()
    self.uiClickConsumedThisFrame = false 

    -- Caret blink logic
    self.caretBlinkTimer = (self.caretBlinkTimer + 0.016) % 1 -- Assuming roughly 60 FPS, blink every 0.5s
    if self.caretBlinkTimer < 0.5 then
        self.caretVisible = true
    else
        self.caretVisible = false
    end

    local pressedKeys = getpressedkeys() 
    local newLastPressedKeys = {}
    local justPressedChars = {}

    local keyMap = {
        Space = " ", Period = ".", Comma = ",", Minus = "-", Underscore = "_",
        Equals = "=", Plus = "+", LeftBracket = "[", RightBracket = "]",
        Backslash = "\\", Semicolon = ";", Quote = "'", Slash = "/",
        NumPad0 = "0", NumPad1 = "1", NumPad2 = "2", NumPad3 = "3", NumPad4 = "4",
        NumPad5 = "5", NumPad6 = "6", NumPad7 = "7", NumPad8 = "8", NumPad9 = "9",
        D0 = "0", D1 = "1", D2 = "2", D3 = "3", D4 = "4", D5 = "5", D6 = "6", D7 = "7", D8 = "8", D9 = "9"
        -- Add other simple mappings as needed. Shift states are not handled here.
    }

    for _, key in ipairs(pressedKeys) do
        newLastPressedKeys[key] = true
        local previouslyPressed = false
        for lastKey, _ in pairs(self.lastPressedKeys) do
            if lastKey == key then
                previouslyPressed = true
                break
            end
        end
        if not previouslyPressed then
            if #key == 1 and key:match("%a") then -- Single alphabet character
                table.insert(justPressedChars, key:lower()) -- Convert to lowercase for now
            elseif keyMap[key] then
                table.insert(justPressedChars, keyMap[key])
            elseif key == "Backspace" then
                 table.insert(justPressedChars, "Backspace")
            elseif key == "Enter" or key == "Return" or key == "NumPadEnter" then
                 table.insert(justPressedChars, "Enter")
            end
        end
    end
    self.lastPressedKeys = newLastPressedKeys

    if self.toggleKey then
        local pressedKeys = getpressedkeys() 
        local toggleKeyCurrentlyPressed = false
        for _, key in ipairs(pressedKeys) do
            if key == self.toggleKey then 
                toggleKeyCurrentlyPressed = true
                break
            end
        end

        if toggleKeyCurrentlyPressed and not self.wasToggleKeyPressedLastFrame then
            self.areAllWindowsVisible = not self.areAllWindowsVisible
            for windowId, _ in pairs(self.windows) do
                self:SetWindowVisible(windowId, self.areAllWindowsVisible) 
            end
            if not self.areAllWindowsVisible and self.activeDropdownId then 
                local activeWin = self.windows[self.activeDropdownId.windowId]
                if activeWin then
                    local activeEl = activeWin.elements[self.activeDropdownId.elementIndex]
                    if activeEl and (activeEl.type == "dropdown" or activeEl.type == "multidropdown") then
                        activeEl.isOpen = false
                        if activeEl.obMainBoxBorder then
                           local key_suffix = (activeEl.type == "multidropdown") and "_mdd" or "_dd"
                           local border_color_key = "obMainBoxBorder_color_val" .. key_suffix
                           self:_SetPropertyIfChanged(activeEl.obMainBoxBorder, "Color", activeEl.colors.outline or self.defaultDropdownOutlineColor, activeEl.optionsCache, border_color_key)
                        end
                    end
                end
                self.activeDropdownId = nil
            end
        end
        self.wasToggleKeyPressedLastFrame = toggleKeyCurrentlyPressed
    end

    local mouseJustPressed = self.leftCurrentlyPressed and not self.wasLeftPressedLastFrame
    if mouseJustPressed and self.activeDropdownId then
        local activeWin = self.windows[self.activeDropdownId.windowId]
        if activeWin then
            local activeEl = activeWin.elements[self.activeDropdownId.elementIndex]
            if activeEl and (activeEl.type == "dropdown" or activeEl.type == "multidropdown") then
                local mainBoxAbsPos = RetOB(activeEl.obMainBox, "Position")
                local mainBoxAbsSize = RetOB(activeEl.obMainBox, "Size")
                local itemsListHeight = 0
                if activeEl.items and activeEl.itemHeight then
                    itemsListHeight = #activeEl.items * activeEl.itemHeight
                end
                
                local wasClickOnDropdown = false
                if self.mousePosition.x >= mainBoxAbsPos.x and self.mousePosition.x <= mainBoxAbsPos.x + mainBoxAbsSize.x and
                   self.mousePosition.y >= mainBoxAbsPos.y and self.mousePosition.y <= mainBoxAbsPos.y + mainBoxAbsSize.y then
                    wasClickOnDropdown = true
                end
                if not wasClickOnDropdown and activeEl.isOpen then
                    if self.mousePosition.x >= mainBoxAbsPos.x and self.mousePosition.x <= mainBoxAbsPos.x + mainBoxAbsSize.x and
                       self.mousePosition.y >= mainBoxAbsPos.y + mainBoxAbsSize.y and 
                       self.mousePosition.y <= mainBoxAbsPos.y + mainBoxAbsSize.y + itemsListHeight then
                        wasClickOnDropdown = true
                    end
                end

                if not wasClickOnDropdown then
                    activeEl.isOpen = false
                    local key_suffix = (activeEl.type == "multidropdown") and "_mdd" or "_dd"
                    local bg_color_key = "obMainBox_color_val" .. key_suffix
                    local border_color_key = "obMainBoxBorder_color_val" .. key_suffix
                    
                    self:_SetPropertyIfChanged(activeEl.obMainBox, "Color", activeEl.colors.bg or self.defaultDropdownBgColor, activeEl.optionsCache, bg_color_key)
                    self:_SetPropertyIfChanged(activeEl.obMainBoxBorder, "Color", activeEl.colors.outline or self.defaultDropdownOutlineColor, activeEl.optionsCache, border_color_key)
                    self.activeDropdownId = nil
                    self.uiClickConsumedThisFrame = true 
                end
            else
                self.activeDropdownId = nil 
            end
        else
             self.activeDropdownId = nil 
        end
    end

    -- Handle input field character processing if an input is active
    if self.activeInputId and #justPressedChars > 0 then
        local activeWin = self.windows[self.activeInputId.windowId]
        if activeWin then
            local activeEl = activeWin.elements[self.activeInputId.elementIndex]
            if activeEl and activeEl.type == "input" then
                local changed = false
                for _, charCode in ipairs(justPressedChars) do
                    if charCode == "Backspace" then
                        if #activeEl.currentText > 0 then
                            activeEl.currentText = activeEl.currentText:sub(1, -2)
                            changed = true
                        end
                    elseif charCode == "Enter" then
                        if activeEl.onEnter then
                            local cb = activeEl.onEnter
                            local text_at_call = activeEl.currentText
                            spawn(function() pcall(cb, text_at_call) end)
                        end
                        -- Optionally unfocus: self.activeInputId = nil
                        -- For now, Enter does not automatically unfocus
                    else -- Append character
                        -- Basic max length check (optional)
                        -- if not activeEl.maxLength or #activeEl.currentText < activeEl.maxLength then
                        activeEl.currentText = activeEl.currentText .. charCode
                        changed = true
                        -- end
                    end
                end
                if changed and activeEl.onChanged then
                    local cb = activeEl.onChanged
                    local text_at_call = activeEl.currentText
                    spawn(function() pcall(cb, text_at_call) end)
                end
            else
                self.activeInputId = nil -- Active element is no longer an input or valid
            end
        else
            self.activeInputId = nil -- Active window is no longer valid
        end
    elseif mouseJustPressed and not self.uiClickConsumedThisFrame then 
        -- If no dropdown was clicked and no other UI consumed the click,
        -- check if we clicked outside an active input to unfocus it.
        if self.activeInputId then
            local activeWin = self.windows[self.activeInputId.windowId]
            if activeWin then
                local activeEl = activeWin.elements[self.activeInputId.elementIndex]
                if activeEl and activeEl.type == "input" then
                    if not IsWithinRegion(self.mousePosition, activeEl.obBox) then
                        self.activeInputId = nil
                        -- Potentially self.uiClickConsumedThisFrame = true here if unfocusing should consume click
                    end
                else
                    self.activeInputId = nil -- Stale activeInputId
                end
            else 
                self.activeInputId = nil -- Stale activeInputId
            end
        end
    end
end

function UIHelper:EndFrame()
    self.wasLeftPressedLastFrame = self.leftCurrentlyPressed
end


function UIHelper:BeginWindow(id, titleText, x, y, width, height)
    if not self.areAllWindowsVisible then
        local window = self.windows[id]
        if window then 
            self:SetWindowVisible(id, false) 
        end
        return false
    end

    local window = self.windows[id]
    local titleBarHeight = 20 

    if not window then
        window = {
            id = id,
            titleText = titleText,
            x = x, y = y, 
            width = width, height = height, 
            initialHeight = height,
            titleBarHeight = titleBarHeight,
            isDragging = false,
            dragOffsetX = 0, dragOffsetY = 0,
            elements = {}, 
            currentElementIndex = 1, 
            
            padding = DEFAULT_PADDING,
            currentLayoutX = 0, 
            currentLayoutY = 0, 
            nextElementY = 0, 
            contentMaxY = 0, 
            cache = {}, 

            titleBarOB = CrtOB("Square"),
            titleTextOB = CrtOB("Text"),
            mainAreaOB = CrtOB("Square"),
        }
        self:_SetPropertyIfChanged(window.titleBarOB, "Position", {x, y}, window.cache, "titleBarPos")
        self:_SetPropertyIfChanged(window.titleBarOB, "Size", {width, titleBarHeight}, window.cache, "titleBarSize")
        self:_SetPropertyIfChanged(window.titleBarOB, "Color", self.defaultTitleBarColor, window.cache, "titleBarColor")
        self:_SetPropertyIfChanged(window.titleBarOB, "Filled", true, window.cache, "titleBarFilled")
        self:_SetPropertyIfChanged(window.titleBarOB, "Visible", true, window.cache, "titleBarVisible")

        self:_SetPropertyIfChanged(window.titleTextOB, "Text", titleText, window.cache, "titleText")
        self:_SetPropertyIfChanged(window.titleTextOB, "Position", {x + 5, y + (titleBarHeight - 10)/2}, window.cache, "titleTextPos")
        self:_SetPropertyIfChanged(window.titleTextOB, "Size", 10, window.cache, "titleTextSize") 
        self:_SetPropertyIfChanged(window.titleTextOB, "Color", {255,255,255}, window.cache, "titleTextColor")
        self:_SetPropertyIfChanged(window.titleTextOB, "Visible", true, window.cache, "titleTextVisible")
        
        self:_SetPropertyIfChanged(window.mainAreaOB, "Position", {x, y + titleBarHeight}, window.cache, "mainAreaPos")
        self:_SetPropertyIfChanged(window.mainAreaOB, "Size", {width, height - titleBarHeight}, window.cache, "mainAreaSize")
        self:_SetPropertyIfChanged(window.mainAreaOB, "Color", self.defaultWindowBgColor, window.cache, "mainAreaColor")
        self:_SetPropertyIfChanged(window.mainAreaOB, "Filled", true, window.cache, "mainAreaFilled")
        self:_SetPropertyIfChanged(window.mainAreaOB, "Visible", true, window.cache, "mainAreaVisible")
        
        self.windows[id] = window
    else
        window.cache = window.cache or {} 
        if window.x ~= x or window.y ~= y or window.width ~= width or window.height ~= height or window.titleText ~= titleText then
            window.x = x; window.y = y; window.width = width; window.height = height; window.titleText = titleText;
            if height ~= window.initialHeight then window.initialHeight = height end 

            self:_SetPropertyIfChanged(window.titleBarOB, "Position", {x,y}, window.cache, "titleBarPos")
            self:_SetPropertyIfChanged(window.titleBarOB, "Size", {width, window.titleBarHeight}, window.cache, "titleBarSize")
            self:_SetPropertyIfChanged(window.titleTextOB, "Text", titleText, window.cache, "titleText")
            self:_SetPropertyIfChanged(window.titleTextOB, "Position", {x + 5, y + (window.titleBarHeight - 10)/2}, window.cache, "titleTextPos")
            self:_SetPropertyIfChanged(window.mainAreaOB, "Position", {x, y + window.titleBarHeight}, window.cache, "mainAreaPos")
            self:_SetPropertyIfChanged(window.mainAreaOB, "Size", {width, height - window.titleBarHeight}, window.cache, "mainAreaSize")
        end

        self:_SetPropertyIfChanged(window.titleBarOB, "Visible", true, window.cache, "titleBarVisible")
        self:_SetPropertyIfChanged(window.titleTextOB, "Visible", true, window.cache, "titleTextVisible")
        self:_SetPropertyIfChanged(window.mainAreaOB, "Visible", true, window.cache, "mainAreaVisible")
    end

    window.currentElementIndex = 1 
    window.currentLayoutX = window.padding 
    window.currentLayoutY = window.padding 
    window.nextElementY = window.padding  
    window.contentMaxY = 0 

    for _, elData in ipairs(window.elements) do
        elData.updatedThisFrame = false 
    end

    self.currentWindowId = id

    local titleBarPos = RetOB(window.titleBarOB, "Position") 
    local mouseJustPressed = self.leftCurrentlyPressed and not self.wasLeftPressedLastFrame

    if not window.isDragging then
        if IsWithinRegion(self.mousePosition, window.titleBarOB) then
            self:_SetPropertyIfChanged(window.titleBarOB, "Color", self.hoverTitleBarColor, window.cache, "titleBarColor")
            if not self.uiClickConsumedThisFrame and mouseJustPressed then 
                window.isDragging = true
                window.dragOffsetX = self.mousePosition.x - titleBarPos.x
                window.dragOffsetY = self.mousePosition.y - titleBarPos.y
                self:_SetPropertyIfChanged(window.titleBarOB, "Color", self.draggingTitleBarColor, window.cache, "titleBarColor")
                self.uiClickConsumedThisFrame = true 
            end
        else
            self:_SetPropertyIfChanged(window.titleBarOB, "Color", self.defaultTitleBarColor, window.cache, "titleBarColor")
        end
    end

    if window.isDragging then
        if self.leftCurrentlyPressed then
            local newWindowX = self.mousePosition.x - window.dragOffsetX
            local newWindowY = self.mousePosition.y - window.dragOffsetY

            window.x = newWindowX
            window.y = newWindowY

            self:_SetPropertyIfChanged(window.titleBarOB, "Position", {newWindowX, newWindowY}, window.cache, "titleBarPos")
            self:_SetPropertyIfChanged(window.titleTextOB, "Position", {newWindowX + 5, newWindowY + (window.titleBarHeight - 10)/2}, window.cache, "titleTextPos")
            
            local newMainAreaX = newWindowX
            local newMainAreaY = newWindowY + window.titleBarHeight
            self:_SetPropertyIfChanged(window.mainAreaOB, "Position", {newMainAreaX, newMainAreaY}, window.cache, "mainAreaPos")
            
            self:_SetPropertyIfChanged(window.titleBarOB, "Color", self.draggingTitleBarColor, window.cache, "titleBarColor")
        else
            window.isDragging = false
            local newColor = IsWithinRegion(self.mousePosition, window.titleBarOB) and self.hoverTitleBarColor or self.defaultTitleBarColor
            self:_SetPropertyIfChanged(window.titleBarOB, "Color", newColor, window.cache, "titleBarColor")
        end
    end
    
    return true 
end

function UIHelper:EndWindow()
    local window = self.windows[self.currentWindowId]
    if window then
        for i = window.currentElementIndex, #window.elements do
            local elData = window.elements[i]
            if elData then 
                local elCache = elData.optionsCache or {}
                if elData.type == "text" then
                    if elData.ob then self:_SetPropertyIfChanged(elData.ob, "Visible", false, elCache, "visible") end 
                elseif elData.type == "square" then
                     if elData.ob then self:_SetPropertyIfChanged(elData.ob, "Visible", false, elCache, "square_visible") end
                elseif elData.type == "toggle" then
                    if elData.obOuter then self:_SetPropertyIfChanged(elData.obOuter, "Visible", false, elCache, "obOuter_visible") end
                    if elData.obInner then self:_SetPropertyIfChanged(elData.obInner, "Visible", false, elCache, "obInner_visible_val") end
                    if elData.obText then self:_SetPropertyIfChanged(elData.obText, "Visible", false, elCache, "obText_visible") end
                elseif elData.type == "dropdown" or elData.type == "multidropdown" then
                    local key_suffix = (elData.type == "multidropdown") and "_mdd" or "_dd"
                    
                    if elData.obMainBox then self:_SetPropertyIfChanged(elData.obMainBox, "Visible", false, elCache, "obMainBox_visible" .. key_suffix) end
                    if elData.obMainBoxBorder then self:_SetPropertyIfChanged(elData.obMainBoxBorder, "Visible", false, elCache, "obMainBoxBorder_visible" .. key_suffix) end
                    if elData.obCurrentText then self:_SetPropertyIfChanged(elData.obCurrentText, "Visible", false, elCache, "obCurrentText_visible" .. key_suffix) end
                    if elData.obArrow then self:_SetPropertyIfChanged(elData.obArrow, "Visible", false, elCache, "obArrow_visible" .. key_suffix) end
                    
                    if elData.itemOBs then 
                        for _, itemDisplay in ipairs(elData.itemOBs) do
                            if itemDisplay.bg then self:_SetPropertyIfChanged(itemDisplay.bg, "Visible", false, itemDisplay.cache_bg, "visible_val" .. key_suffix) end 
                            if itemDisplay.text then self:_SetPropertyIfChanged(itemDisplay.text, "Visible", false, itemDisplay.cache_text, "visible_text_val" .. key_suffix) end 
                        end
                    end
                    elData.isOpen = false 
                    if self.activeDropdownId and self.activeDropdownId.windowId == window.id and self.activeDropdownId.elementIndex == i then
                        self.activeDropdownId = nil
                    end
                elseif elData.type == "button" then
                    if elData.obButton then self:_SetPropertyIfChanged(elData.obButton, "Visible", false, elCache, "obButton_visible") end
                    if elData.obText then self:_SetPropertyIfChanged(elData.obText, "Visible", false, elCache, "obText_visible_button") end
                elseif elData.type == "input" then
                    if elData.obBox then self:_SetPropertyIfChanged(elData.obBox, "Visible", false, elCache, "obBox_visible_input") end
                    if elData.obText then self:_SetPropertyIfChanged(elData.obText, "Visible", false, elCache, "obText_visible_input") end
                    if elData.obCaret then self:_SetPropertyIfChanged(elData.obCaret, "Visible", false, elCache, "obCaret_visible_input") end
                    if self.activeInputId and self.activeInputId.windowId == window.id and self.activeInputId.elementIndex == i then
                        self.activeInputId = nil
                    end
                end
            end
        end
        while #window.elements >= window.currentElementIndex do
            local elDataRemoved = table.remove(window.elements)
            
            
        end

        local requiredMainAreaHeight = window.contentMaxY + window.padding 
        local initialMainAreaHeight = window.initialHeight - window.titleBarHeight
        local currentMainAreaSize = RetOB(window.mainAreaOB, "Size")
        local newMainAreaHeight = math.max(initialMainAreaHeight, requiredMainAreaHeight)
        
        if math.abs(newMainAreaHeight - currentMainAreaSize.y) > 0.1 then 
            self:_SetPropertyIfChanged(window.mainAreaOB, "Size", {currentMainAreaSize.x, newMainAreaHeight}, window.cache, "mainAreaSize")
            window.height = newMainAreaHeight + window.titleBarHeight
        end
    end
    self.currentWindowId = nil
end

function UIHelper:Text(textString, options)
    if not self.currentWindowId then print("UIHelper Error: Text() called outside a BeginWindow/EndWindow block.") return nil end
    local window = self.windows[self.currentWindowId]
    if not window then print("UIHelper Error: Current window not found.") return nil end
    
    options = options or {}
    local relX = options.x 
    local relY = options.y 
    local size = options.size or 10
    local color = options.color or self.defaultTextColor

    local mainAreaPos = RetOB(window.mainAreaOB, "Position")
    local actualRelX, actualRelY
    local isAutoLayout = (options.x == nil and options.y == nil)

    if isAutoLayout then
        actualRelX = window.currentLayoutX
        actualRelY = window.nextElementY
    else
        actualRelX = relX or 0 
        actualRelY = relY or 0 
    end
    
    local elData
    local obToUse

    if window.currentElementIndex <= #window.elements and window.elements[window.currentElementIndex].type == "text" then
        elData = window.elements[window.currentElementIndex]
        obToUse = elData.ob
        elData.optionsCache = elData.optionsCache or {} 
        self:_SetPropertyIfChanged(obToUse, "Visible", true, elData.optionsCache, "visible") 
    else
        obToUse = CrtOB("Text")
        elData = {
            ob = obToUse, 
            type = "text", 
            optionsCache = {} 
        }
        window.elements[window.currentElementIndex] = elData
        self:_SetPropertyIfChanged(obToUse, "Visible", true, elData.optionsCache, "visible") 
    end

    elData.originalRelX = actualRelX 
    elData.originalRelY = actualRelY
    elData.updatedThisFrame = true
    
    elData.optionsCache.textString_arg = textString
    elData.optionsCache.size_arg = size
    elData.optionsCache.color_arg = color
    elData.optionsCache.relX_arg = actualRelX 
    elData.optionsCache.relY_arg = actualRelY 

    self:_SetPropertyIfChanged(obToUse, "Text", textString, elData.optionsCache, "textString_val")
    self:_SetPropertyIfChanged(obToUse, "Position", {mainAreaPos.x + actualRelX, mainAreaPos.y + actualRelY}, elData.optionsCache, "absPosition_val")
    self:_SetPropertyIfChanged(obToUse, "Size", size, elData.optionsCache, "size_val")
    self:_SetPropertyIfChanged(obToUse, "Color", color, elData.optionsCache, "color_val")

    if isAutoLayout then
        window.nextElementY = actualRelY + size + window.padding 
    end
    window.contentMaxY = math.max(window.contentMaxY, actualRelY + size)
    
    window.currentElementIndex = window.currentElementIndex + 1
    return obToUse
end

function UIHelper:Square(options)
    if not self.currentWindowId then print("UIHelper Error: Square() called outside a BeginWindow/EndWindow block.") return nil end
    local window = self.windows[self.currentWindowId]
    if not window then print("UIHelper Error: Current window not found.") return nil end

    options = options or {}
    local relX = options.x or 5
    local relY = options.y or 5 
    local width = options.width or 20
    local height = options.height or 20
    local color = options.color or {100,100,100}
    local filled = options.filled == nil and true or options.filled
    local thickness = options.thickness or 1

    local mainAreaPos = RetOB(window.mainAreaOB, "Position")
    local actualRelX, actualRelY
    local isAutoLayout = (options.x == nil and options.y == nil)

    if isAutoLayout then
        actualRelX = window.currentLayoutX
        actualRelY = window.nextElementY
    else
        actualRelX = relX
        actualRelY = relY
    end
    
    local elData
    local obToUse

    if window.currentElementIndex <= #window.elements and window.elements[window.currentElementIndex].type == "square" then
        elData = window.elements[window.currentElementIndex]
        obToUse = elData.ob
        elData.optionsCache = elData.optionsCache or {}
        self:_SetPropertyIfChanged(obToUse, "Visible", true, elData.optionsCache, "square_visible") 
    else
        obToUse = CrtOB("Square")
        elData = {
            ob = obToUse,
            type = "square",
            originalRelX = actualRelX, 
            originalRelY = actualRelY, 
            optionsCache = {} 
        }
        window.elements[window.currentElementIndex] = elData
        self:_SetPropertyIfChanged(obToUse, "Visible", true, elData.optionsCache, "square_visible") 
    end
    
    elData.originalRelX = actualRelX
    elData.originalRelY = actualRelY
    elData.updatedThisFrame = true

    local squarePos = {mainAreaPos.x + actualRelX, mainAreaPos.y + actualRelY}
    local squareSize = {width, height}

    self:_SetPropertyIfChanged(obToUse, "Position", squarePos, elData.optionsCache, "square_pos")
    self:_SetPropertyIfChanged(obToUse, "Size", squareSize, elData.optionsCache, "square_size")
    self:_SetPropertyIfChanged(obToUse, "Color", color, elData.optionsCache, "square_color")
    self:_SetPropertyIfChanged(obToUse, "Filled", filled, elData.optionsCache, "square_filled")
    if not filled then
        self:_SetPropertyIfChanged(obToUse, "Thickness", thickness, elData.optionsCache, "square_thickness")
    end

    if isAutoLayout then
        window.nextElementY = actualRelY + height + window.padding
    end
    window.contentMaxY = math.max(window.contentMaxY, actualRelY + height)

    window.currentElementIndex = window.currentElementIndex + 1
    return obToUse
end

function UIHelper:Toggle(textString, options)
    if not self.currentWindowId then print("UIHelper Error: Toggle() called outside a BeginWindow/EndWindow block.") return nil end
    local window = self.windows[self.currentWindowId]
    if not window then print("UIHelper Error: Current window not found for Toggle().") return nil end

    options = options or {}
    local relX = options.x 
    local relY = options.y 
    local defaultValue = options.defaultValue or false
    local onChangedCallback = options.onChanged

    local colors = options.colors or {}
    local outlineColor = colors.outline or self.defaultToggleOutlineColor
    local offColor = colors.off or self.defaultToggleOffColor
    local onColor = colors.on or self.defaultToggleOnColor
    local textColorOpt = colors.text or self.defaultTextColor

    local toggleSize = options.size or 16 
    local textGap = options.textGap or 5 
    local textSize = options.textSize or 10

    local mainAreaPos = RetOB(window.mainAreaOB, "Position")
    local actualRelX, actualRelY
    local isAutoLayout = (relX == nil and relY == nil)

    if isAutoLayout then
        actualRelX = window.currentLayoutX
        actualRelY = window.nextElementY
    else
        actualRelX = relX or window.currentLayoutX 
        actualRelY = relY or window.nextElementY 
    end

    local elData, obOuter, obInner, obText

    if window.currentElementIndex <= #window.elements and window.elements[window.currentElementIndex].type == "toggle" then
        elData = window.elements[window.currentElementIndex]
        obOuter = elData.obOuter
        obInner = elData.obInner
        obText = elData.obText
        elData.optionsCache = elData.optionsCache or {}
        self:_SetPropertyIfChanged(obOuter, "Visible", true, elData.optionsCache, "obOuter_visible")
        self:_SetPropertyIfChanged(obInner, "Visible", true, elData.optionsCache, "obInner_visible_val")
        self:_SetPropertyIfChanged(obText, "Visible", true, elData.optionsCache, "obText_visible")
    else
        obOuter = CrtOB("Square")
        obInner = CrtOB("Square")
        obText = CrtOB("Text")
        elData = {
            obOuter = obOuter, obInner = obInner, obText = obText,
            type = "toggle",
            state = defaultValue, 
            onChanged = onChangedCallback,
            optionsCache = {}
        }
        window.elements[window.currentElementIndex] = elData
        elData.state = defaultValue 
        self:_SetPropertyIfChanged(obOuter, "Visible", true, elData.optionsCache, "obOuter_visible")
        self:_SetPropertyIfChanged(obInner, "Visible", true, elData.optionsCache, "obInner_visible_val")
        self:_SetPropertyIfChanged(obText, "Visible", true, elData.optionsCache, "obText_visible") 
    end
    
    if elData.onChanged ~= onChangedCallback then
        elData.onChanged = onChangedCallback
    end

    elData.originalRelX = actualRelX
    elData.originalRelY = actualRelY
    elData.updatedThisFrame = true
    
    elData.optionsCache.textString_arg = textString
    elData.optionsCache.relX_arg = actualRelX; elData.optionsCache.relY_arg = actualRelY;
    elData.optionsCache.toggleSize_arg = toggleSize; elData.optionsCache.textSize_arg = textSize; elData.optionsCache.textGap_arg = textGap;
    elData.optionsCache.outlineColor_arg = outlineColor; elData.optionsCache.offColor_arg = offColor; 
    elData.optionsCache.onColor_arg = onColor; elData.optionsCache.textColor_arg = textColorOpt;

    local outerPos = {mainAreaPos.x + actualRelX, mainAreaPos.y + actualRelY}
    self:_SetPropertyIfChanged(obOuter, "Position", outerPos, elData.optionsCache, "obOuter_pos_val")
    self:_SetPropertyIfChanged(obOuter, "Size", {toggleSize, toggleSize}, elData.optionsCache, "obOuter_size_val")
    self:_SetPropertyIfChanged(obOuter, "Color", outlineColor, elData.optionsCache, "obOuter_color_val")
    self:_SetPropertyIfChanged(obOuter, "Filled", false, elData.optionsCache, "obOuter_filled_val") 
    self:_SetPropertyIfChanged(obOuter, "Thickness", 1, elData.optionsCache, "obOuter_thickness_val") 

    local innerBoxSize = toggleSize - 4 
    local innerBoxOffset = (toggleSize - innerBoxSize) / 2
    local innerPos = {mainAreaPos.x + actualRelX + innerBoxOffset, mainAreaPos.y + actualRelY + innerBoxOffset}
    self:_SetPropertyIfChanged(obInner, "Position", innerPos, elData.optionsCache, "obInner_pos_val")
    self:_SetPropertyIfChanged(obInner, "Size", {innerBoxSize, innerBoxSize}, elData.optionsCache, "obInner_size_val")
    self:_SetPropertyIfChanged(obInner, "Filled", true, elData.optionsCache, "obInner_filled_val")

    local textPos = {mainAreaPos.x + actualRelX + toggleSize + textGap, mainAreaPos.y + actualRelY + (toggleSize - textSize)/2}
    self:_SetPropertyIfChanged(obText, "Text", textString or "", elData.optionsCache, "obText_text_val")
    self:_SetPropertyIfChanged(obText, "Position", textPos, elData.optionsCache, "obText_pos_val")
    self:_SetPropertyIfChanged(obText, "Size", textSize, elData.optionsCache, "obText_size_val")
    self:_SetPropertyIfChanged(obText, "Color", textColorOpt, elData.optionsCache, "obText_color_val")

    local mouseJustPressed = self.leftCurrentlyPressed and not self.wasLeftPressedLastFrame
    if not self.uiClickConsumedThisFrame and mouseJustPressed and IsWithinRegion(self.mousePosition, obOuter) then 
        elData.state = not elData.state 
        if elData.onChanged then
            local cb = elData.onChanged
            local state_at_call = elData.state
            spawn(function() 
                pcall(cb, state_at_call)
                wait(0.1) 
            end)
        end
        self.uiClickConsumedThisFrame = true 
    end

    local currentInnerColor = elData.state and onColor or offColor
    self:_SetPropertyIfChanged(obInner, "Color", currentInnerColor, elData.optionsCache, "obInner_color_val")

    if isAutoLayout then
        window.nextElementY = actualRelY + toggleSize + window.padding
    end
    window.contentMaxY = math.max(window.contentMaxY, actualRelY + toggleSize) 

    window.currentElementIndex = window.currentElementIndex + 1
    return elData 
end

function UIHelper:Button(textString, options)
    if not self.currentWindowId then print("UIHelper Error: Button() called outside a BeginWindow/EndWindow block.") return nil end
    local window = self.windows[self.currentWindowId]
    if not window then print("UIHelper Error: Current window not found for Button().") return nil end

    options = options or {}
    local relX = options.x 
    local relY = options.y 
    local onClickCallback = options.onClick

    local colors = options.colors or {}
    local bgColor = colors.bg or self.defaultButtonBgColor
    local hoverBgColor = colors.hover or self.defaultButtonHoverBgColor
    local textColorOpt = colors.text or self.defaultButtonTextColor

    local buttonWidth = options.width or 100
    local buttonHeight = options.height or 20
    local textSize = options.textSize or 10

    local mainAreaPos = RetOB(window.mainAreaOB, "Position")
    local actualRelX, actualRelY
    local isAutoLayout = (relX == nil and relY == nil)

    if isAutoLayout then
        actualRelX = window.currentLayoutX
        actualRelY = window.nextElementY
    else
        actualRelX = relX or window.currentLayoutX 
        actualRelY = relY or window.nextElementY 
    end

    local elData, obButton, obText

    if window.currentElementIndex <= #window.elements and window.elements[window.currentElementIndex].type == "button" then
        elData = window.elements[window.currentElementIndex]
        obButton = elData.obButton
        obText = elData.obText
        elData.optionsCache = elData.optionsCache or {}
        self:_SetPropertyIfChanged(obButton, "Visible", true, elData.optionsCache, "obButton_visible")
        self:_SetPropertyIfChanged(obText, "Visible", true, elData.optionsCache, "obText_visible_button")
    else
        obButton = CrtOB("Square")
        obText = CrtOB("Text")
        elData = {
            obButton = obButton, obText = obText,
            type = "button",
            onClick = onClickCallback,
            optionsCache = {}
        }
        window.elements[window.currentElementIndex] = elData
        self:_SetPropertyIfChanged(obButton, "Visible", true, elData.optionsCache, "obButton_visible")
        self:_SetPropertyIfChanged(obText, "Visible", true, elData.optionsCache, "obText_visible_button") 
    end
    
    if elData.onClick ~= onClickCallback then
        elData.onClick = onClickCallback
    end

    elData.originalRelX = actualRelX
    elData.originalRelY = actualRelY
    elData.updatedThisFrame = true
    
    elData.optionsCache.textString_arg = textString
    elData.optionsCache.relX_arg = actualRelX; elData.optionsCache.relY_arg = actualRelY;
    elData.optionsCache.buttonWidth_arg = buttonWidth; elData.optionsCache.buttonHeight_arg = buttonHeight; elData.optionsCache.textSize_arg = textSize;
    elData.optionsCache.bgColor_arg = bgColor; elData.optionsCache.hoverBgColor_arg = hoverBgColor; elData.optionsCache.textColor_arg = textColorOpt;

    local buttonPos = {mainAreaPos.x + actualRelX, mainAreaPos.y + actualRelY}
    self:_SetPropertyIfChanged(obButton, "Position", buttonPos, elData.optionsCache, "obButton_pos_val")
    self:_SetPropertyIfChanged(obButton, "Size", {buttonWidth, buttonHeight}, elData.optionsCache, "obButton_size_val")
    self:_SetPropertyIfChanged(obButton, "Color", bgColor, elData.optionsCache, "obButton_color_val")
    self:_SetPropertyIfChanged(obButton, "Filled", true, elData.optionsCache, "obButton_filled_val")

    local textPos = {mainAreaPos.x + actualRelX + (buttonWidth - textSize * #textString) / 2, mainAreaPos.y + actualRelY + (buttonHeight - textSize) / 2}
    self:_SetPropertyIfChanged(obText, "Text", textString or "", elData.optionsCache, "obText_text_val")
    self:_SetPropertyIfChanged(obText, "Position", textPos, elData.optionsCache, "obText_pos_val")
    self:_SetPropertyIfChanged(obText, "Size", textSize, elData.optionsCache, "obText_size_val")
    self:_SetPropertyIfChanged(obText, "Color", textColorOpt, elData.optionsCache, "obText_color_val")

    local mouseJustPressed = self.leftCurrentlyPressed and not self.wasLeftPressedLastFrame
    if not self.uiClickConsumedThisFrame and mouseJustPressed and IsWithinRegion(self.mousePosition, obButton) then 
        if elData.onClick then
            local cb = elData.onClick
            spawn(function() 
                pcall(cb)
                wait(0.1) 
            end)
        end
        self.uiClickConsumedThisFrame = true 
    end

    if isAutoLayout then
        window.nextElementY = actualRelY + buttonHeight + window.padding
    end
    window.contentMaxY = math.max(window.contentMaxY, actualRelY + buttonHeight) 

    window.currentElementIndex = window.currentElementIndex + 1
    return elData 
end

function UIHelper:Dropdown(labelText, options)
    if not self.currentWindowId then print("UIHelper Error: Dropdown() called outside a BeginWindow/EndWindow block.") return nil end
    local window = self.windows[self.currentWindowId]
    if not window then print("UIHelper Error: Current window not found for Dropdown().") return nil end

    local key_suffix = "_dd" 

    options = options or {}
    local items = options.items or {}
    local defaultSelectedItem = options.defaultSelectedItem
    local onItemSelectedCallback = options.onItemSelected

    local colors = options.colors or {}
    local bgColor = colors.bg or self.defaultDropdownBgColor
    local outlineColor = colors.outline or self.defaultDropdownOutlineColor
    local openOutlineColor = colors.openOutline or self.defaultDropdownOpenOutlineColor
    local textColor = colors.text or self.defaultDropdownTextColor
    local arrowColor = colors.arrow or self.defaultDropdownArrowColor
    local itemHoverBgColor = colors.itemHoverBg or self.defaultDropdownItemHoverBgColor
    local selectedItemTextColor = colors.selectedItemText or self.defaultDropdownSelectedItemTextColor

    local relX = options.x
    local relY = options.y
    local width = options.width or 150
    local height = options.height or 20 
    local itemHeight = options.itemHeight or height 
    local textSize = options.textSize or 10
    local arrowSize = math.floor(height * 0.4)

    local mainAreaPos = RetOB(window.mainAreaOB, "Position")
    local actualRelX, actualRelY
    local isAutoLayout = (relX == nil and relY == nil)

    if isAutoLayout then
        actualRelX = window.currentLayoutX
        actualRelY = window.nextElementY
    else
        actualRelX = relX or window.currentLayoutX
        actualRelY = relY or window.nextElementY
    end

    local elData, obMainBox, obCurrentText, obArrow, obMainBoxBorder
    local itemOBs = {} 

    local uniqueElementId = window.id .. "_el" .. window.currentElementIndex

    if window.currentElementIndex <= #window.elements and window.elements[window.currentElementIndex].type == "dropdown" then
        elData = window.elements[window.currentElementIndex]
        obMainBox = elData.obMainBox
        obMainBoxBorder = elData.obMainBoxBorder
        obCurrentText = elData.obCurrentText
        obArrow = elData.obArrow
        itemOBs = elData.itemOBs or {} 

        self:_SetPropertyIfChanged(obMainBox, "Visible", true, elData.optionsCache, "obMainBox_visible" .. key_suffix)
        self:_SetPropertyIfChanged(obMainBoxBorder, "Visible", true, elData.optionsCache, "obMainBoxBorder_visible" .. key_suffix)
        self:_SetPropertyIfChanged(obCurrentText, "Visible", true, elData.optionsCache, "obCurrentText_visible" .. key_suffix)
        self:_SetPropertyIfChanged(obArrow, "Visible", true, elData.optionsCache, "obArrow_visible" .. key_suffix)
    else
        obMainBox = CrtOB("Square")
        obMainBoxBorder = CrtOB("Square")
        obCurrentText = CrtOB("Text")
        obArrow = CrtOB("Line") 
        elData = {
            id = uniqueElementId,
            obMainBox = obMainBox, obMainBoxBorder = obMainBoxBorder,
            obCurrentText = obCurrentText, obArrow = obArrow,
            type = "dropdown",
            items = items,
            selectedItem = defaultSelectedItem,
            isOpen = false,
            onItemSelected = onItemSelectedCallback,
            itemHeight = itemHeight,
            colors = colors, 
            itemOBs = {}, 
            currentHoveredItemIndex = -1,
            optionsCache = {} 
        }
        window.elements[window.currentElementIndex] = elData
        self:_SetPropertyIfChanged(obMainBox, "Visible", true, elData.optionsCache, "obMainBox_visible" .. key_suffix)
        self:_SetPropertyIfChanged(obMainBoxBorder, "Visible", true, elData.optionsCache, "obMainBoxBorder_visible" .. key_suffix)
        self:_SetPropertyIfChanged(obCurrentText, "Visible", true, elData.optionsCache, "obCurrentText_visible" .. key_suffix)
        self:_SetPropertyIfChanged(obArrow, "Visible", true, elData.optionsCache, "obArrow_visible" .. key_suffix)
    end
    
    elData.originalRelX = actualRelX
    elData.originalRelY = actualRelY
    elData.updatedThisFrame = true
    elData.optionsCache = elData.optionsCache or {} 

    local mainBoxPos = {mainAreaPos.x + actualRelX, mainAreaPos.y + actualRelY}
    self:_SetPropertyIfChanged(obMainBox, "Position", mainBoxPos, elData.optionsCache, "obMainBox_pos_val" .. key_suffix)
    self:_SetPropertyIfChanged(obMainBox, "Size", {width, height}, elData.optionsCache, "obMainBox_size_val" .. key_suffix)
    self:_SetPropertyIfChanged(obMainBox, "Color", bgColor, elData.optionsCache, "obMainBox_color_val" .. key_suffix)
    self:_SetPropertyIfChanged(obMainBox, "Filled", true, elData.optionsCache, "obMainBox_filled_val" .. key_suffix)

    self:_SetPropertyIfChanged(obMainBoxBorder, "Position", mainBoxPos, elData.optionsCache, "obMainBoxBorder_pos_val" .. key_suffix)
    self:_SetPropertyIfChanged(obMainBoxBorder, "Size", {width, height}, elData.optionsCache, "obMainBoxBorder_size_val" .. key_suffix)
    self:_SetPropertyIfChanged(obMainBoxBorder, "Filled", false, elData.optionsCache, "obMainBoxBorder_filled_val" .. key_suffix)
    self:_SetPropertyIfChanged(obMainBoxBorder, "Thickness", 1, elData.optionsCache, "obMainBoxBorder_thickness_val" .. key_suffix)

    local displayText = elData.selectedItem or labelText or "Select..."
    local currentTextPos = {mainAreaPos.x + actualRelX + 5, mainAreaPos.y + actualRelY + (height - textSize) / 2}
    self:_SetPropertyIfChanged(obCurrentText, "Text", displayText, elData.optionsCache, "obCurrentText_text_val" .. key_suffix)
    self:_SetPropertyIfChanged(obCurrentText, "Position", currentTextPos, elData.optionsCache, "obCurrentText_pos_val" .. key_suffix)
    self:_SetPropertyIfChanged(obCurrentText, "Size", textSize, elData.optionsCache, "obCurrentText_size_val" .. key_suffix)
    self:_SetPropertyIfChanged(obCurrentText, "Color", textColor, elData.optionsCache, "obCurrentText_color_val" .. key_suffix)

    local arrowX = mainAreaPos.x + actualRelX + width - arrowSize - 5
    local arrowY = mainAreaPos.y + actualRelY + (height - arrowSize) / 2
    local arrowFrom, arrowTo
    if elData.isOpen then 
        arrowFrom = {arrowX, arrowY + arrowSize}
        arrowTo = {arrowX + arrowSize / 2, arrowY}
    else 
        arrowFrom = {arrowX, arrowY}
        arrowTo = {arrowX + arrowSize / 2, arrowY + arrowSize}
    end
    self:_SetPropertyIfChanged(elData.obArrow, "From", arrowFrom, elData.optionsCache, "obArrow_from_val" .. key_suffix)
    self:_SetPropertyIfChanged(elData.obArrow, "To", arrowTo, elData.optionsCache, "obArrow_to_val" .. key_suffix)
    self:_SetPropertyIfChanged(elData.obArrow, "Color", arrowColor, elData.optionsCache, "obArrow_color_val" .. key_suffix)
    self:_SetPropertyIfChanged(elData.obArrow, "Thickness", 2, elData.optionsCache, "obArrow_thickness_val" .. key_suffix)

    local mouseJustPressed = self.leftCurrentlyPressed and not self.wasLeftPressedLastFrame
    local border_color_key = "obMainBoxBorder_color_val" .. key_suffix

    if not self.uiClickConsumedThisFrame and mouseJustPressed and IsWithinRegion(self.mousePosition, obMainBox) then
        if elData.isOpen then
            elData.isOpen = false
            self.activeDropdownId = nil
        else
            if self.activeDropdownId then
                 local otherWin = self.windows[self.activeDropdownId.windowId]
                 if otherWin and otherWin.elements[self.activeDropdownId.elementIndex] then
                    local otherEl = otherWin.elements[self.activeDropdownId.elementIndex]
                    if otherEl and (otherEl.type == "dropdown" or otherEl.type == "multidropdown") and otherEl.isOpen then
                         otherEl.isOpen = false
                         if otherEl.obMainBoxBorder then
                            local other_key_suffix = (otherEl.type == "multidropdown") and "_mdd" or "_dd"
                            local other_border_color_key = "obMainBoxBorder_color_val" .. other_key_suffix
                            local otherColors = otherEl.colors or {}
                            self:_SetPropertyIfChanged(otherEl.obMainBoxBorder, "Color", otherColors.outline or self.defaultDropdownOutlineColor, otherEl.optionsCache, other_border_color_key)
                         end
                    end
                end
            end
            elData.isOpen = true
            self.activeDropdownId = {windowId = window.id, elementIndex = window.currentElementIndex}
        end
        self.uiClickConsumedThisFrame = true
    end

    local currentBorderColor = elData.isOpen and openOutlineColor or outlineColor
    self:_SetPropertyIfChanged(obMainBoxBorder, "Color", currentBorderColor, elData.optionsCache, border_color_key)

    for i = 1, #elData.itemOBs do
        local itemDisplay = elData.itemOBs[i]
        if itemDisplay then
            if not elData.isOpen then 
                if itemDisplay.bg then self:_SetPropertyIfChanged(itemDisplay.bg, "Visible", false, itemDisplay.cache_bg, "visible_val" .. key_suffix) end
                if itemDisplay.text then self:_SetPropertyIfChanged(itemDisplay.text, "Visible", false, itemDisplay.cache_text, "visible_text_val" .. key_suffix) end
            end
        end
    end

    if elData.isOpen then
        elData.currentHoveredItemIndex = -1 
        local item_relative_Y_start = actualRelY + height
       
        while #elData.itemOBs < #elData.items do
            table.insert(elData.itemOBs, {
                bg = CrtOB("Square"), text = CrtOB("Text"), 
                cache_bg = {}, cache_text = {} 
            })
        end
        
        for i = 1, #elData.items do
            local itemData = elData.items[i]
            local itemDisplay = elData.itemOBs[i]
            local itemBgOb = itemDisplay.bg
            local itemTextOb = itemDisplay.text
            local itemCacheBg = itemDisplay.cache_bg
            local itemCacheText = itemDisplay.cache_text
            
            local currentItemRelativeY = item_relative_Y_start + (i-1) * itemHeight
            local itemBgPos = {mainAreaPos.x + actualRelX, mainAreaPos.y + currentItemRelativeY}
            local itemTextPos = {mainAreaPos.x + actualRelX + 5, mainAreaPos.y + currentItemRelativeY + (itemHeight - textSize) / 2}

            self:_SetPropertyIfChanged(itemBgOb, "Position", itemBgPos, itemCacheBg, "pos_val" .. key_suffix)
            self:_SetPropertyIfChanged(itemBgOb, "Size", {width, itemHeight}, itemCacheBg, "size_val" .. key_suffix)
            self:_SetPropertyIfChanged(itemBgOb, "Filled", true, itemCacheBg, "filled_val" .. key_suffix)
            self:_SetPropertyIfChanged(itemBgOb, "Visible", true, itemCacheBg, "visible_val" .. key_suffix) 

            self:_SetPropertyIfChanged(itemTextOb, "Text", itemData, itemCacheText, "text_val" .. key_suffix)
            self:_SetPropertyIfChanged(itemTextOb, "Position", itemTextPos, itemCacheText, "pos_text_val" .. key_suffix)
            self:_SetPropertyIfChanged(itemTextOb, "Size", textSize, itemCacheText, "size_text_val" .. key_suffix)
            self:_SetPropertyIfChanged(itemTextOb, "Visible", true, itemCacheText, "visible_text_val" .. key_suffix)

            window.contentMaxY = math.max(window.contentMaxY, currentItemRelativeY + itemHeight)

            local itemBgColorToSet = bgColor
            local itemTextColorToSet = textColor

            local isMouseOverItem = IsWithinRegion(self.mousePosition, itemBgOb) 
            if isMouseOverItem then
                elData.currentHoveredItemIndex = i
                itemBgColorToSet = itemHoverBgColor
                if not self.uiClickConsumedThisFrame and mouseJustPressed then
                    elData.selectedItem = itemData
                    if elData.onItemSelected then
                        local cb = elData.onItemSelected
                        local item_at_call = itemData
                        spawn(function() 
                            pcall(cb, item_at_call)
                            wait(0.1) 
                        end)
                    end
                    elData.isOpen = false 
                    self.activeDropdownId = nil
                    
                    self:_SetPropertyIfChanged(obMainBoxBorder, "Color", outlineColor, elData.optionsCache, border_color_key) 
                    self:_SetPropertyIfChanged(obCurrentText, "Text", elData.selectedItem, elData.optionsCache, "obCurrentText_text_val" .. key_suffix)
                    self.uiClickConsumedThisFrame = true 
                end
            else
                if itemData == elData.selectedItem then
                    itemTextColorToSet = selectedItemTextColor
                end
            end
            self:_SetPropertyIfChanged(itemBgOb, "Color", itemBgColorToSet, itemCacheBg, "color_val" .. key_suffix)
            self:_SetPropertyIfChanged(itemTextOb, "Color", itemTextColorToSet, itemCacheText, "color_text_val" .. key_suffix)
        end
        for i = #elData.items + 1, #elData.itemOBs do
            local surplusItemDisplay = elData.itemOBs[i]
            if surplusItemDisplay.bg then self:_SetPropertyIfChanged(surplusItemDisplay.bg, "Visible", false, surplusItemDisplay.cache_bg, "visible_val" .. key_suffix) end
            if surplusItemDisplay.text then self:_SetPropertyIfChanged(surplusItemDisplay.text, "Visible", false, surplusItemDisplay.cache_text, "visible_text_val" .. key_suffix) end
        end
    end

    if isAutoLayout then
        window.nextElementY = actualRelY + height + window.padding
    end
    window.contentMaxY = math.max(window.contentMaxY, actualRelY + height)

    window.currentElementIndex = window.currentElementIndex + 1
    return elData
end

function UIHelper:MultiDropdown(labelText, options)
    if not self.currentWindowId then print("UIHelper Error: MultiDropdown() called outside a BeginWindow/EndWindow block.") return nil end
    local window = self.windows[self.currentWindowId]
    if not window then print("UIHelper Error: Current window not found for MultiDropdown().") return nil end

    local key_suffix = "_mdd" 

    options = options or {}
    local items = options.items or {}
    local defaultSelectedItems = {} 
    if type(options.defaultSelectedItems) == "table" then
        for _, itemStr in pairs(options.defaultSelectedItems) do 
            table.insert(defaultSelectedItems, itemStr)
        end
    end

    local onSelectionChangedCallback = options.onSelectionChanged

    local colors = options.colors or {}
    local bgColor = colors.bg or self.defaultDropdownBgColor
    local outlineColor = colors.outline or self.defaultDropdownOutlineColor
    local openOutlineColor = colors.openOutline or self.defaultDropdownOpenOutlineColor
    local textColor = colors.text or self.defaultDropdownTextColor
    local arrowColor = colors.arrow or self.defaultDropdownArrowColor
    local itemHoverBgColor = colors.itemHoverBg or self.defaultDropdownItemHoverBgColor
    local selectedItemTextColor = colors.selectedItemText or self.defaultDropdownSelectedItemTextColor

    local relX = options.x
    local relY = options.y
    local width = options.width or 150
    local height = options.height or 20
    local itemHeight = options.itemHeight or height
    local textSize = options.textSize or 10
    local arrowSize = math.floor(height * 0.4)

    local mainAreaPos = RetOB(window.mainAreaOB, "Position")
    local actualRelX, actualRelY
    local isAutoLayout = (relX == nil and relY == nil)

    if isAutoLayout then
        actualRelX = window.currentLayoutX
        actualRelY = window.nextElementY
    else
        actualRelX = relX or window.currentLayoutX
        actualRelY = relY or window.nextElementY
    end

    local elData, obMainBox, obMainBoxBorder, obCurrentText, obArrow
    local itemOBs = {} 
    local uniqueElementId = window.id .. "_el_multi_" .. window.currentElementIndex

    if window.currentElementIndex <= #window.elements and window.elements[window.currentElementIndex].type == "multidropdown" then
        elData = window.elements[window.currentElementIndex]
        obMainBox = elData.obMainBox
        obMainBoxBorder = elData.obMainBoxBorder
        obCurrentText = elData.obCurrentText
        obArrow = elData.obArrow
        itemOBs = elData.itemOBs or {}
        elData.optionsCache = elData.optionsCache or {} 

        self:_SetPropertyIfChanged(obMainBox, "Visible", true, elData.optionsCache, "obMainBox_visible" .. key_suffix)
        self:_SetPropertyIfChanged(obMainBoxBorder, "Visible", true, elData.optionsCache, "obMainBoxBorder_visible" .. key_suffix)
        self:_SetPropertyIfChanged(obCurrentText, "Visible", true, elData.optionsCache, "obCurrentText_visible" .. key_suffix)
        self:_SetPropertyIfChanged(obArrow, "Visible", true, elData.optionsCache, "obArrow_visible" .. key_suffix)
    else
        obMainBox = CrtOB("Square")
        obMainBoxBorder = CrtOB("Square")
        obCurrentText = CrtOB("Text")
        obArrow = CrtOB("Line")
        elData = {
            id = uniqueElementId,
            obMainBox = obMainBox, obMainBoxBorder = obMainBoxBorder,
            obCurrentText = obCurrentText, obArrow = obArrow,
            type = "multidropdown",
            items = items,
            selectedItems = defaultSelectedItems, 
            isOpen = false,
            onSelectionChanged = onSelectionChangedCallback,
            itemHeight = itemHeight,
            colors = colors,
            itemOBs = {},
            currentHoveredItemIndex = -1,
            optionsCache = {} 
        }
        window.elements[window.currentElementIndex] = elData
        self:_SetPropertyIfChanged(obMainBox, "Visible", true, elData.optionsCache, "obMainBox_visible" .. key_suffix)
        self:_SetPropertyIfChanged(obMainBoxBorder, "Visible", true, elData.optionsCache, "obMainBoxBorder_visible" .. key_suffix)
        self:_SetPropertyIfChanged(obCurrentText, "Visible", true, elData.optionsCache, "obCurrentText_visible" .. key_suffix)
        self:_SetPropertyIfChanged(obArrow, "Visible", true, elData.optionsCache, "obArrow_visible" .. key_suffix)
    end

    elData.originalRelX = actualRelX
    elData.originalRelY = actualRelY
    elData.updatedThisFrame = true
    elData.optionsCache = elData.optionsCache or {} 

    local mainBoxPos = {mainAreaPos.x + actualRelX, mainAreaPos.y + actualRelY}
    self:_SetPropertyIfChanged(obMainBox, "Position", mainBoxPos, elData.optionsCache, "obMainBox_pos_val" .. key_suffix)
    self:_SetPropertyIfChanged(obMainBox, "Size", {width, height}, elData.optionsCache, "obMainBox_size_val" .. key_suffix)
    self:_SetPropertyIfChanged(obMainBox, "Color", bgColor, elData.optionsCache, "obMainBox_color_val" .. key_suffix)
    self:_SetPropertyIfChanged(obMainBox, "Filled", true, elData.optionsCache, "obMainBox_filled_val" .. key_suffix)

    self:_SetPropertyIfChanged(obMainBoxBorder, "Position", mainBoxPos, elData.optionsCache, "obMainBoxBorder_pos_val" .. key_suffix)
    self:_SetPropertyIfChanged(obMainBoxBorder, "Size", {width, height}, elData.optionsCache, "obMainBoxBorder_size_val" .. key_suffix)
    self:_SetPropertyIfChanged(obMainBoxBorder, "Filled", false, elData.optionsCache, "obMainBoxBorder_filled_val" .. key_suffix)
    self:_SetPropertyIfChanged(obMainBoxBorder, "Thickness", 1, elData.optionsCache, "obMainBoxBorder_thickness_val" .. key_suffix)

    local currentDisplayText
    if #elData.selectedItems == 0 then
        currentDisplayText = labelText or "Select items..."
    else
        currentDisplayText = table.concat(elData.selectedItems, ", ")
    end
    local currentTextPos = {mainAreaPos.x + actualRelX + 5, mainAreaPos.y + actualRelY + (height - textSize) / 2}
    self:_SetPropertyIfChanged(obCurrentText, "Text", currentDisplayText, elData.optionsCache, "obCurrentText_text_val" .. key_suffix)
    self:_SetPropertyIfChanged(obCurrentText, "Position", currentTextPos, elData.optionsCache, "obCurrentText_pos_val" .. key_suffix)
    self:_SetPropertyIfChanged(obCurrentText, "Size", textSize, elData.optionsCache, "obCurrentText_size_val" .. key_suffix)
    self:_SetPropertyIfChanged(obCurrentText, "Color", textColor, elData.optionsCache, "obCurrentText_color_val" .. key_suffix)

    local arrowX = mainAreaPos.x + actualRelX + width - arrowSize - 5
    local arrowY = mainAreaPos.y + actualRelY + (height - arrowSize) / 2
    local arrowFrom, arrowTo
    if elData.isOpen then
        arrowFrom = {arrowX, arrowY + arrowSize}
        arrowTo = {arrowX + arrowSize / 2, arrowY}
    else
        arrowFrom = {arrowX, arrowY}
        arrowTo = {arrowX + arrowSize / 2, arrowY + arrowSize}
    end
    self:_SetPropertyIfChanged(elData.obArrow, "From", arrowFrom, elData.optionsCache, "obArrow_from_val" .. key_suffix)
    self:_SetPropertyIfChanged(elData.obArrow, "To", arrowTo, elData.optionsCache, "obArrow_to_val" .. key_suffix)
    self:_SetPropertyIfChanged(elData.obArrow, "Color", arrowColor, elData.optionsCache, "obArrow_color_val" .. key_suffix)
    self:_SetPropertyIfChanged(elData.obArrow, "Thickness", 2, elData.optionsCache, "obArrow_thickness_val" .. key_suffix)

    local mouseJustPressed = self.leftCurrentlyPressed and not self.wasLeftPressedLastFrame
    local border_color_key = "obMainBoxBorder_color_val" .. key_suffix

    if not self.uiClickConsumedThisFrame and mouseJustPressed and IsWithinRegion(self.mousePosition, obMainBox) then 
        if elData.isOpen then
            elData.isOpen = false
            self.activeDropdownId = nil
        else
            if self.activeDropdownId then
                 local otherWin = self.windows[self.activeDropdownId.windowId]
                 if otherWin and otherWin.elements[self.activeDropdownId.elementIndex] then
                    local otherEl = otherWin.elements[self.activeDropdownId.elementIndex]
                    if otherEl and (otherEl.type == "dropdown" or otherEl.type == "multidropdown") and otherEl.isOpen then
                        otherEl.isOpen = false
                        if otherEl.obMainBoxBorder then 
                            local other_key_suffix = (otherEl.type == "multidropdown") and "_mdd" or "_dd"
                            local other_border_color_key = "obMainBoxBorder_color_val" .. other_key_suffix
                            local otherColors = otherEl.colors or {}
                            self:_SetPropertyIfChanged(otherEl.obMainBoxBorder, "Color", otherColors.outline or self.defaultDropdownOutlineColor, otherEl.optionsCache, other_border_color_key)
                        end
                    end
                end
            end
            elData.isOpen = true
            self.activeDropdownId = {windowId = window.id, elementIndex = window.currentElementIndex}
        end
        self.uiClickConsumedThisFrame = true 
    end
    local currentBorderColor = elData.isOpen and openOutlineColor or outlineColor
    self:_SetPropertyIfChanged(obMainBoxBorder, "Color", currentBorderColor, elData.optionsCache, border_color_key)

    for i = 1, #elData.itemOBs do
        local itemDisplay = elData.itemOBs[i]
        if itemDisplay then
            if not elData.isOpen then
                if itemDisplay.bg then self:_SetPropertyIfChanged(itemDisplay.bg, "Visible", false, itemDisplay.cache_bg, "visible_val" .. key_suffix) end
                if itemDisplay.text then self:_SetPropertyIfChanged(itemDisplay.text, "Visible", false, itemDisplay.cache_text, "visible_text_val" .. key_suffix) end
            end
        end
    end

    if elData.isOpen then
        elData.currentHoveredItemIndex = -1
        local item_relative_Y_start = actualRelY + height 

        while #elData.itemOBs < #elData.items do
            table.insert(elData.itemOBs, {
                bg = CrtOB("Square"), text = CrtOB("Text"),
                cache_bg = {}, cache_text = {} 
            })
        end

        for i = 1, #elData.items do
            local itemData = elData.items[i]
            local itemDisplay = elData.itemOBs[i]
            local itemBgOb = itemDisplay.bg
            local itemTextOb = itemDisplay.text
            local itemCacheBg = itemDisplay.cache_bg
            local itemCacheText = itemDisplay.cache_text
            
            local currentItemRelativeY = item_relative_Y_start + (i-1) * itemHeight
            local itemBgPos = {mainAreaPos.x + actualRelX, mainAreaPos.y + currentItemRelativeY}
            local itemTextPos = {mainAreaPos.x + actualRelX + 5, mainAreaPos.y + currentItemRelativeY + (itemHeight - textSize) / 2}

            self:_SetPropertyIfChanged(itemBgOb, "Position", itemBgPos, itemCacheBg, "pos_val" .. key_suffix)
            self:_SetPropertyIfChanged(itemBgOb, "Size", {width, itemHeight}, itemCacheBg, "size_val" .. key_suffix)
            self:_SetPropertyIfChanged(itemBgOb, "Filled", true, itemCacheBg, "filled_val" .. key_suffix)
            self:_SetPropertyIfChanged(itemBgOb, "Visible", true, itemCacheBg, "visible_val" .. key_suffix)

            self:_SetPropertyIfChanged(itemTextOb, "Text", itemData, itemCacheText, "text_val" .. key_suffix)
            self:_SetPropertyIfChanged(itemTextOb, "Position", itemTextPos, itemCacheText, "pos_text_val" .. key_suffix)
            self:_SetPropertyIfChanged(itemTextOb, "Size", textSize, itemCacheText, "size_text_val" .. key_suffix)
            self:_SetPropertyIfChanged(itemTextOb, "Visible", true, itemCacheText, "visible_text_val" .. key_suffix)

            window.contentMaxY = math.max(window.contentMaxY, currentItemRelativeY + itemHeight)

            local isItemSelected = false
            for _, selected in ipairs(elData.selectedItems) do
                if selected == itemData then
                    isItemSelected = true
                    break
                end
            end

            local itemBgColorToSet = bgColor
            local itemTextColorToSet = textColor

            local isMouseOverItem = IsWithinRegion(self.mousePosition, itemBgOb)
            if isMouseOverItem then
                elData.currentHoveredItemIndex = i
                itemBgColorToSet = itemHoverBgColor
                
                if not self.uiClickConsumedThisFrame and mouseJustPressed then 
                    local previouslySelected = isItemSelected
                    if previouslySelected then 
                        for k, selectedValue in ipairs(elData.selectedItems) do
                            if selectedValue == itemData then
                                table.remove(elData.selectedItems, k)
                                break
                            end
                        end
                    else 
                        table.insert(elData.selectedItems, itemData)
                    end
                    isItemSelected = not previouslySelected 

                    if elData.onSelectionChanged then
                        local cb = elData.onSelectionChanged
                        
                        
                        local currentSelectionCopy = {}
                        for _, selItem in ipairs(elData.selectedItems) do table.insert(currentSelectionCopy, selItem) end
                        
                        spawn(function() 
                            pcall(cb, currentSelectionCopy)
                            wait(0.1) 
                        end)
                    end
                    
                    local newDisplayText
                    if #elData.selectedItems == 0 then
                        newDisplayText = labelText or "Select items..."
                    else
                        newDisplayText = table.concat(elData.selectedItems, ", ")
                    end
                    self:_SetPropertyIfChanged(obCurrentText, "Text", newDisplayText, elData.optionsCache, "obCurrentText_text_val" .. key_suffix)
                    self.uiClickConsumedThisFrame = true 
                end
            end
            
            if isItemSelected then
                itemTextColorToSet = selectedItemTextColor
            end
            if isMouseOverItem then itemBgColorToSet = itemHoverBgColor end

            self:_SetPropertyIfChanged(itemBgOb, "Color", itemBgColorToSet, itemCacheBg, "color_val" .. key_suffix)
            self:_SetPropertyIfChanged(itemTextOb, "Color", itemTextColorToSet, itemCacheText, "color_text_val" .. key_suffix)
        end
        
        for i = #elData.items + 1, #elData.itemOBs do
            local surplusItemDisplay = elData.itemOBs[i]
            if surplusItemDisplay.bg then self:_SetPropertyIfChanged(surplusItemDisplay.bg, "Visible", false, surplusItemDisplay.cache_bg, "visible_val" .. key_suffix) end
            if surplusItemDisplay.text then self:_SetPropertyIfChanged(surplusItemDisplay.text, "Visible", false, surplusItemDisplay.cache_text, "visible_text_val" .. key_suffix) end
        end
    end

    if isAutoLayout then
        window.nextElementY = actualRelY + height + window.padding
    end
    window.contentMaxY = math.max(window.contentMaxY, actualRelY + height)

    window.currentElementIndex = window.currentElementIndex + 1
    return elData
end

function UIHelper:Button(textString, options)
    if not self.currentWindowId then print("UIHelper Error: Button() called outside a BeginWindow/EndWindow block.") return nil end
    local window = self.windows[self.currentWindowId]
    if not window then print("UIHelper Error: Current window not found for Button().") return nil end

    options = options or {}
    local relX = options.x
    local relY = options.y
    local width = options.width or 100
    local height = options.height or 20
    local onClickCallback = options.onClick

    local colors = options.colors or {}
    local bgColor = colors.bg or self.defaultButtonBgColor
    local hoverBgColor = colors.hoverBg or self.defaultButtonHoverBgColor
    local textColor = colors.text or self.defaultButtonTextColor
    local textSize = options.textSize or 10

    local mainAreaPos = RetOB(window.mainAreaOB, "Position")
    local actualRelX, actualRelY
    local isAutoLayout = (relX == nil and relY == nil)

    if isAutoLayout then
        actualRelX = window.currentLayoutX
        actualRelY = window.nextElementY
    else
        actualRelX = relX or window.currentLayoutX
        actualRelY = relY or window.nextElementY
    end

    local elData, obButton, obText

    if window.currentElementIndex <= #window.elements and window.elements[window.currentElementIndex].type == "button" then
        elData = window.elements[window.currentElementIndex]
        obButton = elData.obButton
        obText = elData.obText
        elData.optionsCache = elData.optionsCache or {}
        self:_SetPropertyIfChanged(obButton, "Visible", true, elData.optionsCache, "obButton_visible")
        self:_SetPropertyIfChanged(obText, "Visible", true, elData.optionsCache, "obText_visible_button")
    else
        obButton = CrtOB("Square")
        obText = CrtOB("Text")
        elData = {
            obButton = obButton, obText = obText,
            type = "button",
            onClick = onClickCallback,
            optionsCache = {}
        }
        window.elements[window.currentElementIndex] = elData
        self:_SetPropertyIfChanged(obButton, "Visible", true, elData.optionsCache, "obButton_visible")
        self:_SetPropertyIfChanged(obText, "Visible", true, elData.optionsCache, "obText_visible_button")
    end

    if elData.onClick ~= onClickCallback then
        elData.onClick = onClickCallback
    end

    elData.originalRelX = actualRelX
    elData.originalRelY = actualRelY
    elData.updatedThisFrame = true
    elData.optionsCache = elData.optionsCache or {}

    elData.optionsCache.textString_arg_button = textString
    elData.optionsCache.relX_arg_button = actualRelX; elData.optionsCache.relY_arg_button = actualRelY;
    elData.optionsCache.width_arg_button = width; elData.optionsCache.height_arg_button = height;
    elData.optionsCache.textSize_arg_button = textSize;
    elData.optionsCache.bgColor_arg_button = bgColor; elData.optionsCache.hoverBgColor_arg_button = hoverBgColor;
    elData.optionsCache.textColor_arg_button = textColor;

    local buttonPos = {mainAreaPos.x + actualRelX, mainAreaPos.y + actualRelY}
    self:_SetPropertyIfChanged(obButton, "Position", buttonPos, elData.optionsCache, "obButton_pos_val")
    self:_SetPropertyIfChanged(obButton, "Size", {width, height}, elData.optionsCache, "obButton_size_val")
    self:_SetPropertyIfChanged(obButton, "Filled", true, elData.optionsCache, "obButton_filled_val")

    self:_SetPropertyIfChanged(obText, "Text", textString or "", elData.optionsCache, "obText_text_val_button")
    self:_SetPropertyIfChanged(obText, "Size", textSize, elData.optionsCache, "obText_size_val_button")
    self:_SetPropertyIfChanged(obText, "Color", textColor, elData.optionsCache, "obText_color_val_button")

    local textBoundsX = RetOB(obText, "TextBounds").x or 0
    local textPos = {mainAreaPos.x + actualRelX + (width - textBoundsX)/2 , mainAreaPos.y + actualRelY + (height - textSize)/2}
    self:_SetPropertyIfChanged(obText, "Position", textPos, elData.optionsCache, "obText_pos_val_button")

    local mouseJustPressed = self.leftCurrentlyPressed and not self.wasLeftPressedLastFrame
    local currentBgColor = bgColor

    if IsWithinRegion(self.mousePosition, obButton) then
        currentBgColor = hoverBgColor
        if not self.uiClickConsumedThisFrame and mouseJustPressed then
            if elData.onClick then
                local cb = elData.onClick
                spawn(function()
                    pcall(cb)
                    wait(0.1)
                end)
            end
            self.uiClickConsumedThisFrame = true
        end
    end
    self:_SetPropertyIfChanged(obButton, "Color", currentBgColor, elData.optionsCache, "obButton_color_val")

    if isAutoLayout then
        window.nextElementY = actualRelY + height + window.padding
    end
    window.contentMaxY = math.max(window.contentMaxY, actualRelY + height)

    window.currentElementIndex = window.currentElementIndex + 1
    return elData
end

function UIHelper:SetWindowVisible(id, visible)
    local window = self.windows[id]
    if not window then return end

    if window.titleBarOB then self:_SetPropertyIfChanged(window.titleBarOB, "Visible", visible, window.cache, "titleBarVisible") end
    if window.titleTextOB then self:_SetPropertyIfChanged(window.titleTextOB, "Visible", visible, window.cache, "titleTextVisible") end
    if window.mainAreaOB then self:_SetPropertyIfChanged(window.mainAreaOB, "Visible", visible, window.cache, "mainAreaVisible") end

    for i, elData in ipairs(window.elements) do -- Iterate here to get index i
        if elData and elData.optionsCache then 
            local elCache = elData.optionsCache
            if elData.type == "text" then
                if elData.ob then self:_SetPropertyIfChanged(elData.ob, "Visible", visible, elCache, "visible") end
            elseif elData.type == "square" then
                if elData.ob then self:_SetPropertyIfChanged(elData.ob, "Visible", visible, elCache, "square_visible") end
            elseif elData.type == "toggle" then
                if elData.obOuter then self:_SetPropertyIfChanged(elData.obOuter, "Visible", visible, elCache, "obOuter_visible") end
                if elData.obInner then self:_SetPropertyIfChanged(elData.obInner, "Visible", visible, elCache, "obInner_visible_val") end 
                if elData.obText then self:_SetPropertyIfChanged(elData.obText, "Visible", visible, elCache, "obText_visible") end
            elseif elData.type == "dropdown" or elData.type == "multidropdown" then
                local key_suffix = (elData.type == "multidropdown") and "_mdd" or "_dd"
                local border_color_key = "obMainBoxBorder_color_val" .. key_suffix
                
                if elData.obMainBox then self:_SetPropertyIfChanged(elData.obMainBox, "Visible", visible, elCache, "obMainBox_visible" .. key_suffix) end
                if elData.obMainBoxBorder then self:_SetPropertyIfChanged(elData.obMainBoxBorder, "Visible", visible, elCache, "obMainBoxBorder_visible" .. key_suffix) end
                if elData.obCurrentText then self:_SetPropertyIfChanged(elData.obCurrentText, "Visible", visible, elCache, "obCurrentText_visible" .. key_suffix) end
                if elData.obArrow then self:_SetPropertyIfChanged(elData.obArrow, "Visible", visible, elCache, "obArrow_visible" .. key_suffix) end
                
                local itemsShouldBeVisible = visible and elData.isOpen 
                if elData.itemOBs then
                    for _, itemDisplay in ipairs(elData.itemOBs) do
                        if itemDisplay.bg then self:_SetPropertyIfChanged(itemDisplay.bg, "Visible", itemsShouldBeVisible, itemDisplay.cache_bg, "visible_val" .. key_suffix) end
                        if itemDisplay.text then self:_SetPropertyIfChanged(itemDisplay.text, "Visible", itemsShouldBeVisible, itemDisplay.cache_text, "visible_text_val" .. key_suffix) end
                    end
                end

                if not visible then
                    elData.isOpen = false 
                    if elData.obMainBoxBorder then
                         local elColors = elData.colors or {}
                         self:_SetPropertyIfChanged(elData.obMainBoxBorder, "Color", elColors.outline or self.defaultDropdownOutlineColor, elCache, border_color_key)
                    end
                else 
                    if elData.obMainBoxBorder then
                        local elColors = elData.colors or {}
                        local currentOutlineColor = elData.isOpen and 
                                                  (elColors.openOutline or self.defaultDropdownOpenOutlineColor) or 
                                                  (elColors.outline or self.defaultDropdownOutlineColor)
                        self:_SetPropertyIfChanged(elData.obMainBoxBorder, "Color", currentOutlineColor, elCache, border_color_key)
                    end
                end
            elseif elData.type == "button" then
                if elData.obButton then self:_SetPropertyIfChanged(elData.obButton, "Visible", visible, elCache, "obButton_visible") end
                if elData.obText then self:_SetPropertyIfChanged(elData.obText, "Visible", visible, elCache, "obText_visible_button") end
            elseif elData.type == "input" then
                local isActuallyVisible = visible
                if elData.obBox then self:_SetPropertyIfChanged(elData.obBox, "Visible", isActuallyVisible, elCache, "obBox_visible_input") end
                if elData.obText then self:_SetPropertyIfChanged(elData.obText, "Visible", isActuallyVisible, elCache, "obText_visible_input") end
                
                local isFocused = self.activeInputId and self.activeInputId.windowId == id and self.activeInputId.elementIndex == i
                local caretShouldBeVisible = isActuallyVisible and isFocused and self.caretVisible
                if elData.obCaret then self:_SetPropertyIfChanged(elData.obCaret, "Visible", caretShouldBeVisible, elCache, "obCaret_visible_input") end
                
                if not isActuallyVisible and isFocused then
                    self.activeInputId = nil
                end
            end
        end
    end

    if not visible then
        if self.activeDropdownId and self.activeDropdownId.windowId == id then
            self.activeDropdownId = nil
        end
    end
end

function UIHelper:Run(userRenderFunction)
    if not self.mouseService then 
        print("UIHelper Error: MouseService not available. Initialize UIHelper first.")
        return
    end
    if type(userRenderFunction) ~= "function" then
        print("UIHelper Error: UIHelper:Run requires a function argument that defines the UI.")
        return
    end

    spawn(function() 
        while true do   
            local mousePos = getmouselocation(self.mouseService) 
            local leftPressed = isleftpressed() 
            self:UpdateInputState(mousePos.x, mousePos.y, leftPressed)         
            self:BeginFrame()
            local success, err = pcall(userRenderFunction)
            if not success then
                print("UIHelper Error in userRenderFunction:", err)                
            end        
            self:EndFrame()
            wait(0.01) 
            
        end
    end)
end

function UIHelper:Input(options)
    if not self.currentWindowId then print("UIHelper Error: Input() called outside a BeginWindow/EndWindow block.") return nil end
    local window = self.windows[self.currentWindowId]
    if not window then print("UIHelper Error: Current window not found for Input().") return nil end

    options = options or {}
    local relX = options.x
    local relY = options.y
    local width = options.width or 150
    local height = options.height or 20
    local defaultText = options.defaultText or ""
    local placeholderText = options.placeholderText or ""
    local onChangedCallback = options.onChanged
    local onEnterCallback = options.onEnter

    local colors = options.colors or {}
    local bgColor = colors.bg or self.defaultInputBgColor
    local textColor = colors.text or self.defaultInputTextColor
    local placeholderColor = colors.placeholder or self.defaultInputPlaceholderColor
    local borderColor = colors.border or self.defaultInputBorderColor -- Used if not focused
    local focusedBgColor = colors.focusedBg or self.defaultInputFocusedBorderColor -- Use as BG when focused for clear indication
    local caretColor = colors.caret or self.defaultInputCaretColor
    local textSize = options.textSize or 10

    local mainAreaPos = RetOB(window.mainAreaOB, "Position")
    local actualRelX, actualRelY
    local isAutoLayout = (relX == nil and relY == nil)

    if isAutoLayout then
        actualRelX = window.currentLayoutX
        actualRelY = window.nextElementY
    else
        actualRelX = relX or window.currentLayoutX
        actualRelY = relY or window.nextElementY
    end

    local elData, obBox, obText, obCaret
    local elementUniqueId = window.id .. "_input_" .. window.currentElementIndex

    if window.currentElementIndex <= #window.elements and window.elements[window.currentElementIndex].type == "input" then
        elData = window.elements[window.currentElementIndex]
        obBox = elData.obBox
        obText = elData.obText
        obCaret = elData.obCaret
        elData.optionsCache = elData.optionsCache or {}
        self:_SetPropertyIfChanged(obBox, "Visible", true, elData.optionsCache, "obBox_visible_input")
        self:_SetPropertyIfChanged(obText, "Visible", true, elData.optionsCache, "obText_visible_input")
    else
        obBox = CrtOB("Square")
        obText = CrtOB("Text")
        obCaret = CrtOB("Line")
        elData = {
            id = elementUniqueId,
            obBox = obBox, obText = obText, obCaret = obCaret,
            type = "input",
            currentText = defaultText,
            placeholderText = placeholderText,
            onChanged = onChangedCallback,
            onEnter = onEnterCallback,
            optionsCache = {}
        }
        window.elements[window.currentElementIndex] = elData
        self:_SetPropertyIfChanged(obBox, "Visible", true, elData.optionsCache, "obBox_visible_input")
        self:_SetPropertyIfChanged(obText, "Visible", true, elData.optionsCache, "obText_visible_input")
    end

    elData.onChanged = onChangedCallback
    elData.onEnter = onEnterCallback
    elData.placeholderText = placeholderText
    elData.updatedThisFrame = true

    local boxPos = {mainAreaPos.x + actualRelX, mainAreaPos.y + actualRelY}
    local isFocused = self.activeInputId and self.activeInputId.windowId == window.id and self.activeInputId.elementIndex == window.currentElementIndex
    
    local currentBgColorToSet = isFocused and focusedBgColor or bgColor
    
    self:_SetPropertyIfChanged(obBox, "Position", boxPos, elData.optionsCache, "obBox_pos_input")
    self:_SetPropertyIfChanged(obBox, "Size", {width, height}, elData.optionsCache, "obBox_size_input")
    self:_SetPropertyIfChanged(obBox, "Color", currentBgColorToSet, elData.optionsCache, "obBox_color_input")
    self:_SetPropertyIfChanged(obBox, "Filled", true, elData.optionsCache, "obBox_filled_input")
    -- If your engine supports BorderColor and Thickness for Square, you would set them here:
    -- self:_SetPropertyIfChanged(obBox, "BorderColor", isFocused and focusedBorderColor or borderColor, elData.optionsCache, "input_border_color")
    -- self:_SetPropertyIfChanged(obBox, "Thickness", 1, elData.optionsCache, "input_border_thickness")

    local textToDisplay = elData.currentText
    local currentTextColorToDisplay = textColor
    if #elData.currentText == 0 and #elData.placeholderText > 0 then
        textToDisplay = elData.placeholderText
        currentTextColorToDisplay = placeholderColor
    end

    local textPaddingX = 5
    local textPosY = mainAreaPos.y + actualRelY + (height - textSize) / 2
    local textPosX = mainAreaPos.x + actualRelX + textPaddingX

    self:_SetPropertyIfChanged(obText, "Text", textToDisplay, elData.optionsCache, "obText_val_input")
    self:_SetPropertyIfChanged(obText, "Position", {textPosX, textPosY}, elData.optionsCache, "obText_pos_input")
    self:_SetPropertyIfChanged(obText, "Size", textSize, elData.optionsCache, "obText_size_input")
    self:_SetPropertyIfChanged(obText, "Color", currentTextColorToDisplay, elData.optionsCache, "obText_color_input")
    -- self:_SetPropertyIfChanged(obText, "ClipWidget", obBox, elData.optionsCache, "obText_clip_input")
    self:_SetPropertyIfChanged(obText, "Visible", true, elData.optionsCache, "obText_visible_input")
    if isFocused and self.caretVisible then
        local textWidth = RetOB(obText, "TextBounds").x or 0
        if #elData.currentText == 0 and #elData.placeholderText > 0 and textToDisplay == elData.placeholderText then
             textWidth = 0 
        end        
        local caretPosX = mainAreaPos.x + actualRelX + textPaddingX + textWidth
        -- Ensure caret is not drawn outside the box boundaries (simple clip)
        caretPosX = math.min(caretPosX, boxPos[1] + width - textPaddingX)
        caretPosX = math.max(caretPosX, boxPos[1] + textPaddingX)

        local caretTopY = mainAreaPos.y + actualRelY + 2
        local caretBottomY = mainAreaPos.y + actualRelY + height - 2
        self:_SetPropertyIfChanged(obCaret, "From", {caretPosX, caretTopY}, elData.optionsCache, "obCaret_from_input")
        self:_SetPropertyIfChanged(obCaret, "To", {caretPosX, caretBottomY}, elData.optionsCache, "obCaret_to_input")
        self:_SetPropertyIfChanged(obCaret, "Color", caretColor, elData.optionsCache, "obCaret_color_input")
        self:_SetPropertyIfChanged(obCaret, "Thickness", 1, elData.optionsCache, "obCaret_thickness_input")
        self:_SetPropertyIfChanged(obCaret, "Visible", true, elData.optionsCache, "obCaret_visible_input")
    else
        self:_SetPropertyIfChanged(obCaret, "Visible", false, elData.optionsCache, "obCaret_visible_input")
    end

    local mouseJustPressed = self.leftCurrentlyPressed and not self.wasLeftPressedLastFrame
    if not self.uiClickConsumedThisFrame and mouseJustPressed and IsWithinRegion(self.mousePosition, obBox) then
        if not isFocused then
            if self.activeInputId then 
                 local prevWin = self.windows[self.activeInputId.windowId]
                 if prevWin and prevWin.elements[self.activeInputId.elementIndex] and prevWin.elements[self.activeInputId.elementIndex].type == "input" then
                    -- Trigger visual update for old input to lose focus (color change)
                    local oldEl = prevWin.elements[self.activeInputId.elementIndex]
                    self:_SetPropertyIfChanged(oldEl.obBox, "Color", oldEl.colors.bg or self.defaultInputBgColor, oldEl.optionsCache, "obBox_color_input")
                 end
            end
            self.activeInputId = {windowId = window.id, elementIndex = window.currentElementIndex}
            self.caretBlinkTimer = 0 
            self.caretVisible = true
        end
        self.uiClickConsumedThisFrame = true 
    end

    if isAutoLayout then
        window.nextElementY = actualRelY + height + window.padding
    end
    window.contentMaxY = math.max(window.contentMaxY, actualRelY + height)

    window.currentElementIndex = window.currentElementIndex + 1
    return elData
end

return UIHelper
