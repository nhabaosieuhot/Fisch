-- // Color Scheme \\
local Library = {}
Library.Scheme = {
    ["Accent"] = {125, 85, 255},
    ["Background"] = {20, 20, 20},
    ["Content Background"] = {25, 25, 25},
    ["Dark"] = {0, 0, 0},
    ["Text"] = {255, 255, 255},
    ["Main"] = {30, 30, 30},
    ["Outline"] = {40, 40, 40},
    ["Window Background"] = {13, 13, 13},
    ["Disabled"] = {128, 128, 128}
}

-- // Globals \\
local Last = 0

-- // Library Functions \\
function Library:CreateWindow(WindowInfo)
    -- // Window Construction \\
    local Window = {}
    Window.MainFrame = WindowInfo or {}
    Window.Drawings = {}
    Window.DrawingsMap = {}
    Window.IsValid = true
    Window.MouseService = nil
    
    -- // Tabs System \\
    Window.Tabs = {}
    Window.TabButtons = {}
    Window.ActiveTab = nil
    
    -- // Cursor Setup \\
    local CursorH = Drawing.new("Square")
    CursorH.Visible = false
    CursorH.Color = {255, 255, 255}
    CursorH.Size = {7, 1}
    CursorH.Filled = true
    CursorH.Thickness = 1
    CursorH.zIndex = 999
    Window.CursorH = CursorH

    local CursorHOutline = Drawing.new("Square")
    CursorHOutline.Visible = false
    CursorHOutline.Color = {0, 0, 0}
    CursorHOutline.Size = {9, 3}
    CursorHOutline.Filled = true
    CursorHOutline.Thickness = 1
    CursorHOutline.zIndex = 998
    Window.CursorHOutline = CursorHOutline

    local CursorV = Drawing.new("Square")
    CursorV.Visible = false
    CursorV.Color = {255, 255, 255}
    CursorV.Size = {1, 7}
    CursorV.Filled = true
    CursorV.Thickness = 1
    CursorV.zIndex = 999
    Window.CursorV = CursorV

    local CursorVOutline = Drawing.new("Square")
    CursorVOutline.Visible = false
    CursorVOutline.Color = {0, 0, 0}
    CursorVOutline.Size = {3, 9}
    CursorVOutline.Filled = true
    CursorVOutline.Thickness = 1
    CursorVOutline.zIndex = 998
    Window.CursorVOutline = CursorVOutline

    -- // Window Parameters \\
    local WindowParams = {
        Title = "Default Title",
        Footer = "Default Footer",
        Position = {X = 100, Y = 100},
        Size = {X = 720, Y = 600},
        AutoShow = true,
        Center = false,
        Visible = false,
        ToggleKeybind = "Delete",
        ShowCustomCursor = false
    }
    for Key, Value in pairs(WindowParams) do
        if Window.MainFrame[Key] == nil then
            Window.MainFrame[Key] = Value
        end
    end
    Window.Position = {X = Window.MainFrame.Position.X, Y = Window.MainFrame.Position.Y}
    Window.Size = {
        X = math.max(400, Window.MainFrame.Size.X),
        Y = math.max(300, Window.MainFrame.Size.Y)
    }
    if Window.MainFrame.Center then
        local ScreenDimensions = getscreendimensions()
        Window.Position.X = (ScreenDimensions.x / 2) - (Window.Size.X / 2)
        Window.Position.Y = (ScreenDimensions.y / 2) - (Window.Size.Y / 2)
    end

    -- // Window Methods \\
    function Window:UpdateCursor(MousePosition)
        if not self.IsValid or not MousePosition then
            return
        end
        local X, Y = math.floor(MousePosition.x), math.floor(MousePosition.y)
        self.CursorHOutline.Position = {X - 4, Y - 1}
        self.CursorVOutline.Position = {X - 1, Y - 4}
        self.CursorH.Position = {X - 3, Y}
        self.CursorV.Position = {X, Y - 3}
    end

    function Window:SetCursorVisibility(Visible)
        if not self.IsValid or not self.MainFrame.ShowCustomCursor then
            return
        end
        self.CursorH.Visible = Visible
        self.CursorHOutline.Visible = Visible
        self.CursorV.Visible = Visible
        self.CursorVOutline.Visible = Visible
    end

    -- // Tab System Methods \\
    function Window:CreateTab(TabInfo)
        local Tab = {
            Title = TabInfo.Title or "Tab " .. (#self.Tabs + 1),
            Content = {},
            Button = nil,
            ButtonText = nil,
            Visible = false
        }
        
        table.insert(self.Tabs, Tab)
        
        -- If this is the first tab, make it active
        if #self.Tabs == 1 then
            self.ActiveTab = Tab
            Tab.Visible = true
        end
        
        -- Let's rebuild the tabs display
        self:RebuildTabs()
        
        return Tab
    end
    
    function Window:SelectTab(TabObject)
        if not TabObject then return end
        
        -- Hide all tabs first
        for _, Tab in ipairs(self.Tabs) do
            Tab.Visible = false
            if Tab.Button then
                Tab.Button.Color = Library.Scheme["Main"]
                if Tab.ButtonText then
                    Tab.ButtonText.Color = Library.Scheme["Disabled"]
                end
            end
        end
        
        -- Show the selected tab
        TabObject.Visible = true
        self.ActiveTab = TabObject
        
        -- Update button styles to show active state
        if TabObject.Button then
            TabObject.Button.Color = Library.Scheme["Background"]
            if TabObject.ButtonText then
                TabObject.ButtonText.Color = Library.Scheme["Text"]
            end
        end
        
        -- Update the content display
        self:UpdateTabContent()
    end
    
    function Window:UpdateTabContent()
        if not self.IsValid then return end
        
        -- Hide all tab content
        for _, Tab in ipairs(self.Tabs) do
            for _, Element in ipairs(Tab.Content) do
                if Element.Visible ~= nil then
                    Element.Visible = Tab.Visible
                end
            end
        end
    end

    function Window:RebuildDrawings()
        if not self.IsValid then
            return
        end
        for _, Element in ipairs(self.Drawings) do
            if Element.Remove then
                Element:Remove()
            end
        end
        self.Drawings = {}
        self.DrawingsMap = {}
        local ZIndex = 1
        local function GetNextZIndex()
            ZIndex = ZIndex + 1
            return ZIndex
        end

        local Position = self.Position
        local Size = self.Size

        local FrameOuterX = Position.X
        local FrameOuterY = Position.Y
        local FrameOuterWidth = Size.X
        local FrameOuterHeight = Size.Y

        local FrameOutlineX = FrameOuterX + 1
        local FrameOutlineY = FrameOuterY + 1
        local FrameOutlineWidth = FrameOuterWidth - 2
        local FrameOutlineHeight = FrameOuterHeight - 2

        local MainBGX = FrameOutlineX + 1
        local MainBGY = FrameOutlineY + 1
        local MainBGWidth = FrameOutlineWidth - 2
        local MainBGHeight = FrameOutlineHeight - 2

        local SidePanelWidth = math.floor(MainBGWidth * 0.3)
        local ContentPanelX = MainBGX + SidePanelWidth + 1
        local ContentPanelWidth = MainBGWidth - SidePanelWidth - 1

        local PanelsCommonY = MainBGY + 40 - 40.5
        local PanelsCommonHeight = MainBGHeight - 40 - 20 - 2

        self.TopBarDragArea = {X = MainBGX, Y = MainBGY, Width = MainBGWidth, Height = 40}

        self.ResizeArea = {
            X = MainBGX + MainBGWidth - 15,
            Y = MainBGY + MainBGHeight - 15,
            Width = 15,
            Height = 15
        }

        local function AddDrawing(Obj, Ref)
            table.insert(self.Drawings, Obj)
            if Ref then
                self.DrawingsMap[Ref] = Obj
            end
        end

        local DarkBorder = Drawing.new("Square")
        DarkBorder.Position = {FrameOuterX, FrameOuterY}
        DarkBorder.Size = {FrameOuterWidth, FrameOuterHeight}
        DarkBorder.Color = Library.Scheme["Dark"]
        DarkBorder.Filled = true
        DarkBorder.zIndex = GetNextZIndex()
        AddDrawing(DarkBorder, "DarkBorder")

        local Outline = Drawing.new("Square")
        Outline.Position = {FrameOutlineX, FrameOutlineY}
        Outline.Size = {FrameOutlineWidth, FrameOutlineHeight}
        Outline.Color = Library.Scheme["Outline"]
        Outline.Filled = true
        Outline.zIndex = GetNextZIndex()
        AddDrawing(Outline, "Outline")

        local MainBackground = Drawing.new("Square")
        MainBackground.Position = {MainBGX, MainBGY}
        MainBackground.Size = {MainBGWidth, MainBGHeight}
        MainBackground.Color = Library.Scheme["Window Background"]
        MainBackground.Filled = true
        MainBackground.zIndex = GetNextZIndex()
        AddDrawing(MainBackground, "MainBackground")

        local SidePanelBG = Drawing.new("Square")
        SidePanelBG.Position = {MainBGX, PanelsCommonY}
        SidePanelBG.Size = {SidePanelWidth, PanelsCommonHeight + 41}
        SidePanelBG.Color = Library.Scheme["Background"]
        SidePanelBG.Filled = true
        SidePanelBG.zIndex = GetNextZIndex()
        AddDrawing(SidePanelBG, "SidePanelBG")

        local ContentPanelBG = Drawing.new("Square")
        ContentPanelBG.Position = {ContentPanelX, PanelsCommonY}
        ContentPanelBG.Size = {ContentPanelWidth, PanelsCommonHeight + 41}
        ContentPanelBG.Color = Library.Scheme["Content Background"]
        ContentPanelBG.Filled = true
        ContentPanelBG.zIndex = GetNextZIndex()
        AddDrawing(ContentPanelBG, "ContentPanelBG")

        local TopBarSeparator = Drawing.new("Line")
        TopBarSeparator.From = {MainBGX, MainBGY + 40}
        TopBarSeparator.To = {MainBGX + MainBGWidth, MainBGY + 40}
        TopBarSeparator.Color = Library.Scheme["Outline"]
        TopBarSeparator.Thickness = 1
        TopBarSeparator.zIndex = GetNextZIndex()
        AddDrawing(TopBarSeparator, "TopBarSeparator")

        local VerticalSeparator = Drawing.new("Line")
        VerticalSeparator.From = {MainBGX + SidePanelWidth, MainBGY + 40 - 40.5}
        VerticalSeparator.To = {MainBGX + SidePanelWidth, MainBGY + MainBGHeight - 20 - 0.6}
        VerticalSeparator.Color = Library.Scheme["Outline"]
        VerticalSeparator.Thickness = 1
        VerticalSeparator.zIndex = GetNextZIndex()
        AddDrawing(VerticalSeparator, "VerticalSeparator")

        local FooterSeparator = Drawing.new("Line")
        FooterSeparator.From = {MainBGX, MainBGY + MainBGHeight - 20 - 0.6}
        FooterSeparator.To = {MainBGX + MainBGWidth, MainBGY + MainBGHeight - 20 - 0.6}
        FooterSeparator.Color = Library.Scheme["Outline"]
        FooterSeparator.Thickness = 1
        FooterSeparator.zIndex = GetNextZIndex()
        AddDrawing(FooterSeparator, "FooterSeparator")

        local TopBarX = MainBGX + 10

        local TitleDrawing = Drawing.new("Text")
        TitleDrawing.Text = self.MainFrame.Title
        TitleDrawing.Font = 5
        TitleDrawing.Size = 22
        TitleDrawing.Color = Library.Scheme["Text"]
        TitleDrawing.Center = true
        TitleDrawing.Position = {MainBGX + (SidePanelWidth / 2), MainBGY + (40 / 2) - (22 / 2) - 2}
        TitleDrawing.zIndex = GetNextZIndex()
        AddDrawing(TitleDrawing, "TitleDrawing")

        local SearchAreaStartX = MainBGX + SidePanelWidth + 1 + 10
        local SearchBoxPaddingVertical = (40 - 26) / 2
        local SearchAreaWidth = MainBGWidth - SidePanelWidth - 1 - (10 * 2)
        local SearchBoxY = MainBGY + SearchBoxPaddingVertical

        local SearchBoxOutline = Drawing.new("Square")
        SearchBoxOutline.Position = {SearchAreaStartX - 1, SearchBoxY - 1}
        SearchBoxOutline.Size = {SearchAreaWidth + 2, 28}
        SearchBoxOutline.Color = Library.Scheme["Outline"]
        SearchBoxOutline.Filled = true
        SearchBoxOutline.zIndex = GetNextZIndex()
        AddDrawing(SearchBoxOutline, "SearchBoxOutline")

        local SearchBoxBackground = Drawing.new("Square")
        SearchBoxBackground.Position = {SearchAreaStartX, SearchBoxY}
        SearchBoxBackground.Size = {SearchAreaWidth, 26}
        SearchBoxBackground.Color = Library.Scheme["Main"]
        SearchBoxBackground.Filled = true
        SearchBoxBackground.zIndex = GetNextZIndex()
        AddDrawing(SearchBoxBackground, "SearchBoxBackground")

        local SearchPlaceholderText = Drawing.new("Text")
        SearchPlaceholderText.Text = "Search"
        SearchPlaceholderText.Font = 5
        SearchPlaceholderText.Size = 16
        SearchPlaceholderText.Color = Library.Scheme["Disabled"]
        SearchPlaceholderText.Center = true
        SearchPlaceholderText.Position = {SearchAreaStartX + (SearchAreaWidth / 2), SearchBoxY + (26 / 2) - (16 / 2)}
        SearchPlaceholderText.zIndex = GetNextZIndex()
        AddDrawing(SearchPlaceholderText, "SearchPlaceholderText")

        local FooterDrawing = Drawing.new("Text")
        local FooterTextStartX = MainBGX + 10
        local FooterTextAreaWidth = MainBGWidth - (10 * 2)

        FooterDrawing.Text = self.MainFrame.Footer
        FooterDrawing.Font = 5
        FooterDrawing.Size = 12
        FooterDrawing.Color = Library.Scheme["Disabled"]
        FooterDrawing.Center = true
        FooterDrawing.Position = {
            FooterTextStartX + (FooterTextAreaWidth / 2),
            MainBGY + MainBGHeight - 20 + (20 / 2) - (12 / 2.5)
        }
        FooterDrawing.zIndex = GetNextZIndex()
        AddDrawing(FooterDrawing, "FooterDrawing")
        
        -- Store important dimensions for tabs system
        self.SidePanelWidth = SidePanelWidth
        self.SidePanelHeight = PanelsCommonHeight + 41
        self.SidePanelX = MainBGX
        self.SidePanelY = PanelsCommonY
        self.TabHeaderHeight = 30 -- Height for tab buttons at the top of side panel
        
        -- Build tab headers area
        local TabHeaderBG = Drawing.new("Square")
        TabHeaderBG.Position = {MainBGX, PanelsCommonY}
        TabHeaderBG.Size = {SidePanelWidth, self.TabHeaderHeight}
        TabHeaderBG.Color = Library.Scheme["Window Background"] 
        TabHeaderBG.Filled = true
        TabHeaderBG.zIndex = GetNextZIndex()
        AddDrawing(TabHeaderBG, "TabHeaderBG")
        
        local TabHeaderSeparator = Drawing.new("Line")
        TabHeaderSeparator.From = {MainBGX, PanelsCommonY + self.TabHeaderHeight}
        TabHeaderSeparator.To = {MainBGX + SidePanelWidth, PanelsCommonY + self.TabHeaderHeight}
        TabHeaderSeparator.Color = Library.Scheme["Outline"]
        TabHeaderSeparator.Thickness = 1
        TabHeaderSeparator.zIndex = GetNextZIndex()
        AddDrawing(TabHeaderSeparator, "TabHeaderSeparator")

        for _, Element in ipairs(self.Drawings) do
            if Element.Remove then
                Element.Visible = self.MainFrame.Visible
            end
        end

        if self.MainFrame.ShowCustomCursor then
            self:SetCursorVisibility(self.MainFrame.Visible)
        end
        
        -- Rebuild tabs if there are any
        if #self.Tabs > 0 then
            self:RebuildTabs()
        end
    end
    
    -- Function to rebuild tab buttons
    function Window:RebuildTabs()
        -- Clear existing tab buttons
        for _, tabButton in pairs(self.TabButtons) do
            if tabButton.Button and tabButton.Button.Remove then
                tabButton.Button:Remove()
            end
            if tabButton.Text and tabButton.Text.Remove then
                tabButton.Text:Remove()
            end
        end
        self.TabButtons = {}
        
        if #self.Tabs == 0 then return end
        
        local tabWidth = self.SidePanelWidth / #self.Tabs
        
        for i, tab in ipairs(self.Tabs) do
            -- Create tab button
            local tabButton = Drawing.new("Square")
            tabButton.Position = {self.SidePanelX + ((i-1) * tabWidth), self.SidePanelY}
            tabButton.Size = {tabWidth, self.TabHeaderHeight}
            tabButton.Color = tab == self.ActiveTab and Library.Scheme["Background"] or Library.Scheme["Main"]
            tabButton.Filled = true
            tabButton.zIndex = 10
            tabButton.Visible = self.MainFrame.Visible
            table.insert(self.Drawings, tabButton)
            
            -- Create tab text
            local tabText = Drawing.new("Text")
            tabText.Text = tab.Title
            tabText.Font = 5
            tabText.Size = 16
            tabText.Color = tab == self.ActiveTab and Library.Scheme["Text"] or Library.Scheme["Disabled"]
            tabText.Center = true
            tabText.Position = {self.SidePanelX + ((i-1) * tabWidth) + (tabWidth / 2), self.SidePanelY + (self.TabHeaderHeight / 2) - 8}
            tabText.zIndex = 11
            tabText.Visible = self.MainFrame.Visible
            table.insert(self.Drawings, tabText)
            
            -- Store references
            tab.Button = tabButton
            tab.ButtonText = tabText
            
            -- Store in a separate array for easy access
            table.insert(self.TabButtons, {
                Tab = tab,
                Button = tabButton,
                Text = tabText,
                Region = {
                    X = self.SidePanelX + ((i-1) * tabWidth),
                    Y = self.SidePanelY,
                    Width = tabWidth,
                    Height = self.TabHeaderHeight
                }
            })
        end
        
        -- Show active tab content
        self:UpdateTabContent()
    end

    function Window:UpdatePositionsAndSizes()
        if not self.IsValid or not self.DrawingsMap then
            return
        end

        local Position = self.Position
        local Size = self.Size

        local FrameOuterX = Position.X
        local FrameOuterY = Position.Y
        local FrameOuterWidth = Size.X
        local FrameOuterHeight = Size.Y

        local FrameOutlineX = FrameOuterX + 1
        local FrameOutlineY = FrameOuterY + 1
        local FrameOutlineWidth = FrameOuterWidth - 2
        local FrameOutlineHeight = FrameOuterHeight - 2

        local MainBGX = FrameOutlineX + 1
        local MainBGY = FrameOutlineY + 1
        local MainBGWidth = FrameOutlineWidth - 2
        local MainBGHeight = FrameOutlineHeight - 2

        local SidePanelWidth = math.floor(MainBGWidth * 0.3)
        local ContentPanelX = MainBGX + SidePanelWidth + 1
        local ContentPanelWidth = MainBGWidth - SidePanelWidth - 1

        local PanelsCommonY = MainBGY + 40 - 40.5
        local PanelsCommonHeight = MainBGHeight - 40 - 20 - 2

        self.TopBarDragArea = {X = MainBGX, Y = MainBGY, Width = MainBGWidth, Height = 40}

        self.ResizeArea = {
            X = MainBGX + MainBGWidth - 15,
            Y = MainBGY + MainBGHeight - 15,
            Width = 15,
            Height = 15
        }

        if self.DrawingsMap["DarkBorder"] then
            self.DrawingsMap["DarkBorder"].Position = {FrameOuterX, FrameOuterY}
            self.DrawingsMap["DarkBorder"].Size = {FrameOuterWidth, FrameOuterHeight}
        end

        if self.DrawingsMap["Outline"] then
            self.DrawingsMap["Outline"].Position = {FrameOutlineX, FrameOutlineY}
            self.DrawingsMap["Outline"].Size = {FrameOutlineWidth, FrameOutlineHeight}
        end

        if self.DrawingsMap["MainBackground"] then
            self.DrawingsMap["MainBackground"].Position = {MainBGX, MainBGY}
            self.DrawingsMap["MainBackground"].Size = {MainBGWidth, MainBGHeight}
        end

        if self.DrawingsMap["SidePanelBG"] then
            self.DrawingsMap["SidePanelBG"].Position = {MainBGX, PanelsCommonY}
            self.DrawingsMap["SidePanelBG"].Size = {SidePanelWidth, PanelsCommonHeight + 41}
        end

        if self.DrawingsMap["ContentPanelBG"] then
            self.DrawingsMap["ContentPanelBG"].Position = {ContentPanelX, PanelsCommonY}
            self.DrawingsMap["ContentPanelBG"].Size = {ContentPanelWidth, PanelsCommonHeight + 41}
        end

        if self.DrawingsMap["TopBarSeparator"] then
            self.DrawingsMap["TopBarSeparator"].From = {MainBGX, MainBGY + 40}
            self.DrawingsMap["TopBarSeparator"].To = {MainBGX + MainBGWidth, MainBGY + 40}
        end

        if self.DrawingsMap["VerticalSeparator"] then
            self.DrawingsMap["VerticalSeparator"].From = {MainBGX + SidePanelWidth, MainBGY + 40 - 40.5}
            self.DrawingsMap["VerticalSeparator"].To = {MainBGX + SidePanelWidth, MainBGY + MainBGHeight - 20 - 0.6}
        end

        if self.DrawingsMap["FooterSeparator"] then
            self.DrawingsMap["FooterSeparator"].From = {MainBGX, MainBGY + MainBGHeight - 20 - 0.6}
            self.DrawingsMap["FooterSeparator"].To = {MainBGX + MainBGWidth, MainBGY + MainBGHeight - 20 - 0.6}
        end

        local TopBarX = MainBGX + 10

        if self.DrawingsMap["TitleDrawing"] then
            self.DrawingsMap["TitleDrawing"].Position = {
                MainBGX + (SidePanelWidth / 2),
                MainBGY + (40 / 2) - (22 / 2) - 2
            }
        end

        local SearchAreaStartX = MainBGX + SidePanelWidth + 1 + 10
        local SearchBoxPaddingVertical = (40 - 26) / 2
        local SearchAreaWidth = MainBGWidth - SidePanelWidth - 1 - (10 * 2)
        local SearchBoxY = MainBGY + SearchBoxPaddingVertical

        if self.DrawingsMap["SearchBoxOutline"] then
            self.DrawingsMap["SearchBoxOutline"].Position = {SearchAreaStartX - 1, SearchBoxY - 1}
            self.DrawingsMap["SearchBoxOutline"].Size = {SearchAreaWidth + 2, 28}
        end

        if self.DrawingsMap["SearchBoxBackground"] then
            self.DrawingsMap["SearchBoxBackground"].Position = {SearchAreaStartX, SearchBoxY}
            self.DrawingsMap["SearchBoxBackground"].Size = {SearchAreaWidth, 26}
        end

        if self.DrawingsMap["SearchPlaceholderText"] then
            self.DrawingsMap["SearchPlaceholderText"].Position = {
                SearchAreaStartX + (SearchAreaWidth / 2),
                SearchBoxY + (26 / 2) - (16 / 2)
            }
        end

        if self.DrawingsMap["FooterDrawing"] then
            local FooterTextStartX = MainBGX + 10
            local FooterTextAreaWidth = MainBGWidth - (10 * 2)
            self.DrawingsMap["FooterDrawing"].Position = {
                FooterTextStartX + (FooterTextAreaWidth / 2),
                MainBGY + MainBGHeight - 20 + (20 / 2) - (12 / 2.5)
            }
        }
        
        -- Update tabs header
        if self.DrawingsMap["TabHeaderBG"] then
            self.DrawingsMap["TabHeaderBG"].Position = {MainBGX, PanelsCommonY}
            self.DrawingsMap["TabHeaderBG"].Size = {SidePanelWidth, self.TabHeaderHeight}
        end
        
        if self.DrawingsMap["TabHeaderSeparator"] then
            self.DrawingsMap["TabHeaderSeparator"].From = {MainBGX, PanelsCommonY + self.TabHeaderHeight}
            self.DrawingsMap["TabHeaderSeparator"].To = {MainBGX + SidePanelWidth, PanelsCommonY + self.TabHeaderHeight}
        }
        
        -- Update tab dimensions
        self.SidePanelWidth = SidePanelWidth
        self.SidePanelHeight = PanelsCommonHeight + 41
        self.SidePanelX = MainBGX
        self.SidePanelY = PanelsCommonY
        
        -- Rebuild tabs with new dimensions
        if #self.Tabs > 0 then
            self:RebuildTabs()
        end
    end

    function Window:SetPosition(NewX, NewY)
        if not self.IsValid then
            return
        end

        self.Position = {
            X = NewX or self.Position.X,
            Y = NewY or self.Position.Y
        }

        self:UpdatePositionsAndSizes()
    end

    function Window:SetSize(NewWidth, NewHeight)
        if not self.IsValid then
            return
        end

        local ClampedWidth = math.max(400, NewWidth)
        local ClampedHeight = math.max(300, NewHeight)

        if self.Size.X ~= ClampedWidth or self.Size.Y ~= ClampedHeight then
            self.Size.X = ClampedWidth
            self.Size.Y = ClampedHeight
            self:UpdatePositionsAndSizes()
        end
    end

    function Window:Toggle(State)
        if not self.IsValid then
            return
        end
        if os.clock() - Last < 0.3 then
            return
        end
        Last = os.clock()

        local NewState = type(State) == "boolean" and State or not self.MainFrame.Visible
        self.MainFrame.Visible = NewState

        for _, Element in ipairs(self.Drawings) do
            if Element.Remove then
                Element.Visible = NewState
            end
        end

        if self.MainFrame.ShowCustomCursor then
            self:SetCursorVisibility(true)
        end
    end

    function Window:SetTitle(NewTitle)
        if not self.IsValid then
            return
        end

        self.MainFrame.Title = NewTitle
        if self.DrawingsMap["TitleDrawing"] then
            self.DrawingsMap["TitleDrawing"].Text = NewTitle
        else
            self:RebuildDrawings()
        end
    end

    function Window:SetFooter(NewFooter)
        if not self.IsValid then
            return
        end

        self.MainFrame.Footer = NewFooter
        if self.DrawingsMap["FooterDrawing"] then
            self.DrawingsMap["FooterDrawing"].Text = NewFooter
        else
            self:RebuildDrawings()
        end
    end

    function Window:CheckToggleKeybind()
        if not self.IsValid then
            return
        end
        local Last = 0
        local Time = os.clock()
        if Time - Last < 0 then
            return
        end
        Last = Time
        if not isrbxactive() then
            return
        end

        local Keys = getpressedkeys()
        if Keys then
            for _, Key in ipairs(Keys) do
                if Key == self.MainFrame.ToggleKeybind then
                    self:Toggle()
                    return
                end
            end
        end
    end

    function Window:Update()
        if not self.IsValid then
            return
        end

        if not self.MouseService then
            self.MouseService = findservice(Game, "MouseService")
            if not self.MouseService then
                return
            end
        end

        self:CheckToggleKeybind()

        local MousePosition = getmouselocation(self.MouseService)
        if not MousePosition then
            self.IsResizing = false
            self.DragStartMouse = nil
            self.DragStartWindowSize = nil
            self.IsDragging = false
            self.DragStartWindowPos = nil
            return
        end

        if self.MainFrame.ShowCustomCursor then
            self:UpdateCursor(MousePosition)
        end

        if isleftpressed() then
            if not self.IsResizing and not self.IsDragging then
                if
                    self.TopBarDragArea and MousePosition.x >= self.TopBarDragArea.X and
                        MousePosition.x <= self.TopBarDragArea.X + self.TopBarDragArea.Width and
                        MousePosition.y >= self.TopBarDragArea.Y and
                        MousePosition.y <= self.TopBarDragArea.Y + self.TopBarDragArea.Height
                 then
                    self.IsDragging = true
                    self.DragStartMouse = {X = MousePosition.x, Y = MousePosition.y}
                    self.DragStartWindowPos = {X = self.Position.X, Y = self.Position.Y}
                end

                if
                    self.ResizeArea and MousePosition.x >= self.ResizeArea.X and
                        MousePosition.x <= self.ResizeArea.X + self.ResizeArea.Width and
                        MousePosition.y >= self.ResizeArea.Y and
                        MousePosition.y <= self.ResizeArea.Y + self.ResizeArea.Height
                 then
                    self.IsResizing = true
                    self.DragStartMouse = {X = MousePosition.x, Y = MousePosition.y}
                    self.DragStartWindowSize = {X = self.Size.X, Y = self.Size.Y}
                end
                
                -- Check if clicked on any tab buttons
                for _, tabBtn in pairs(self.TabButtons) do
                    if MousePosition.x >= tabBtn.Region.X and
                       MousePosition.x <= tabBtn.Region.X + tabBtn.Region.Width and
                       MousePosition.y >= tabBtn.Region.Y and
                       MousePosition.y <= tabBtn.Region.Y + tabBtn.Region.Height then
                        self:SelectTab(tabBtn.Tab)
                        break
                    end
                end
            elseif self.IsDragging and self.DragStartMouse and self.DragStartWindowPos then
                local DeltaX = MousePosition.x - self.DragStartMouse.X
                local DeltaY = MousePosition.y - self.DragStartMouse.Y
                self:SetPosition(self.DragStartWindowPos.X + DeltaX, self.DragStartWindowPos.Y + DeltaY)
            elseif self.IsResizing and self.DragStartMouse and self.DragStartWindowSize then
                local DeltaX = MousePosition.x - self.DragStartMouse.X
                local DeltaY = MousePosition.y - self.DragStartMouse.Y
                self:SetSize(self.DragStartWindowSize.X + DeltaX, self.DragStartWindowSize.Y + DeltaY)
            end
        else
            self.IsResizing = false
            self.DragStartMouse = nil
            self.DragStartWindowSize = nil
            self.IsDragging = false
            self.DragStartWindowPos = nil
        end
    end

    function Window:Destroy()
        self.IsValid = false

        if self.MainFrame.ShowCustomCursor then
            self.CursorH:Remove()
            self.CursorHOutline:Remove()
            self.CursorV:Remove()
            self.CursorVOutline:Remove()

            if self.MouseService then
                setmouseiconenabled(self.MouseService, true)
            end
        end

        for _, Element in ipairs(self.Drawings) do
            if Element.Remove then
                Element:Remove()
            end
        end

        self.Drawings = {}
        self.DrawingsMap = {}
        self.MainFrame = nil
    end

    Window:RebuildDrawings()

    if Window.MainFrame.ShowCustomCursor then
        if not Window.MouseService then
            Window.MouseService = findservice(Game, "MouseService")
        end

        if Window.MouseService then
            setmouseiconenabled(Window.MouseService, false)
        end

        Window:SetCursorVisibility(true)
    end

    if Window.MainFrame.AutoShow then
        Window:Toggle(true)
    else
        Window:Toggle(false)
    end

    spawn(
        function()
            while Window.IsValid do
                if Window.MainFrame.ShowCustomCursor or Window.MainFrame.Visible then
                    Window:Update()
                else
                    Window:CheckToggleKeybind()
                end
                wait()
            end
        end
    )

    return Window
end

-- // Return \\
return Library
