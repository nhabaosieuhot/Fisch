--- START OF FILE UIHelper.lua ---

SET_SCHEDULER_TIMEOUT(false)
local UIHelper = {
    windows = {},
    currentWindowId = nil,
    mouseService = nil,
    activeDropdownId = nil,
    uiClickConsumedThisFrame = false,
    
    areAllWindowsVisible = true,
    toggleKey = "Delete", 
    wasToggleKeyPressedLastFrame = false,
    
    mousePosition = {x=0, y=0},
    leftCurrentlyPressed = false,
    wasLeftPressedLastFrame = false,

    activeInputBoxId = nil, 
    inputBoxLastPressedKeys = {},
    inputBoxKeyRepeatDelay = 0.5, 
    inputBoxKeyRepeatRate = 0.05, 
    inputBoxKeyRepeatInfo = { key = nil, char = nil, nextRepeatTime = 0, initialRepeat = true },

    -- Default Colors
    defaultTitleBarColor = {41, 74, 122}, hoverTitleBarColor = {61, 94, 142}, draggingTitleBarColor = {81, 114, 162},
    defaultWindowBgColor = {15, 15, 15}, defaultTextColor = {255, 255, 255},
    -- Toggle Colors
    defaultToggleOutlineColor = {100, 100, 100}, defaultToggleOffColor = {50, 50, 50}, defaultToggleOnColor = {70, 130, 180},  
    -- Button Colors
    defaultButtonBgColor = {80, 80, 80}, defaultButtonTextColor = {230, 230, 230}, hoverButtonBgColor = {100, 100, 100}, pressedButtonBgColor = {60, 60, 60}, defaultButtonOutlineColor = {120, 120, 120},
    -- Dropdown Colors
    defaultDropdownBgColor = {50, 50, 50}, defaultDropdownOutlineColor = {100, 100, 100}, defaultDropdownTextColor = {220, 220, 220}, defaultDropdownArrowColor = {200, 200, 200}, defaultDropdownItemHoverBgColor = {70, 90, 110}, defaultDropdownSelectedItemTextColor = {120, 180, 255}, defaultDropdownOpenOutlineColor = {100, 150, 200}, 
    -- InputBox Colors
    defaultInputBgColor = {30, 30, 30}, defaultInputTextColor = {220, 220, 220}, defaultInputOutlineColor = {100, 100, 100}, focusedInputOutlineColor = {100, 150, 200}, defaultCursorColor = {230, 230, 230},
}

local DEFAULT_PADDING = 5

local KEY_TO_CHAR_LOWER = {
    A="a", B="b", C="c", D="d", E="e", F="f", G="g", H="h", I="i", J="j", K="k", L="l", M="m",
    N="n", O="o", P="p", Q="q", R="r", S="s", T="t", U="u", V="v", W="w", X="x", Y="y", Z="z",
    One="1", Two="2", Three="3", Four="4", Five="5", Six="6", Seven="7", Eight="8", Nine="9", Zero="0",
    NumPad1="1", NumPad2="2", NumPad3="3", NumPad4="4", NumPad5="5", NumPad6="6", NumPad7="7", NumPad8="8", NumPad9="9", NumPad0="0",
    Space=" ", Period=".", Comma=",", Minus="-", Equals="=", Slash="/", Backslash="\\",
    LeftBracket="[", RightBracket="]", Semicolon=";", Quote="'", Backquote="`",
    NumPadDecimal=".", NumPadDivide="/", NumPadMultiply="*", NumPadSubtract="-", NumPadAdd="+",
}
local KEY_TO_CHAR_UPPER = {
    A="A", B="B", C="C", D="D", E="E", F="F", G="G", H="H", I="I", J="J", K="K", L="L", M="M",
    N="N", O="O", P="P", Q="Q", R="R", S="S", T="T", U="U", V="V", W="W", X="X", Y="Y", Z="Z",
    One="!", Two="@", Three="#", Four="$", Five="%", Six="^", Seven="&", Eight="*", Nine="(", Zero=")",
    Period=">", Comma="<", Minus="_", Equals="+", Slash="?", Backslash="|",
    LeftBracket="{", RightBracket="}", Semicolon=":", Quote="\"", Backquote="~",
}
local CONTROL_KEYS = { Backspace=true, Enter=true, NumpadEnter=true, LeftShift=true, RightShift=true, 
                       LeftControl=true, RightControl=true, LeftAlt=true, RightAlt=true }


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
        if type(oldVal) ~= "table" then changed = true
        else
            if #newValue ~= #oldVal then changed = true
            else
                for i = 1, #newValue do
                    if type(newValue[i]) == "table" and type(oldVal[i]) == "table" then
                        if #newValue[i] ~= #oldVal[i] then changed = true; break; end
                        for j=1, #newValue[i] do if newValue[i][j] ~= oldVal[i][j] then changed = true; break; end end
                        if changed then break; end
                    elseif newValue[i] ~= oldVal[i] then changed = true; break; end
                end
            end
        end
    else 
        if oldVal ~= newValue then changed = true; end
    end
    if changed then
        SetOB(ob, propName, newValue)
        if type(newValue) == "table" then
            local copy = {}; for i = 1, #newValue do
                if type(newValue[i]) == "table" then 
                    local subCopy = {}; for j=1, #newValue[i] do subCopy[j] = newValue[i][j]; end
                    copy[i] = subCopy
                else copy[i] = newValue[i]; end
            end
            cache[cacheKey] = copy 
        else cache[cacheKey] = newValue; end
    end
end

function UIHelper:Initialize(options)
    local opts = options or {}
    self.mouseService = opts.mouseServiceInstance or findservice(Game, "MouseService")
    if not self.mouseService then print("UIHelper Error: MouseService instance not found."); return false; end
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

    if self.toggleKey then
        local currentPressedKeys = getpressedkeys() 
        local toggleKeyFound = false
        for _, key in ipairs(currentPressedKeys) do if key == self.toggleKey then toggleKeyFound = true; break; end end

        if toggleKeyFound and not self.wasToggleKeyPressedLastFrame then
            self.areAllWindowsVisible = not self.areAllWindowsVisible
            for windowId, _ in pairs(self.windows) do self:SetWindowVisible(windowId, self.areAllWindowsVisible); end
            if not self.areAllWindowsVisible then
                if self.activeDropdownId then 
                    local activeWin = self.windows[self.activeDropdownId.windowId]
                    if activeWin and activeWin.elements[self.activeDropdownId.elementIndex] then
                        local activeEl = activeWin.elements[self.activeDropdownId.elementIndex]
                        if activeEl and (activeEl.type == "dropdown" or activeEl.type == "multidropdown") and activeEl.obMainBoxBorder and activeEl.optionsCache and activeEl.colors then
                           activeEl.isOpen = false
                           local key_suffix = (activeEl.type == "multidropdown") and "_mdd" or "_dd"
                           self:_SetPropertyIfChanged(activeEl.obMainBoxBorder, "Color", activeEl.colors.outline or self.defaultDropdownOutlineColor, activeEl.optionsCache, "obMainBoxBorder_color_val" .. key_suffix)
                        end
                    end; self.activeDropdownId = nil
                end
                if self.activeInputBoxId then 
                    local activeWinInput = self.windows[self.activeInputBoxId.windowId]
                    if activeWinInput and activeWinInput.elements[self.activeInputBoxId.elementIndex] then
                         local activeElInput = activeWinInput.elements[self.activeInputBoxId.elementIndex]
                         if activeElInput and activeElInput.type == "inputbox" then activeElInput.isFocused = false; end
                    end; self.activeInputBoxId = nil
                end
            end
        end
        self.wasToggleKeyPressedLastFrame = toggleKeyFound
    end

    local mouseJustPressed = self.leftCurrentlyPressed and not self.wasLeftPressedLastFrame
    
    if mouseJustPressed and self.activeDropdownId then
        local activeWin = self.windows[self.activeDropdownId.windowId]
        if activeWin and activeWin.elements[self.activeDropdownId.elementIndex] then
            local activeEl = activeWin.elements[self.activeDropdownId.elementIndex]
            if activeEl and (activeEl.type == "dropdown" or activeEl.type == "multidropdown") and activeEl.obMainBox then
                local mainBoxAbsPos = RetOB(activeEl.obMainBox, "Position"); local mainBoxAbsSize = RetOB(activeEl.obMainBox, "Size")
                local itemsListHeight = (activeEl.items and activeEl.itemHeight) and (#activeEl.items * activeEl.itemHeight) or 0
                local wasClickOnDropdown = false
                if mainBoxAbsPos and mainBoxAbsSize then 
                    if IsWithinRegion(self.mousePosition, activeEl.obMainBox) or 
                       (activeEl.isOpen and self.mousePosition.x >= mainBoxAbsPos.x and self.mousePosition.x <= mainBoxAbsPos.x + mainBoxAbsSize.x and
                        self.mousePosition.y >= mainBoxAbsPos.y + mainBoxAbsSize.y and self.mousePosition.y <= mainBoxAbsPos.y + mainBoxAbsSize.y + itemsListHeight) then
                        wasClickOnDropdown = true
                    end
                end
                if not wasClickOnDropdown then
                    activeEl.isOpen = false
                    if activeEl.optionsCache and activeEl.colors then 
                        local key_suffix = (activeEl.type == "multidropdown") and "_mdd" or "_dd"
                        self:_SetPropertyIfChanged(activeEl.obMainBox, "Color", activeEl.colors.bg or self.defaultDropdownBgColor, activeEl.optionsCache, "obMainBox_color_val" .. key_suffix)
                        self:_SetPropertyIfChanged(activeEl.obMainBoxBorder, "Color", activeEl.colors.outline or self.defaultDropdownOutlineColor, activeEl.optionsCache, "obMainBoxBorder_color_val" .. key_suffix)
                    end
                    self.activeDropdownId = nil; self.uiClickConsumedThisFrame = true 
                end
            else self.activeDropdownId = nil; end
        else self.activeDropdownId = nil; end
    end

    if mouseJustPressed and self.activeInputBoxId and not self.uiClickConsumedThisFrame then
        local activeWinInput = self.windows[self.activeInputBoxId.windowId]
        if activeWinInput and activeWinInput.elements[self.activeInputBoxId.elementIndex] then
            local activeElInput = activeWinInput.elements[self.activeInputBoxId.elementIndex]
            if activeElInput and activeElInput.type == "inputbox" and activeElInput.obInputBg then
                if not IsWithinRegion(self.mousePosition, activeElInput.obInputBg) then
                    activeElInput.isFocused = false; self.activeInputBoxId = nil;
                end
            else self.activeInputBoxId = nil; end
        else self.activeInputBoxId = nil; end
    end

    if self.activeInputBoxId then
        local win = self.windows[self.activeInputBoxId.windowId]
        if win and win.elements[self.activeInputBoxId.elementIndex] then
            local elData = win.elements[self.activeInputBoxId.elementIndex]
            if elData and elData.type == "inputbox" and elData.isFocused then
                local currentPressedKeysRaw = getpressedkeys()
                local currentPressedSet = {}; local isShiftDown = false
                for _, k_raw in ipairs(currentPressedKeysRaw) do currentPressedSet[k_raw] = true; if k_raw == "LeftShift" or k_raw == "RightShift" then isShiftDown = true; end end

                local textChangedThisFrame = false; local currentTime = os.clock()
                local processChar = ""; local processKey = ""

                for keyName, _ in pairs(currentPressedSet) do
                    if not self.inputBoxLastPressedKeys[keyName] and not CONTROL_KEYS[keyName] then 
                        local charMap = isShiftDown and KEY_TO_CHAR_UPPER or KEY_TO_CHAR_LOWER
                        if charMap[keyName] then
                            processChar = charMap[keyName]; processKey = keyName;
                            self.inputBoxKeyRepeatInfo.key = keyName; self.inputBoxKeyRepeatInfo.char = processChar;
                            self.inputBoxKeyRepeatInfo.nextRepeatTime = currentTime + self.inputBoxKeyRepeatDelay;
                            self.inputBoxKeyRepeatInfo.initialRepeat = true; break;
                        end
                    elseif keyName == "Backspace" and not self.inputBoxLastPressedKeys[keyName] then
                        processKey = "Backspace"; self.inputBoxKeyRepeatInfo.key = "Backspace"; self.inputBoxKeyRepeatInfo.char = nil;
                        self.inputBoxKeyRepeatInfo.nextRepeatTime = currentTime + self.inputBoxKeyRepeatDelay; 
                        self.inputBoxKeyRepeatInfo.initialRepeat = true; break;
                    elseif (keyName == "Enter" or keyName == "NumpadEnter") and not self.inputBoxLastPressedKeys[keyName] then
                        processKey = "Enter"; self.inputBoxKeyRepeatInfo.key = nil; break;
                    end
                end
                
                if processKey == "" and self.inputBoxKeyRepeatInfo.key and currentPressedSet[self.inputBoxKeyRepeatInfo.key] and currentTime >= self.inputBoxKeyRepeatInfo.nextRepeatTime then
                    if self.inputBoxKeyRepeatInfo.key == "Backspace" then processKey = "Backspace";
                    else processChar = self.inputBoxKeyRepeatInfo.char; processKey = self.inputBoxKeyRepeatInfo.key; end
                    self.inputBoxKeyRepeatInfo.nextRepeatTime = currentTime + self.inputBoxKeyRepeatRate; self.inputBoxKeyRepeatInfo.initialRepeat = false;
                elseif not self.inputBoxKeyRepeatInfo.key or not currentPressedSet[self.inputBoxKeyRepeatInfo.key] then
                     self.inputBoxKeyRepeatInfo.key = nil; 
                end

                if processKey == "Backspace" then
                    if elData.cursorPos > 0 and string.len(elData.current_text_value) > 0 then
                        elData.current_text_value = string.sub(elData.current_text_value, 1, elData.cursorPos - 1) .. string.sub(elData.current_text_value, elData.cursorPos + 1)
                        elData.cursorPos = elData.cursorPos - 1; textChangedThisFrame = true;
                    end
                elseif processKey == "Enter" then
                    if elData.onEnterPressed then local cb = elData.onEnterPressed; local text_val = elData.current_text_value; spawn(function() pcall(cb, text_val); wait(0.1); end); end
                    elData.isFocused = false; self.activeInputBoxId = nil;
                elseif processChar ~= "" then
                    elData.current_text_value = string.sub(elData.current_text_value, 1, elData.cursorPos) .. processChar .. string.sub(elData.current_text_value, elData.cursorPos + 1)
                    elData.cursorPos = elData.cursorPos + #processChar; textChangedThisFrame = true;
                end
                
                if textChangedThisFrame then
                    elData.cursorPos = math.max(0, math.min(string.len(elData.current_text_value), elData.cursorPos))
                    if elData.onTextChanged then pcall(elData.onTextChanged, elData.current_text_value); end
                    elData.lastBlinkTime = currentTime; elData.cursorBlinkOn = true;
                end
                self.inputBoxLastPressedKeys = currentPressedSet 
            end
        end
    else
        self.inputBoxLastPressedKeys = {} 
        self.inputBoxKeyRepeatInfo.key = nil
    end
end


function UIHelper:EndFrame()
    self.wasLeftPressedLastFrame = self.leftCurrentlyPressed
end

function UIHelper:BeginWindow(id, titleText, x, y, width, height)
    x = x or 0; y = y or 0; width = width or 200; height = height or 150; titleText = titleText or "Window";
    if not self.areAllWindowsVisible then if self.windows[id] then self:SetWindowVisible(id, false); end return false; end

    local window = self.windows[id]; local titleBarHeight = 20;
    if not window then
        window = { id = id, titleText = titleText, x = x, y = y, width = width, height = height, initialHeight = height, titleBarHeight = titleBarHeight, 
                   isDragging = false, dragOffsetX = 0, dragOffsetY = 0, elements = {}, currentElementIndex = 1, padding = DEFAULT_PADDING, 
                   currentLayoutX = 0, currentLayoutY = 0, nextElementY = 0, contentMaxY = 0, cache = {}, 
                   titleBarOB = CrtOB("Square"), titleTextOB = CrtOB("Text"), mainAreaOB = CrtOB("Square") };
        self.windows[id] = window;
        self:_SetPropertyIfChanged(window.titleBarOB, "Position", {x, y}, window.cache, "titleBarPos")
        self:_SetPropertyIfChanged(window.titleBarOB, "Size", {width, titleBarHeight}, window.cache, "titleBarSize")
        self:_SetPropertyIfChanged(window.titleBarOB, "Color", self.defaultTitleBarColor, window.cache, "titleBarColor")
        self:_SetPropertyIfChanged(window.titleBarOB, "Filled", true, window.cache, "titleBarFilled")
        self:_SetPropertyIfChanged(window.titleBarOB, "Visible", true, window.cache, "titleBarVisible")
        self:_SetPropertyIfChanged(window.titleTextOB, "Text", titleText, window.cache, "titleText")
        self:_SetPropertyIfChanged(window.titleTextOB, "Position", {x + 5, y + (titleBarHeight - 10)/2}, window.cache, "titleTextPos")
        self:_SetPropertyIfChanged(window.titleTextOB, "Size", 10, window.cache, "titleTextSize") 
        self:_SetPropertyIfChanged(window.titleTextOB, "Color", self.defaultTextColor, window.cache, "titleTextColor")
        self:_SetPropertyIfChanged(window.titleTextOB, "Visible", true, window.cache, "titleTextVisible")
        self:_SetPropertyIfChanged(window.mainAreaOB, "Position", {x, y + titleBarHeight}, window.cache, "mainAreaPos")
        self:_SetPropertyIfChanged(window.mainAreaOB, "Size", {width, height - titleBarHeight}, window.cache, "mainAreaSize")
        self:_SetPropertyIfChanged(window.mainAreaOB, "Color", self.defaultWindowBgColor, window.cache, "mainAreaColor")
        self:_SetPropertyIfChanged(window.mainAreaOB, "Filled", true, window.cache, "mainAreaFilled")
        self:_SetPropertyIfChanged(window.mainAreaOB, "Visible", true, window.cache, "mainAreaVisible")
    else
        window.cache = window.cache or {} 
        if window.x ~= x or window.y ~= y or window.width ~= width or window.height ~= height or window.titleText ~= titleText then
            window.x = x; window.y = y; window.width = width; window.height = height; window.titleText = titleText;
            if height ~= window.initialHeight then window.initialHeight = height; end 
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
    window.currentElementIndex = 1; window.currentLayoutX = window.padding; window.currentLayoutY = window.padding; 
    window.nextElementY = window.padding; window.contentMaxY = 0;
    for _, elData in ipairs(window.elements) do elData.updatedThisFrame = false; end
    self.currentWindowId = id

    local titleBarCurrentPos = RetOB(window.titleBarOB, "Position"); local mouseJustPressed = self.leftCurrentlyPressed and not self.wasLeftPressedLastFrame;
    if not window.isDragging then
        if IsWithinRegion(self.mousePosition, window.titleBarOB) then
            self:_SetPropertyIfChanged(window.titleBarOB, "Color", self.hoverTitleBarColor, window.cache, "titleBarColor")
            if not self.uiClickConsumedThisFrame and mouseJustPressed and titleBarCurrentPos then 
                window.isDragging = true; window.dragOffsetX = self.mousePosition.x - titleBarCurrentPos.x;
                window.dragOffsetY = self.mousePosition.y - titleBarCurrentPos.y;
                self:_SetPropertyIfChanged(window.titleBarOB, "Color", self.draggingTitleBarColor, window.cache, "titleBarColor")
                self.uiClickConsumedThisFrame = true;
            end
        else self:_SetPropertyIfChanged(window.titleBarOB, "Color", self.defaultTitleBarColor, window.cache, "titleBarColor"); end
    end
    if window.isDragging then
        if self.leftCurrentlyPressed then
            local newX = self.mousePosition.x - window.dragOffsetX; local newY = self.mousePosition.y - window.dragOffsetY;
            window.x = newX; window.y = newY;
            self:_SetPropertyIfChanged(window.titleBarOB, "Position", {newX, newY}, window.cache, "titleBarPos")
            self:_SetPropertyIfChanged(window.titleTextOB, "Position", {newX + 5, newY + (window.titleBarHeight - 10)/2}, window.cache, "titleTextPos")
            self:_SetPropertyIfChanged(window.mainAreaOB, "Position", {newX, newY + window.titleBarHeight}, window.cache, "mainAreaPos")
            self:_SetPropertyIfChanged(window.titleBarOB, "Color", self.draggingTitleBarColor, window.cache, "titleBarColor")
        else window.isDragging = false; local newC = IsWithinRegion(self.mousePosition, window.titleBarOB) and self.hoverTitleBarColor or self.defaultTitleBarColor;
             self:_SetPropertyIfChanged(window.titleBarOB, "Color", newC, window.cache, "titleBarColor");
        end
    end; return true;
end

function UIHelper:EndWindow()
    local window = self.windows[self.currentWindowId]
    if window then
        for i = window.currentElementIndex, #window.elements do
            local elData = window.elements[i]
            if elData and elData.optionsCache then 
                local elCache = elData.optionsCache; local type = elData.type;
                if type == "text" then if elData.ob then self:_SetPropertyIfChanged(elData.ob, "Visible", false, elCache, "visible"); end 
                elseif type == "square" then if elData.ob then self:_SetPropertyIfChanged(elData.ob, "Visible", false, elCache, "square_visible"); end
                elseif type == "toggle" then
                    if elData.obOuter then self:_SetPropertyIfChanged(elData.obOuter, "Visible", false, elCache, "obOuter_visible"); end
                    if elData.obInner then self:_SetPropertyIfChanged(elData.obInner, "Visible", false, elCache, "obInner_visible"); end
                    if elData.obText then self:_SetPropertyIfChanged(elData.obText, "Visible", false, elCache, "obText_visible"); end
                elseif type == "button" then
                    local ks = "_btn"; if elData.obButtonBg then self:_SetPropertyIfChanged(elData.obButtonBg, "Visible", false, elCache, "obButtonBg_visible"..ks); end
                    if elData.obButtonText then self:_SetPropertyIfChanged(elData.obButtonText, "Visible", false, elCache, "obButtonText_visible"..ks); end
                    elData.isPotentiallyClicking = false;
                elseif type == "inputbox" then
                    local ksi = "_inp"; if elData.obInputBg then self:_SetPropertyIfChanged(elData.obInputBg, "Visible", false, elCache, "obInputBg_visible"..ksi); end
                    if elData.obOutline then self:_SetPropertyIfChanged(elData.obOutline, "Visible", false, elCache, "obOutline_visible"..ksi); end
                    if elData.obInputText then self:_SetPropertyIfChanged(elData.obInputText, "Visible", false, elCache, "obInputText_visible"..ksi); end
                    if elData.obCursor then self:_SetPropertyIfChanged(elData.obCursor, "Visible", false, elCache, "obCursor_visible_val"..ksi); end
                elseif type == "dropdown" or type == "multidropdown" then
                    local ksd = (type == "multidropdown") and "_mdd" or "_dd";
                    if elData.obMainBox then self:_SetPropertyIfChanged(elData.obMainBox, "Visible", false, elCache, "obMainBox_visible"..ksd); end
                    if elData.obMainBoxBorder then self:_SetPropertyIfChanged(elData.obMainBoxBorder, "Visible", false, elCache, "obMainBoxBorder_visible"..ksd); end
                    if elData.obCurrentText then self:_SetPropertyIfChanged(elData.obCurrentText, "Visible", false, elCache, "obCurrentText_visible"..ksd); end
                    if elData.obArrow then self:_SetPropertyIfChanged(elData.obArrow, "Visible", false, elCache, "obArrow_visible"..ksd); end
                    if elData.itemOBs then for _, itemD in ipairs(elData.itemOBs) do
                        if itemD.bg and itemD.cache_bg then self:_SetPropertyIfChanged(itemD.bg, "Visible", false, itemD.cache_bg, "visible_val"..ksd); end 
                        if itemD.text and itemD.cache_text then self:_SetPropertyIfChanged(itemD.text, "Visible", false, itemD.cache_text, "visible_text_val"..ksd); end 
                    end; end; elData.isOpen = false; 
                    if self.activeDropdownId and self.activeDropdownId.windowId == window.id and self.activeDropdownId.elementIndex == i then self.activeDropdownId = nil; end
                end
            end
        end
        while #window.elements >= window.currentElementIndex do table.remove(window.elements); end
        local reqH = window.contentMaxY + window.padding; local initH = window.initialHeight - window.titleBarHeight;
        local curSize = RetOB(window.mainAreaOB, "Size");
        if curSize then local newH = math.max(initH, reqH);
            if math.abs(newH - curSize.y) > 0.1 then 
                self:_SetPropertyIfChanged(window.mainAreaOB, "Size", {curSize.x, newH}, window.cache, "mainAreaSize");
                window.height = newH + window.titleBarHeight;
            end
        end
    end; self.currentWindowId = nil;
end

function UIHelper:Text(textString, options)
    if not self.currentWindowId then print("UIHelper Err: Text() outside Begin/End"); return nil; end
    local window = self.windows[self.currentWindowId]; if not window then print("UIHelper Err: Text() no window"); return nil; end
    options = options or {}; local relX = options.x; local relY = options.y; 
    local size = options.size or 10; local color = options.color or self.defaultTextColor;
    local mainAreaPos = RetOB(window.mainAreaOB, "Position"); if not mainAreaPos then print("UIHelper Warn: Text() no mainAreaPos"); return nil; end 
    local actualRelX, actualRelY; local isAuto = (options.x==nil and options.y==nil);
    if isAuto then actualRelX=window.currentLayoutX; actualRelY=window.nextElementY; else actualRelX=relX or 0; actualRelY=relY or 0; end
    local elData, obToUse;
    if window.currentElementIndex <= #window.elements and window.elements[window.currentElementIndex].type == "text" then
        elData = window.elements[window.currentElementIndex]; obToUse = elData.ob; elData.optionsCache = elData.optionsCache or {};
    else obToUse = CrtOB("Text"); elData = {ob=obToUse, type="text", optionsCache={}}; window.elements[window.currentElementIndex]=elData; end
    self:_SetPropertyIfChanged(obToUse, "Visible", true, elData.optionsCache, "visible");
    elData.originalRelX=actualRelX; elData.originalRelY=actualRelY; elData.updatedThisFrame=true;
    elData.optionsCache.textString_arg=textString; elData.optionsCache.size_arg=size; elData.optionsCache.color_arg=color; 
    elData.optionsCache.relX_arg=actualRelX; elData.optionsCache.relY_arg=actualRelY;
    self:_SetPropertyIfChanged(obToUse, "Text", textString, elData.optionsCache, "textString_val");
    self:_SetPropertyIfChanged(obToUse, "Position", {mainAreaPos.x+actualRelX, mainAreaPos.y+actualRelY}, elData.optionsCache, "absPosition_val");
    self:_SetPropertyIfChanged(obToUse, "Size", size, elData.optionsCache, "size_val");
    self:_SetPropertyIfChanged(obToUse, "Color", color, elData.optionsCache, "color_val");
    if isAuto then window.nextElementY = actualRelY + size + window.padding; end
    window.contentMaxY = math.max(window.contentMaxY, actualRelY + size);
    window.currentElementIndex = window.currentElementIndex + 1; return obToUse;
end

function UIHelper:Square(options)
    if not self.currentWindowId then print("UIHelper Err: Square() outside Begin/End"); return nil; end
    local window = self.windows[self.currentWindowId]; if not window then print("UIHelper Err: Square() no window"); return nil; end
    options = options or {}; local relX = options.x; local relY = options.y; 
    local width = options.width or 20; local height = options.height or 20;
    local color = options.color or {100,100,100}; local filled = options.filled == nil and true or options.filled;
    local thickness = options.thickness or 1;
    local mainAreaPos = RetOB(window.mainAreaOB, "Position"); if not mainAreaPos then print("UIHelper Warn: Square() no mainAreaPos"); return nil; end
    local actualRelX, actualRelY; local isAuto = (relX==nil and relY==nil);
    if isAuto then actualRelX=window.currentLayoutX; actualRelY=window.nextElementY; else actualRelX=relX or 0; actualRelY=relY or 0; end
    local elData, obToUse;
    if window.currentElementIndex <= #window.elements and window.elements[window.currentElementIndex].type == "square" then
        elData = window.elements[window.currentElementIndex]; obToUse = elData.ob; elData.optionsCache = elData.optionsCache or {};
    else obToUse = CrtOB("Square"); elData = {ob=obToUse, type="square", originalRelX=actualRelX, originalRelY=actualRelY, optionsCache={}}; window.elements[window.currentElementIndex]=elData; end
    self:_SetPropertyIfChanged(obToUse, "Visible", true, elData.optionsCache, "square_visible");
    elData.originalRelX=actualRelX; elData.originalRelY=actualRelY; elData.updatedThisFrame=true;
    local sqPos={mainAreaPos.x+actualRelX, mainAreaPos.y+actualRelY}; local sqSize={width, height};
    self:_SetPropertyIfChanged(obToUse, "Position", sqPos, elData.optionsCache, "square_pos");
    self:_SetPropertyIfChanged(obToUse, "Size", sqSize, elData.optionsCache, "square_size");
    self:_SetPropertyIfChanged(obToUse, "Color", color, elData.optionsCache, "square_color");
    self:_SetPropertyIfChanged(obToUse, "Filled", filled, elData.optionsCache, "square_filled");
    if not filled then self:_SetPropertyIfChanged(obToUse, "Thickness", thickness, elData.optionsCache, "square_thickness"); end
    if isAuto then window.nextElementY = actualRelY + height + window.padding; end
    window.contentMaxY = math.max(window.contentMaxY, actualRelY + height);
    window.currentElementIndex = window.currentElementIndex + 1; return obToUse;
end

function UIHelper:Toggle(textString, options)
    if not self.currentWindowId then print("UIHelper Err: Toggle() outside Begin/End"); return nil; end
    local window = self.windows[self.currentWindowId]; if not window then print("UIHelper Err: Toggle() no window"); return nil; end
    options = options or {}; local relX=options.x; local relY=options.y; 
    local defVal=options.defaultValue or false; local onChngCb=options.onChanged;
    local clrs=options.colors or {}; local olC=clrs.outline or self.defaultToggleOutlineColor;
    local offC=clrs.off or self.defaultToggleOffColor; local onC=clrs.on or self.defaultToggleOnColor;
    local txtCopt=clrs.text or self.defaultTextColor;
    local tgSz=options.size or 16; local txtGp=options.textGap or 5; local txtSz=options.textSize or 10;
    local mainAreaPos = RetOB(window.mainAreaOB, "Position"); if not mainAreaPos then print("UIHelper Warn: Toggle() no mainAreaPos"); return nil; end
    local actualRelX, actualRelY; local isAuto = (relX==nil and relY==nil);
    if isAuto then actualRelX=window.currentLayoutX; actualRelY=window.nextElementY; else actualRelX=relX or window.currentLayoutX; actualRelY=relY or window.nextElementY; end
    local elData, obO, obI, obT;
    if window.currentElementIndex <= #window.elements and window.elements[window.currentElementIndex].type == "toggle" then
        elData = window.elements[window.currentElementIndex]; obO=elData.obOuter; obI=elData.obInner; obT=elData.obText;
        elData.optionsCache = elData.optionsCache or {};
    else obO=CrtOB("Square"); obI=CrtOB("Square"); obT=CrtOB("Text");
        elData = {obOuter=obO, obInner=obI, obText=obT, type="toggle", state=defVal, onChanged=onChngCb, optionsCache={}};
        window.elements[window.currentElementIndex]=elData; elData.state=defVal; 
    end
    self:_SetPropertyIfChanged(obO, "Visible", true, elData.optionsCache, "obOuter_visible");
    self:_SetPropertyIfChanged(obI, "Visible", true, elData.optionsCache, "obInner_visible"); 
    self:_SetPropertyIfChanged(obT, "Visible", true, elData.optionsCache, "obText_visible");
    if elData.onChanged~=onChngCb then elData.onChanged=onChngCb; end
    if options.defaultValue~=nil and elData.optionsCache.defaultValue_arg~=options.defaultValue then elData.state=options.defaultValue; end
    elData.optionsCache.defaultValue_arg=options.defaultValue;
    elData.originalRelX=actualRelX; elData.originalRelY=actualRelY; elData.updatedThisFrame=true;
    elData.optionsCache.textString_arg=textString; elData.optionsCache.relX_arg=actualRelX; elData.optionsCache.relY_arg=actualRelY; 
    elData.optionsCache.toggleSize_arg=tgSz; elData.optionsCache.textSize_arg=txtSz; elData.optionsCache.textGap_arg=txtGp;
    elData.optionsCache.outlineColor_arg=olC; elData.optionsCache.offColor_arg=offC; elData.optionsCache.onColor_arg=onC; 
    elData.optionsCache.textColor_arg=txtCopt;
    local oPos={mainAreaPos.x+actualRelX, mainAreaPos.y+actualRelY};
    self:_SetPropertyIfChanged(obO, "Position", oPos, elData.optionsCache, "obOuter_pos_val");
    self:_SetPropertyIfChanged(obO, "Size", {tgSz, tgSz}, elData.optionsCache, "obOuter_size_val");
    self:_SetPropertyIfChanged(obO, "Color", olC, elData.optionsCache, "obOuter_color_val");
    self:_SetPropertyIfChanged(obO, "Filled", false, elData.optionsCache, "obOuter_filled_val"); 
    self:_SetPropertyIfChanged(obO, "Thickness", 1, elData.optionsCache, "obOuter_thickness_val"); 
    local iBSz=tgSz-4; local iBOff=(tgSz-iBSz)/2;
    local iPos={mainAreaPos.x+actualRelX+iBOff, mainAreaPos.y+actualRelY+iBOff};
    self:_SetPropertyIfChanged(obI, "Position", iPos, elData.optionsCache, "obInner_pos_val");
    self:_SetPropertyIfChanged(obI, "Size", {iBSz, iBSz}, elData.optionsCache, "obInner_size_val");
    self:_SetPropertyIfChanged(obI, "Filled", true, elData.optionsCache, "obInner_filled_val");
    local tPos={mainAreaPos.x+actualRelX+tgSz+txtGp, mainAreaPos.y+actualRelY+(tgSz-txtSz)/2};
    self:_SetPropertyIfChanged(obT, "Text", textString or "", elData.optionsCache, "obText_text_val");
    self:_SetPropertyIfChanged(obT, "Position", tPos, elData.optionsCache, "obText_pos_val");
    self:_SetPropertyIfChanged(obT, "Size", txtSz, elData.optionsCache, "obText_size_val");
    self:_SetPropertyIfChanged(obT, "Color", txtCopt, elData.optionsCache, "obText_color_val");
    local mJP=self.leftCurrentlyPressed and not self.wasLeftPressedLastFrame;
    if not self.uiClickConsumedThisFrame and mJP and IsWithinRegion(self.mousePosition, obO) then 
        elData.state = not elData.state;
        if elData.onChanged then local cb=elData.onChanged; local st=elData.state; spawn(function()pcall(cb,st);wait(0.1);end); end
        self.uiClickConsumedThisFrame=true; 
    end
    local curInC=elData.state and onC or offC;
    self:_SetPropertyIfChanged(obI, "Color", curInC, elData.optionsCache, "obInner_color_val");
    if isAuto then window.nextElementY=actualRelY+tgSz+window.padding; end
    window.contentMaxY=math.max(window.contentMaxY, actualRelY+tgSz);
    window.currentElementIndex=window.currentElementIndex+1; return elData;
end

function UIHelper:Button(labelText, options)
    if not self.currentWindowId then print("UIHelper Err: Button() outside Begin/End"); return nil; end
    local window = self.windows[self.currentWindowId]; if not window then print("UIHelper Err: Button() no window"); return nil; end
    local k_suf = "_btn"; options = options or {}; local onClickCb = options.onClicked;
    local clrs=options.colors or {}; local bgC=clrs.bg or self.defaultButtonBgColor;
    local txtC=clrs.text or self.defaultButtonTextColor; local hBgC=clrs.hoverBg or self.hoverButtonBgColor;
    local pBgC=clrs.pressedBg or self.pressedButtonBgColor;
    local rX=options.x; local rY=options.y; local wd=options.width or 80; local hg=options.height or 22;
    local txtSz=options.textSize or 10; local txtPX=options.textPaddingHorizontal or 5;
    local txtPY=(hg-txtSz)/2; if txtPY<0 then txtPY=0; end
    local mainAreaPos=RetOB(window.mainAreaOB, "Position"); if not mainAreaPos then print("UIHelper Warn: Button() no mainAreaPos"); return nil; end
    local actualRX, actualRY; local isAuto=(rX==nil and rY==nil);
    if isAuto then actualRX=window.currentLayoutX; actualRY=window.nextElementY; else actualRX=rX or 0; actualRY=rY or 0; end
    local elData, obBg, obTxt;
    if window.currentElementIndex<=#window.elements and window.elements[window.currentElementIndex].type=="button" then
        elData=window.elements[window.currentElementIndex]; obBg=elData.obButtonBg; obTxt=elData.obButtonText;
        elData.optionsCache = elData.optionsCache or {};
    else obBg=CrtOB("Square"); obTxt=CrtOB("Text");
        elData={obButtonBg=obBg, obButtonText=obTxt, type="button", onClicked=onClickCb, optionsCache={}, isPotentiallyClicking=false};
        window.elements[window.currentElementIndex]=elData;
    end
    self:_SetPropertyIfChanged(obBg, "Visible", true, elData.optionsCache, "obButtonBg_visible"..k_suf);
    self:_SetPropertyIfChanged(obTxt, "Visible", true, elData.optionsCache, "obButtonText_visible"..k_suf);
    if elData.onClicked~=onClickCb then elData.onClicked=onClickCb; end
    elData.originalRelX=actualRX; elData.originalRelY=actualRY; elData.updatedThisFrame=true;
    local absX=mainAreaPos.x+actualRX; local absY=mainAreaPos.y+actualRY;
    self:_SetPropertyIfChanged(obBg, "Position", {absX, absY}, elData.optionsCache, "obButtonBg_pos_val"..k_suf);
    self:_SetPropertyIfChanged(obBg, "Size", {wd, hg}, elData.optionsCache, "obButtonBg_size_val"..k_suf);
    self:_SetPropertyIfChanged(obBg, "Filled", true, elData.optionsCache, "obButtonBg_filled_val"..k_suf);
    self:_SetPropertyIfChanged(obTxt, "Text", labelText or "", elData.optionsCache, "obButtonText_text_val"..k_suf);
    self:_SetPropertyIfChanged(obTxt, "Position", {absX+txtPX, absY+txtPY}, elData.optionsCache, "obButtonText_pos_val"..k_suf);
    self:_SetPropertyIfChanged(obTxt, "Size", txtSz, elData.optionsCache, "obButtonText_size_val"..k_suf);
    self:_SetPropertyIfChanged(obTxt, "Color", txtC, elData.optionsCache, "obButtonText_color_val"..k_suf);
    local curBgC=bgC; local isMOver=IsWithinRegion(self.mousePosition, obBg);
    local mJP=self.leftCurrentlyPressed and not self.wasLeftPressedLastFrame;
    local mJR=not self.leftCurrentlyPressed and self.wasLeftPressedLastFrame;
    if elData.isPotentiallyClicking then
        if isMOver then curBgC=pBgC; if mJR then if elData.onClicked then spawn(function()pcall(elData.onClicked);wait(0.1);end);end elData.isPotentiallyClicking=false; curBgC=hBgC; end
        else curBgC=bgC; if mJR then elData.isPotentiallyClicking=false; end end
        if not self.leftCurrentlyPressed then elData.isPotentiallyClicking=false; if not isMOver then curBgC=bgC; end; end
    else if isMOver then curBgC=hBgC; if not self.uiClickConsumedThisFrame and mJP then elData.isPotentiallyClicking=true; curBgC=pBgC; self.uiClickConsumedThisFrame=true; end
        else curBgC=bgC; end
    end
    self:_SetPropertyIfChanged(obBg, "Color", curBgC, elData.optionsCache, "obButtonBg_color_val"..k_suf);
    if isAuto then window.nextElementY=actualRY+hg+window.padding; end
    window.contentMaxY=math.max(window.contentMaxY, actualRY+hg);
    window.currentElementIndex=window.currentElementIndex+1; return elData;
end

function UIHelper:InputBox(label, options)
    if not self.currentWindowId then print("UIHelper Err: InputBox() outside Begin/End"); return nil; end
    local window=self.windows[self.currentWindowId]; if not window then print("UIHelper Err: InputBox() no window"); return nil; end
    local k_sufi="_inp"; options=options or {}; local extTxtVal=options.text or "";
    local onTxtChg=options.onTextChanged; local onEntPr=options.onEnterPressed;
    local clrs=options.colors or {}; local bgCi=clrs.bg or self.defaultInputBgColor; 
    local txtCi=clrs.text or self.defaultInputTextColor; local olCi=clrs.outline or self.defaultInputOutlineColor;
    local focOlCi=clrs.focusedOutline or self.focusedInputOutlineColor; local crsCi=clrs.cursor or self.defaultCursorColor;
    local rXi=options.x; local rYi=options.y; local widi=options.width or 150; local hgti=options.height or 20;
    local txtSzi=options.textSize or 10; local txtPXi=4; local txtPYi=(hgti-txtSzi)/2; if txtPYi<0 then txtPYi=0; end
    local mainAreaPos=RetOB(window.mainAreaOB, "Position"); if not mainAreaPos then print("UIHelper Warn: InputBox() no mainAreaPos"); return nil; end
    local actRX, actRY; local isAutoI=(rXi==nil and rYi==nil);
    if isAutoI then actRX=window.currentLayoutX; actRY=window.nextElementY; else actRX=rXi or 0; actRY=rYi or 0; end
    local elData, obIBg, obITxt, obICsr, obIOl;
    if window.currentElementIndex<=#window.elements and window.elements[window.currentElementIndex].type=="inputbox" then
        elData=window.elements[window.currentElementIndex]; obIBg=elData.obInputBg; obITxt=elData.obInputText; 
        obICsr=elData.obCursor; obIOl=elData.obOutline; elData.optionsCache=elData.optionsCache or {};
    else obIBg=CrtOB("Square"); obITxt=CrtOB("Text"); obICsr=CrtOB("Line"); obIOl=CrtOB("Square");
        elData={obInputBg=obIBg,obInputText=obITxt,obCursor=obICsr,obOutline=obIOl,type="inputbox",
                current_text_value=extTxtVal, cursorPos=string.len(extTxtVal), isFocused=false, 
                cursorBlinkOn=true, lastBlinkTime=os.clock(), optionsCache={}};
        window.elements[window.currentElementIndex]=elData;
    end
    self:_SetPropertyIfChanged(obIBg, "Visible", true, elData.optionsCache, "obInputBg_visible"..k_sufi);
    self:_SetPropertyIfChanged(obITxt, "Visible", true, elData.optionsCache, "obInputText_visible"..k_sufi);
    self:_SetPropertyIfChanged(obIOl, "Visible", true, elData.optionsCache, "obOutline_visible"..k_sufi);
    elData.onTextChanged=onTxtChg; elData.onEnterPressed=onEntPr;
    if not elData.isFocused and elData.current_text_value~=extTxtVal then elData.current_text_value=extTxtVal; elData.cursorPos=string.len(elData.current_text_value); end
    elData.originalRelX=actRX; elData.originalRelY=actRY; elData.updatedThisFrame=true;
    local absIX=mainAreaPos.x+actRX; local absIY=mainAreaPos.y+actRY; local inputElPos={absIX, absIY};
    self:_SetPropertyIfChanged(obIOl, "Position", inputElPos, elData.optionsCache, "obOutline_pos"..k_sufi);
    self:_SetPropertyIfChanged(obIOl, "Size", {widi, hgti}, elData.optionsCache, "obOutline_size"..k_sufi);
    self:_SetPropertyIfChanged(obIOl, "Filled", false, elData.optionsCache, "obOutline_filled"..k_sufi);
    self:_SetPropertyIfChanged(obIOl, "Thickness", 1, elData.optionsCache, "obOutline_thickness"..k_sufi);
    local curOlC=elData.isFocused and focOlCi or olCi;
    self:_SetPropertyIfChanged(obIOl, "Color", curOlC, elData.optionsCache, "obOutline_color"..k_sufi);
    self:_SetPropertyIfChanged(obIBg, "Position", inputElPos, elData.optionsCache, "obInputBg_pos_val"..k_sufi);
    self:_SetPropertyIfChanged(obIBg, "Size", {widi, hgti}, elData.optionsCache, "obInputBg_size_val"..k_sufi);
    self:_SetPropertyIfChanged(obIBg, "Color", bgCi, elData.optionsCache, "obInputBg_color_val"..k_sufi);
    self:_SetPropertyIfChanged(obIBg, "Filled", true, elData.optionsCache, "obInputBg_filled_val"..k_sufi);
    local mJPi=self.leftCurrentlyPressed and not self.wasLeftPressedLastFrame; local curElID={windowId=window.id, elementIndex=window.currentElementIndex};
    if mJPi and not self.uiClickConsumedThisFrame then
        if IsWithinRegion(self.mousePosition, obIBg) then
            if not elData.isFocused then
                if self.activeInputBoxId and (self.activeInputBoxId.windowId~=curElID.windowId or self.activeInputBoxId.elementIndex~=curElID.elementIndex) then
                    local pAW=self.windows[self.activeInputBoxId.windowId];
                    if pAW and pAW.elements[self.activeInputBoxId.elementIndex] and pAW.elements[self.activeInputBoxId.elementIndex].type=="inputbox" then
                        pAW.elements[self.activeInputBoxId.elementIndex].isFocused=false;
                    end
                end
                elData.isFocused=true; self.activeInputBoxId=curElID;
                elData.lastBlinkTime=os.clock(); elData.cursorBlinkOn=true; elData.cursorPos=string.len(elData.current_text_value);
            end; self.uiClickConsumedThisFrame=true;
        end
    end
    local txtToDisp=elData.current_text_value;
    self:_SetPropertyIfChanged(obITxt, "Text", txtToDisp, elData.optionsCache, "obInputText_text_val"..k_sufi);
    self:_SetPropertyIfChanged(obITxt, "Position", {absIX+txtPXi, absIY+txtPYi}, elData.optionsCache, "obInputText_pos_val"..k_sufi);
    self:_SetPropertyIfChanged(obITxt, "Size", txtSzi, elData.optionsCache, "obInputText_size_val"..k_sufi);
    self:_SetPropertyIfChanged(obITxt, "Color", txtCi, elData.optionsCache, "obInputText_color_val"..k_sufi);
    if elData.isFocused then
        if (os.clock()-elData.lastBlinkTime)>0.5 then elData.cursorBlinkOn=not elData.cursorBlinkOn; elData.lastBlinkTime=os.clock(); end
        if elData.cursorBlinkOn then
            local estCW=txtSzi*0.6; local csrXOff=0;
            if _G.GetTextSize then local preCTxt=string.sub(txtToDisp,1,elData.cursorPos); local preCSz=GetTextSize(preCTxt,"Arial",txtSzi); csrXOff=preCSz and preCSz.X or (elData.cursorPos*estCW);
            else csrXOff=elData.cursorPos*estCW; end
            csrXOff=math.min(csrXOff, widi-txtPXi*2-2); 
            local csrDrwX=absIX+txtPXi+csrXOff; local csrPYTop=absIY+txtPYi; local csrPYBot=absIY+txtPYi+txtSzi;
            self:_SetPropertyIfChanged(obICsr,"From",{csrDrwX,csrPYTop},elData.optionsCache,"obCursor_from_val"..k_sufi);
            self:_SetPropertyIfChanged(obICsr,"To",{csrDrwX,csrPYBot},elData.optionsCache,"obCursor_to_val"..k_sufi);
            self:_SetPropertyIfChanged(obICsr,"Color",crsCi,elData.optionsCache,"obCursor_color_val"..k_sufi);
            self:_SetPropertyIfChanged(obICsr,"Thickness",1,elData.optionsCache,"obCursor_thickness_val"..k_sufi);
        end; self:_SetPropertyIfChanged(obICsr,"Visible",elData.cursorBlinkOn,elData.optionsCache,"obCursor_visible_val"..k_sufi);
    else self:_SetPropertyIfChanged(obICsr,"Visible",false,elData.optionsCache,"obCursor_visible_val"..k_sufi); end
    if isAutoI then window.nextElementY=actRY+hgti+window.padding; end
    window.contentMaxY=math.max(window.contentMaxY, actRY+hgti);
    window.currentElementIndex=window.currentElementIndex+1; return elData.current_text_value;
end

-- Assume Dropdown and MultiDropdown functions are here and correct from previous "fully revised" version.
-- Pasting them here would make the response extremely long. Ensure they use the same robust element creation pattern.

function UIHelper:Dropdown(labelText, options)
    if not self.currentWindowId then print("UIHelper Err: Dropdown() outside Begin/End"); return nil; end
    local window = self.windows[self.currentWindowId]; if not window then print("UIHelper Err: Dropdown() no window"); return nil; end
    local k_sufd = "_dd"; options = options or {}; local items_d = options.items or {}; local defSel_d = options.defaultSelectedItem;
    local onSelCb_d = options.onItemSelected; local clrs_d = options.colors or {};
    local bgC_d=clrs_d.bg or self.defaultDropdownBgColor; local olC_d=clrs_d.outline or self.defaultDropdownOutlineColor;
    local opOlC_d=clrs_d.openOutline or self.defaultDropdownOpenOutlineColor; local txtC_d=clrs_d.text or self.defaultDropdownTextColor;
    local arrC_d=clrs_d.arrow or self.defaultDropdownArrowColor; local itmHovBgC_d=clrs_d.itemHoverBg or self.defaultDropdownItemHoverBgColor;
    local selItmTxtC_d=clrs_d.selectedItemText or self.defaultDropdownSelectedItemTextColor;
    local rXd=options.x; local rYd=options.y; local wd_d=options.width or 150; local hg_d=options.height or 20;
    local itmHg_d=options.itemHeight or hg_d; local txtSz_d=options.textSize or 10; local arrSz_d=math.floor(hg_d*0.4);
    local mainAreaPos_d=RetOB(window.mainAreaOB,"Position"); if not mainAreaPos_d then print("UIHelper Warn: Dropdown() no mainAreaPos"); return nil; end
    local actRX_d, actRY_d; local isAuto_d=(rXd==nil and rYd==nil);
    if isAuto_d then actRX_d=window.currentLayoutX; actRY_d=window.nextElementY; else actRX_d=rXd or window.currentLayoutX; actRY_d=rYd or window.nextElementY; end
    local elData_d, obMB_d, obCT_d, obArr_d, obMBB_d;
    if window.currentElementIndex<=#window.elements and window.elements[window.currentElementIndex].type=="dropdown" then
        elData_d=window.elements[window.currentElementIndex]; obMB_d=elData_d.obMainBox; obMBB_d=elData_d.obMainBoxBorder;
        obCT_d=elData_d.obCurrentText; obArr_d=elData_d.obArrow; elData_d.optionsCache=elData_d.optionsCache or {};
    else obMB_d=CrtOB("Square"); obMBB_d=CrtOB("Square"); obCT_d=CrtOB("Text"); obArr_d=CrtOB("Line"); 
        elData_d={obMainBox=obMB_d,obMainBoxBorder=obMBB_d,obCurrentText=obCT_d,obArrow=obArr_d,type="dropdown",
                  items=items_d,selectedItem=defSel_d,isOpen=false,onItemSelected=onSelCb_d,itemHeight=itmHg_d,
                  colors=clrs_d,itemOBs={},currentHoveredItemIndex=-1,optionsCache={}};
        window.elements[window.currentElementIndex]=elData_d;
    end
    self:_SetPropertyIfChanged(obMB_d,"Visible",true,elData_d.optionsCache,"obMainBox_visible"..k_sufd);
    self:_SetPropertyIfChanged(obMBB_d,"Visible",true,elData_d.optionsCache,"obMainBoxBorder_visible"..k_sufd);
    self:_SetPropertyIfChanged(obCT_d,"Visible",true,elData_d.optionsCache,"obCurrentText_visible"..k_sufd);
    self:_SetPropertyIfChanged(obArr_d,"Visible",true,elData_d.optionsCache,"obArrow_visible"..k_sufd);
    elData_d.items=items_d; elData_d.onItemSelected=onSelCb_d; elData_d.colors=clrs_d; elData_d.itemHeight=itmHg_d;
    if options.defaultSelectedItem~=nil and elData_d.optionsCache.defaultSelectedItem_arg~=options.defaultSelectedItem then elData_d.selectedItem=options.defaultSelectedItem; end
    elData_d.optionsCache.defaultSelectedItem_arg=options.defaultSelectedItem;
    elData_d.originalRelX=actRX_d; elData_d.originalRelY=actRY_d; elData_d.updatedThisFrame=true;
    local mBPos_d={mainAreaPos_d.x+actRX_d,mainAreaPos_d.y+actRY_d};
    self:_SetPropertyIfChanged(obMB_d,"Position",mBPos_d,elData_d.optionsCache,"obMainBox_pos_val"..k_sufd);
    self:_SetPropertyIfChanged(obMB_d,"Size",{wd_d,hg_d},elData_d.optionsCache,"obMainBox_size_val"..k_sufd);
    self:_SetPropertyIfChanged(obMB_d,"Color",bgC_d,elData_d.optionsCache,"obMainBox_color_val"..k_sufd);
    self:_SetPropertyIfChanged(obMB_d,"Filled",true,elData_d.optionsCache,"obMainBox_filled_val"..k_sufd);
    self:_SetPropertyIfChanged(obMBB_d,"Position",mBPos_d,elData_d.optionsCache,"obMainBoxBorder_pos_val"..k_sufd);
    self:_SetPropertyIfChanged(obMBB_d,"Size",{wd_d,hg_d},elData_d.optionsCache,"obMainBoxBorder_size_val"..k_sufd);
    self:_SetPropertyIfChanged(obMBB_d,"Filled",false,elData_d.optionsCache,"obMainBoxBorder_filled_val"..k_sufd);
    self:_SetPropertyIfChanged(obMBB_d,"Thickness",1,elData_d.optionsCache,"obMainBoxBorder_thickness_val"..k_sufd);
    local dspTxt_d=elData_d.selectedItem or labelText or "Select...";
    local curTxtPos_d={mainAreaPos_d.x+actRX_d+5,mainAreaPos_d.y+actRY_d+(hg_d-txtSz_d)/2};
    self:_SetPropertyIfChanged(obCT_d,"Text",tostring(dspTxt_d),elData_d.optionsCache,"obCurrentText_text_val"..k_sufd);
    self:_SetPropertyIfChanged(obCT_d,"Position",curTxtPos_d,elData_d.optionsCache,"obCurrentText_pos_val"..k_sufd);
    self:_SetPropertyIfChanged(obCT_d,"Size",txtSz_d,elData_d.optionsCache,"obCurrentText_size_val"..k_sufd);
    self:_SetPropertyIfChanged(obCT_d,"Color",txtC_d,elData_d.optionsCache,"obCurrentText_color_val"..k_sufd);
    local arrX_d=mainAreaPos_d.x+actRX_d+wd_d-arrSz_d-5; local arrY_d=mainAreaPos_d.y+actRY_d+(hg_d-arrSz_d)/2;
    local arrFr_d, arrTo_d; if elData_d.isOpen then arrFr_d={arrX_d,arrY_d+arrSz_d}; arrTo_d={arrX_d+arrSz_d/2,arrY_d}; else arrFr_d={arrX_d,arrY_d}; arrTo_d={arrX_d+arrSz_d/2,arrY_d+arrSz_d}; end
    self:_SetPropertyIfChanged(elData_d.obArrow,"From",arrFr_d,elData_d.optionsCache,"obArrow_from_val"..k_sufd);
    self:_SetPropertyIfChanged(elData_d.obArrow,"To",arrTo_d,elData_d.optionsCache,"obArrow_to_val"..k_sufd);
    self:_SetPropertyIfChanged(elData_d.obArrow,"Color",arrC_d,elData_d.optionsCache,"obArrow_color_val"..k_sufd);
    self:_SetPropertyIfChanged(elData_d.obArrow,"Thickness",2,elData_d.optionsCache,"obArrow_thickness_val"..k_sufd);
    local mJP_d=self.leftCurrentlyPressed and not self.wasLeftPressedLastFrame; local bdColKey_d="obMainBoxBorder_color_val"..k_sufd;
    if not self.uiClickConsumedThisFrame and mJP_d and IsWithinRegion(self.mousePosition, obMB_d) then
        elData_d.isOpen=not elData_d.isOpen;
        if elData_d.isOpen then
            if self.activeDropdownId then local oW=self.windows[self.activeDropdownId.windowId]; if oW and oW.elements[self.activeDropdownId.elementIndex] then local oE=oW.elements[self.activeDropdownId.elementIndex]; if oE and(oE.type=="dropdown"or oE.type=="multidropdown")and oE.isOpen then oE.isOpen=false; if oE.obMainBoxBorder and oE.optionsCache and oE.colors then local oKS=(oE.type=="multidropdown")and"_mdd"or"_dd"; self:_SetPropertyIfChanged(oE.obMainBoxBorder,"Color",oE.colors.outline or self.defaultDropdownOutlineColor,oE.optionsCache,"obMainBoxBorder_color_val"..oKS);end;end;end;end
            self.activeDropdownId={windowId=window.id,elementIndex=window.currentElementIndex};
        else self.activeDropdownId=nil; end
        self.uiClickConsumedThisFrame=true;
    end
    local curBdC_d=elData_d.isOpen and opOlC_d or olC_d;
    self:_SetPropertyIfChanged(obMBB_d,"Color",curBdC_d,elData_d.optionsCache,bdColKey_d);
    for i=1,#elData_d.itemOBs do local iDpy=elData_d.itemOBs[i]; if iDpy then local iShBVis=elData_d.isOpen and(elData_d.items and elData_d.items[i]~=nil); if iDpy.bg and iDpy.cache_bg then self:_SetPropertyIfChanged(iDpy.bg,"Visible",iShBVis,iDpy.cache_bg,"visible_val"..k_sufd);end; if iDpy.text and iDpy.cache_text then self:_SetPropertyIfChanged(iDpy.text,"Visible",iShBVis,iDpy.cache_text,"visible_text_val"..k_sufd);end;end;end
    if elData_d.isOpen then elData_d.currentHoveredItemIndex=-1; local itmLstOffY_d=hg_d;
        while #elData_d.itemOBs<#elData_d.items do table.insert(elData_d.itemOBs,{bg=CrtOB("Square"),text=CrtOB("Text"),cache_bg={},cache_text={}});end
        for i=#elData_d.items+1,#elData_d.itemOBs do local iDpyS=elData_d.itemOBs[i]; if iDpyS.bg and iDpyS.cache_bg then self:_SetPropertyIfChanged(iDpyS.bg,"Visible",false,iDpyS.cache_bg,"visible_val"..k_sufd.."_surplus");end; if iDpyS.text and iDpyS.cache_text then self:_SetPropertyIfChanged(iDpyS.text,"Visible",false,iDpyS.cache_text,"visible_text_val"..k_sufd.."_surplus");end;end
        for i=1,#elData_d.items do local iDt_d=elData_d.items[i]; local iDpy_d=elData_d.itemOBs[i]; local iBgOb_d=iDpy_d.bg; local iTxtOb_d=iDpy_d.text; local iChBg_d=iDpy_d.cache_bg; local iChTxt_d=iDpy_d.cache_text;
            local curItmAbsY_d=mBPos_d.y+itmLstOffY_d+(i-1)*itmHg_d; local iBgPos_d={mBPos_d.x,curItmAbsY_d}; local iTxtPos_d={mBPos_d.x+5,curItmAbsY_d+(itmHg_d-txtSz_d)/2};
            self:_SetPropertyIfChanged(iBgOb_d,"Position",iBgPos_d,iChBg_d,"pos_val"..k_sufd); self:_SetPropertyIfChanged(iBgOb_d,"Size",{wd_d,itmHg_d},iChBg_d,"size_val"..k_sufd); self:_SetPropertyIfChanged(iBgOb_d,"Filled",true,iChBg_d,"filled_val"..k_sufd);
            self:_SetPropertyIfChanged(iTxtOb_d,"Text",tostring(iDt_d),iChTxt_d,"text_val"..k_sufd); self:_SetPropertyIfChanged(iTxtOb_d,"Position",iTxtPos_d,iChTxt_d,"pos_text_val"..k_sufd); self:_SetPropertyIfChanged(iTxtOb_d,"Size",txtSz_d,iChTxt_d,"size_text_val"..k_sufd);
            local iRYMax_d=actRY_d+itmLstOffY_d+(i-1)*itmHg_d; window.contentMaxY=math.max(window.contentMaxY,iRYMax_d+itmHg_d-mainAreaPos_d.y+actRY_d);
            local iBgColSet_d=bgC_d; local iTxtColSetCur_d=txtC_d; local isMOItm_d=IsWithinRegion(self.mousePosition,iBgOb_d);
            if isMOItm_d then elData_d.currentHoveredItemIndex=i; iBgColSet_d=itmHovBgC_d; if not self.uiClickConsumedThisFrame and mJP_d then elData_d.selectedItem=iDt_d; if elData_d.onItemSelected then local cb=elData_d.onItemSelected;local itmCall=iDt_d;spawn(function()pcall(cb,itmCall);wait(0.1);end);end;elData_d.isOpen=false;self.activeDropdownId=nil;self:_SetPropertyIfChanged(obMBB_d,"Color",olC_d,elData_d.optionsCache,bdColKey_d);self:_SetPropertyIfChanged(obCT_d,"Text",tostring(elData_d.selectedItem),elData_d.optionsCache,"obCurrentText_text_val"..k_sufd);self.uiClickConsumedThisFrame=true;end;end
            if iDt_d==elData_d.selectedItem then iTxtColSetCur_d=selItmTxtC_d; end
            self:_SetPropertyIfChanged(iBgOb_d,"Color",iBgColSet_d,iChBg_d,"color_val"..k_sufd); self:_SetPropertyIfChanged(iTxtOb_d,"Color",iTxtColSetCur_d,iChTxt_d,"color_text_val"..k_sufd);
        end;end
    if isAuto_d then window.nextElementY=actRY_d+hg_d+window.padding;end; local curElBotY_d=actRY_d+hg_d;
    if elData_d.isOpen and elData_d.items and #elData_d.items>0 then curElBotY_d=actRY_d+hg_d+(#elData_d.items*itmHg_d);end
    window.contentMaxY=math.max(window.contentMaxY,curElBotY_d);
    window.currentElementIndex=window.currentElementIndex+1; return elData_d;
end

function UIHelper:MultiDropdown(labelText, options)
    if not self.currentWindowId then print("UIHelper Err: MultiDropdown() outside Begin/End"); return nil; end
    local window = self.windows[self.currentWindowId]; if not window then print("UIHelper Err: MultiDropdown() no window"); return nil; end
    local k_sufm = "_mdd"; options = options or {}; local items_m = options.items or {}; 
    local curDefSel_m = options.defaultSelectedItems or {}; local onSelChgCb_m = options.onSelectionChanged;
    local clrs_m = options.colors or {}; local bgC_m=clrs_m.bg or self.defaultDropdownBgColor; 
    local olC_m=clrs_m.outline or self.defaultDropdownOutlineColor; local opOlC_m=clrs_m.openOutline or self.defaultDropdownOpenOutlineColor;
    local txtC_m=clrs_m.text or self.defaultDropdownTextColor; local arrC_m=clrs_m.arrow or self.defaultDropdownArrowColor;
    local itmHovBgC_m=clrs_m.itemHoverBg or self.defaultDropdownItemHoverBgColor; local selItmTxtC_m=clrs_m.selectedItemText or self.defaultDropdownSelectedItemTextColor;
    local rXm=options.x; local rYm=options.y; local wd_m=options.width or 150; local hg_m=options.height or 20;
    local itmHg_m=options.itemHeight or hg_m; local txtSz_m=options.textSize or 10; local arrSz_m=math.floor(hg_m*0.4);
    local mainAreaPos_m=RetOB(window.mainAreaOB,"Position"); if not mainAreaPos_m then print("UIHelper Warn: MultiDropdown() no mainAreaPos"); return nil; end
    local actRX_m, actRY_m; local isAuto_m=(rXm==nil and rYm==nil);
    if isAuto_m then actRX_m=window.currentLayoutX; actRY_m=window.nextElementY; else actRX_m=rXm or window.currentLayoutX; actRY_m=rYm or window.nextElementY; end
    local elData_m, obMB_m, obMBB_m, obCT_m, obArr_m;
    if window.currentElementIndex<=#window.elements and window.elements[window.currentElementIndex].type=="multidropdown" then
        elData_m=window.elements[window.currentElementIndex]; obMB_m=elData_m.obMainBox; obMBB_m=elData_m.obMainBoxBorder;
        obCT_m=elData_m.obCurrentText; obArr_m=elData_m.obArrow; elData_m.optionsCache=elData_m.optionsCache or {};
    else obMB_m=CrtOB("Square"); obMBB_m=CrtOB("Square"); obCT_m=CrtOB("Text"); obArr_m=CrtOB("Line");
        elData_m={obMainBox=obMB_m,obMainBoxBorder=obMBB_m,obCurrentText=obCT_m,obArrow=obArr_m,type="multidropdown",
                  items=items_m,selectedItems={},isOpen=false,onSelectionChanged=onSelChgCb_m,itemHeight=itmHg_m,
                  colors=clrs_m,itemOBs={},currentHoveredItemIndex=-1,optionsCache={}};
        for _,itm in ipairs(curDefSel_m)do table.insert(elData_m.selectedItems,itm);end; window.elements[window.currentElementIndex]=elData_m;
    end
    self:_SetPropertyIfChanged(obMB_m,"Visible",true,elData_m.optionsCache,"obMainBox_visible"..k_sufm);
    self:_SetPropertyIfChanged(obMBB_m,"Visible",true,elData_m.optionsCache,"obMainBoxBorder_visible"..k_sufm);
    self:_SetPropertyIfChanged(obCT_m,"Visible",true,elData_m.optionsCache,"obCurrentText_visible"..k_sufm);
    self:_SetPropertyIfChanged(obArr_m,"Visible",true,elData_m.optionsCache,"obArrow_visible"..k_sufm);
    elData_m.items=items_m; elData_m.onSelectionChanged=onSelChgCb_m; elData_m.colors=clrs_m; elData_m.itemHeight=itmHg_m;
    local defChg_m=false; if #curDefSel_m~=#(elData_m.optionsCache.defaultSelectedItems_arg or{})then defChg_m=true;else for i,itm in ipairs(curDefSel_m)do if itm~=(elData_m.optionsCache.defaultSelectedItems_arg or{})[i]then defChg_m=true;break;end;end;end
    if defChg_m then elData_m.selectedItems={};for _,itm in ipairs(curDefSel_m)do table.insert(elData_m.selectedItems,itm);end; elData_m.optionsCache.defaultSelectedItems_arg={};for _,itm in ipairs(curDefSel_m)do table.insert(elData_m.optionsCache.defaultSelectedItems_arg,itm);end;end
    elData_m.originalRelX=actRX_m; elData_m.originalRelY=actRY_m; elData_m.updatedThisFrame=true;
    local mBPos_m={mainAreaPos_m.x+actRX_m,mainAreaPos_m.y+actRY_m};
    self:_SetPropertyIfChanged(obMB_m,"Position",mBPos_m,elData_m.optionsCache,"obMainBox_pos_val"..k_sufm);
    self:_SetPropertyIfChanged(obMB_m,"Size",{wd_m,hg_m},elData_m.optionsCache,"obMainBox_size_val"..k_sufm);
    self:_SetPropertyIfChanged(obMB_m,"Color",bgC_m,elData_m.optionsCache,"obMainBox_color_val"..k_sufm);
    self:_SetPropertyIfChanged(obMB_m,"Filled",true,elData_m.optionsCache,"obMainBox_filled_val"..k_sufm);
    self:_SetPropertyIfChanged(obMBB_m,"Position",mBPos_m,elData_m.optionsCache,"obMainBoxBorder_pos_val"..k_sufm);
    self:_SetPropertyIfChanged(obMBB_m,"Size",{wd_m,hg_m},elData_m.optionsCache,"obMainBoxBorder_size_val"..k_sufm);
    self:_SetPropertyIfChanged(obMBB_m,"Filled",false,elData_m.optionsCache,"obMainBoxBorder_filled_val"..k_sufm);
    self:_SetPropertyIfChanged(obMBB_m,"Thickness",1,elData_m.optionsCache,"obMainBoxBorder_thickness_val"..k_sufm);
    local curDspTxt_m=(#elData_m.selectedItems==0)and(labelText or "Select items...")or table.concat(elData_m.selectedItems,", ");
    local curTxtPos_m={mainAreaPos_m.x+actRX_m+5,mainAreaPos_m.y+actRY_m+(hg_m-txtSz_m)/2};
    self:_SetPropertyIfChanged(obCT_m,"Text",curDspTxt_m,elData_m.optionsCache,"obCurrentText_text_val"..k_sufm);
    self:_SetPropertyIfChanged(obCT_m,"Position",curTxtPos_m,elData_m.optionsCache,"obCurrentText_pos_val"..k_sufm);
    self:_SetPropertyIfChanged(obCT_m,"Size",txtSz_m,elData_m.optionsCache,"obCurrentText_size_val"..k_sufm);
    self:_SetPropertyIfChanged(obCT_m,"Color",txtC_m,elData_m.optionsCache,"obCurrentText_color_val"..k_sufm);
    local arrX_m=mainAreaPos_m.x+actRX_m+wd_m-arrSz_m-5; local arrY_m=mainAreaPos_m.y+actRY_m+(hg_m-arrSz_m)/2;
    local arrFr_m,arrTo_m;if elData_m.isOpen then arrFr_m={arrX_m,arrY_m+arrSz_m};arrTo_m={arrX_m+arrSz_m/2,arrY_m};else arrFr_m={arrX_m,arrY_m};arrTo_m={arrX_m+arrSz_m/2,arrY_m+arrSz_m};end
    self:_SetPropertyIfChanged(elData_m.obArrow,"From",arrFr_m,elData_m.optionsCache,"obArrow_from_val"..k_sufm);
    self:_SetPropertyIfChanged(elData_m.obArrow,"To",arrTo_m,elData_m.optionsCache,"obArrow_to_val"..k_sufm);
    self:_SetPropertyIfChanged(elData_m.obArrow,"Color",arrC_m,elData_m.optionsCache,"obArrow_color_val"..k_sufm);
    self:_SetPropertyIfChanged(elData_m.obArrow,"Thickness",2,elData_m.optionsCache,"obArrow_thickness_val"..k_sufm);
    local mJP_m=self.leftCurrentlyPressed and not self.wasLeftPressedLastFrame; local bdColKey_m="obMainBoxBorder_color_val"..k_sufm;
    if not self.uiClickConsumedThisFrame and mJP_m and IsWithinRegion(self.mousePosition,obMB_m)then elData_m.isOpen=not elData_m.isOpen;
        if elData_m.isOpen then if self.activeDropdownId then local oW=self.windows[self.activeDropdownId.windowId]; if oW and oW.elements[self.activeDropdownId.elementIndex]then local oE=oW.elements[self.activeDropdownId.elementIndex]; if oE and(oE.type=="dropdown"or oE.type=="multidropdown")and oE.isOpen then oE.isOpen=false; if oE.obMainBoxBorder and oE.optionsCache and oE.colors then local oKS=(oE.type=="multidropdown")and"_mdd"or"_dd"; self:_SetPropertyIfChanged(oE.obMainBoxBorder,"Color",oE.colors.outline or self.defaultDropdownOutlineColor,oE.optionsCache,"obMainBoxBorder_color_val"..oKS);end;end;end;end; self.activeDropdownId={windowId=window.id,elementIndex=window.currentElementIndex};
        else self.activeDropdownId=nil; end; self.uiClickConsumedThisFrame=true;
    end
    local curBdC_m=elData_m.isOpen and opOlC_m or olC_m;
    self:_SetPropertyIfChanged(obMBB_m,"Color",curBdC_m,elData_m.optionsCache,bdColKey_m);
    for i=1,#elData_m.itemOBs do local iDpy=elData_m.itemOBs[i]; if iDpy then local iShBVis=elData_m.isOpen and(elData_m.items and elData_m.items[i]~=nil); if iDpy.bg and iDpy.cache_bg then self:_SetPropertyIfChanged(iDpy.bg,"Visible",iShBVis,iDpy.cache_bg,"visible_val"..k_sufm);end; if iDpy.text and iDpy.cache_text then self:_SetPropertyIfChanged(iDpy.text,"Visible",iShBVis,iDpy.cache_text,"visible_text_val"..k_sufm);end;end;end
    if elData_m.isOpen then elData_m.currentHoveredItemIndex=-1; local itmLstOffY_m=hg_m;
        while #elData_m.itemOBs<#elData_m.items do table.insert(elData_m.itemOBs,{bg=CrtOB("Square"),text=CrtOB("Text"),cache_bg={},cache_text={}});end
        for i=#elData_m.items+1,#elData_m.itemOBs do local iDpyS=elData_m.itemOBs[i]; if iDpyS.bg and iDpyS.cache_bg then self:_SetPropertyIfChanged(iDpyS.bg,"Visible",false,iDpyS.cache_bg,"visible_val"..k_sufm.."_surplus");end; if iDpyS.text and iDpyS.cache_text then self:_SetPropertyIfChanged(iDpyS.text,"Visible",false,iDpyS.cache_text,"visible_text_val"..k_sufm.."_surplus");end;end
        for i=1,#elData_m.items do local iDt_m=elData_m.items[i]; local iDpy_m=elData_m.itemOBs[i]; local iBgOb_m=iDpy_m.bg; local iTxtOb_m=iDpy_m.text; local iChBg_m=iDpy_m.cache_bg; local iChTxt_m=iDpy_m.cache_text;
            local curItmAbsY_m=mBPos_m.y+itmLstOffY_m+(i-1)*itmHg_m; local iBgPos_m={mBPos_m.x,curItmAbsY_m}; local iTxtPos_m={mBPos_m.x+5,curItmAbsY_m+(itmHg_m-txtSz_m)/2};
            self:_SetPropertyIfChanged(iBgOb_m,"Position",iBgPos_m,iChBg_m,"pos_val"..k_sufm); self:_SetPropertyIfChanged(iBgOb_m,"Size",{wd_m,itmHg_m},iChBg_m,"size_val"..k_sufm); self:_SetPropertyIfChanged(iBgOb_m,"Filled",true,iChBg_m,"filled_val"..k_sufm);
            self:_SetPropertyIfChanged(iTxtOb_m,"Text",tostring(iDt_m),iChTxt_m,"text_val"..k_sufm); self:_SetPropertyIfChanged(iTxtOb_m,"Position",iTxtPos_m,iChTxt_m,"pos_text_val"..k_sufm); self:_SetPropertyIfChanged(iTxtOb_m,"Size",txtSz_m,iChTxt_m,"size_text_val"..k_sufm);
            local iRYMax_m=actRY_m+itmLstOffY_m+(i-1)*itmHg_m; window.contentMaxY=math.max(window.contentMaxY,iRYMax_m+itmHg_m-mainAreaPos_m.y+actRY_m);
            local isItmSel_m=false;for _,sel in ipairs(elData_m.selectedItems)do if sel==iDt_m then isItmSel_m=true;break;end;end;
            local iBgColSet_m=bgC_m; local iTxtColSetCur_m=txtC_m; local isMOItm_m=IsWithinRegion(self.mousePosition,iBgOb_m);
            if isMOItm_m then elData_m.currentHoveredItemIndex=i; iBgColSet_m=itmHovBgC_m; if not self.uiClickConsumedThisFrame and mJP_m then local prevSel=isItmSel_m; if prevSel then for k,v in ipairs(elData_m.selectedItems)do if v==iDt_m then table.remove(elData_m.selectedItems,k);break;end;end; else table.insert(elData_m.selectedItems,iDt_m);end;isItmSel_m=not prevSel; if elData_m.onSelectionChanged then local cb=elData_m.onSelectionChanged;local curSelCp={};for _,sItm in ipairs(elData_m.selectedItems)do table.insert(curSelCp,sItm);end;spawn(function()pcall(cb,curSelCp);wait(0.1);end);end; local newDspTxt_m=(#elData_m.selectedItems==0)and(labelText or "Select items...")or table.concat(elData_m.selectedItems,", "); self:_SetPropertyIfChanged(obCT_m,"Text",newDspTxt_m,elData_m.optionsCache,"obCurrentText_text_val"..k_sufm);self.uiClickConsumedThisFrame=true;end;end
            if isItmSel_m then iTxtColSetCur_m=selItmTxtC_m;end; if isMOItm_m then iBgColSet_m=itmHovBgC_m;end
            self:_SetPropertyIfChanged(iBgOb_m,"Color",iBgColSet_m,iChBg_m,"color_val"..k_sufm); self:_SetPropertyIfChanged(iTxtOb_m,"Color",iTxtColSetCur_m,iChTxt_m,"color_text_val"..k_sufm);
        end;end
    if isAuto_m then window.nextElementY=actRY_m+hg_m+window.padding;end; local curElBotY_m=actRY_m+hg_m;
    if elData_m.isOpen and elData_m.items and #elData_m.items>0 then curElBotY_m=actRY_m+hg_m+(#elData_m.items*itmHg_m);end
    window.contentMaxY=math.max(window.contentMaxY,curElBotY_m);
    window.currentElementIndex=window.currentElementIndex+1; return elData_m;
end

function UIHelper:SetWindowVisible(id, visible)
    local window = self.windows[id]; if not window then return; end
    if window.titleBarOB then self:_SetPropertyIfChanged(window.titleBarOB,"Visible",visible,window.cache,"titleBarVisible");end
    if window.titleTextOB then self:_SetPropertyIfChanged(window.titleTextOB,"Visible",visible,window.cache,"titleTextVisible");end
    if window.mainAreaOB then self:_SetPropertyIfChanged(window.mainAreaOB,"Visible",visible,window.cache,"mainAreaVisible");end
    for _,elData in ipairs(window.elements)do if elData and elData.optionsCache then local elC=elData.optionsCache; local typ=elData.type;
        if typ=="text"then if elData.ob then self:_SetPropertyIfChanged(elData.ob,"Visible",visible,elC,"visible");end
        elseif typ=="square"then if elData.ob then self:_SetPropertyIfChanged(elData.ob,"Visible",visible,elC,"square_visible");end
        elseif typ=="toggle"then if elData.obOuter then self:_SetPropertyIfChanged(elData.obOuter,"Visible",visible,elC,"obOuter_visible");end;if elData.obInner then self:_SetPropertyIfChanged(elData.obInner,"Visible",visible,elC,"obInner_visible");end;if elData.obText then self:_SetPropertyIfChanged(elData.obText,"Visible",visible,elC,"obText_visible");end
        elseif typ=="button"then local ksB="_btn"; if elData.obButtonBg then self:_SetPropertyIfChanged(elData.obButtonBg,"Visible",visible,elC,"obButtonBg_visible"..ksB);end;if elData.obButtonText then self:_SetPropertyIfChanged(elData.obButtonText,"Visible",visible,elC,"obButtonText_visible"..ksB);end;if not visible then elData.isPotentiallyClicking=false;end
        elseif typ=="inputbox"then local ksI="_inp"; if elData.obInputBg then self:_SetPropertyIfChanged(elData.obInputBg,"Visible",visible,elC,"obInputBg_visible"..ksI);end;if elData.obOutline then self:_SetPropertyIfChanged(elData.obOutline,"Visible",visible,elC,"obOutline_visible"..ksI);end;if elData.obInputText then self:_SetPropertyIfChanged(elData.obInputText,"Visible",visible,elC,"obInputText_visible"..ksI);end; local csrSVB=visible and elData.isFocused and elData.cursorBlinkOn; if elData.obCursor then self:_SetPropertyIfChanged(elData.obCursor,"Visible",csrSVB,elC,"obCursor_visible_val"..ksI);end; if not visible and elData.isFocused then elData.isFocused=false; if self.activeInputBoxId and self.activeInputBoxId.windowId==id and self.windows[id]and self.windows[id].elements[self.activeInputBoxId.elementIndex]==elData then self.activeInputBoxId=nil;end;end
        elseif typ=="dropdown"or typ=="multidropdown"then local ksD=(typ=="multidropdown")and"_mdd"or"_dd";local bdColKeyD="obMainBoxBorder_color_val"..ksD;
            if elData.obMainBox then self:_SetPropertyIfChanged(elData.obMainBox,"Visible",visible,elC,"obMainBox_visible"..ksD);end
            if elData.obMainBoxBorder then self:_SetPropertyIfChanged(elData.obMainBoxBorder,"Visible",visible,elC,"obMainBoxBorder_visible"..ksD);end
            if elData.obCurrentText then self:_SetPropertyIfChanged(elData.obCurrentText,"Visible",visible,elC,"obCurrentText_visible"..ksD);end
            if elData.obArrow then self:_SetPropertyIfChanged(elData.obArrow,"Visible",visible,elC,"obArrow_visible"..ksD);end
            local itmsShBVis=visible and elData.isOpen; if elData.itemOBs then for itmIdx,itmDsp in ipairs(elData.itemOBs)do local curItmVisSt=itmsShBVis and(elData.items and elData.items[itmIdx]~=nil); if itmDsp.bg and itmDsp.cache_bg then self:_SetPropertyIfChanged(itmDsp.bg,"Visible",curItmVisSt,itmDsp.cache_bg,"visible_val"..ksD);end;if itmDsp.text and itmDsp.cache_text then self:_SetPropertyIfChanged(itmDsp.text,"Visible",curItmVisSt,itmDsp.cache_text,"visible_text_val"..ksD);end;end;end
            if not visible then elData.isOpen=false; if elData.obMainBoxBorder and elData.colors then self:_SetPropertyIfChanged(elData.obMainBoxBorder,"Color",elData.colors.outline or self.defaultDropdownOutlineColor,elC,bdColKeyD);end
            else if elData.obMainBoxBorder and elData.colors then local curOlC=elData.isOpen and(elData.colors.openOutline or self.defaultDropdownOpenOutlineColor)or(elData.colors.outline or self.defaultDropdownOutlineColor); self:_SetPropertyIfChanged(elData.obMainBoxBorder,"Color",curOlC,elC,bdColKeyD);end;end
        end;end;end
    if not visible and self.activeDropdownId and self.activeDropdownId.windowId==id then self.activeDropdownId=nil;end
end

function UIHelper:Run(userRenderFunction)
    if not self.mouseService then print("UIHelper Err: MouseService N/A"); return; end
    if type(userRenderFunction) ~= "function" then print("UIHelper Err: Run needs func arg"); return; end
    spawn(function() while true do 
        local mP=getmouselocation(self.mouseService); local lP=isleftpressed();
        self:UpdateInputState(mP.x,mP.y,lP); self:BeginFrame();
        local s,e=pcall(userRenderFunction); if not s then print("UIHelper Err in userRenderFunc:",e);end        
        self:EndFrame(); wait(0.016); 
    end;end)
end

return UIHelper
--- END OF FILE UIHelper.lua ---
