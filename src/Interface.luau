-- Product UI only. All Instances belong to the plugin widget, never the place.
local Interface = {}
function Interface.new(widget)
    local U={busy=false,disposed=false,pages={},tabs={},order={}}
    local C={bg=Color3.fromRGB(20,25,34),card=Color3.fromRGB(33,41,55),
        text=Color3.fromRGB(237,243,250),muted=Color3.fromRGB(172,188,207),
        accent=Color3.fromRGB(74,159,226),good=Color3.fromRGB(102,217,169),bad=Color3.fromRGB(255,147,147)}
    local function corner(node)
        local item=Instance.new("UICorner"); item.CornerRadius=UDim.new(0,6); item.Parent=node
    end
    local root=Instance.new("Frame")
    root.Name="RegressionArenaInterface"; root.Size=UDim2.fromScale(1,1)
    root.BackgroundColor3=C.bg; root.BorderSizePixel=0; root.Parent=widget
    local title=Instance.new("TextLabel")
    title.BackgroundTransparency=1; title.Position=UDim2.fromOffset(12,8)
    title.Size=UDim2.new(1,-24,0,28); title.Font=Enum.Font.GothamBold; title.TextSize=19
    title.TextXAlignment=Enum.TextXAlignment.Left; title.TextColor3=C.text
    title.Text="REGRESSION ARENA"; title.Parent=root
    title.TextScaled=true
    local titleLimit=Instance.new("UITextSizeConstraint"); titleLimit.MinTextSize=10; titleLimit.MaxTextSize=19; titleLimit.Parent=title
    local tabs=Instance.new("Frame")
    tabs.BackgroundTransparency=1; tabs.Position=UDim2.fromOffset(8,43); tabs.Size=UDim2.new(1,-16,0,30); tabs.Parent=root
    local status=Instance.new("TextLabel")
    status.BackgroundTransparency=1; status.Position=UDim2.new(0,12,1,-68); status.Size=UDim2.new(1,-24,0,60)
    status.TextXAlignment=Enum.TextXAlignment.Left; status.TextYAlignment=Enum.TextYAlignment.Top
    status.TextWrapped=true; status.Font=Enum.Font.Gotham; status.TextSize=12; status.TextColor3=C.muted; status.Parent=root
    function U:status(message,failed)
        if self.disposed then return end
        status.Text=tostring(message):sub(1,512); status.TextColor3=failed and C.bad or C.muted
    end
    function U:show(name)
        for key,page in pairs(self.pages) do page.Visible=key==name end
        for key,tab in pairs(self.tabs) do tab.BackgroundColor3=key==name and C.accent or C.card end
    end
    for i,name in ipairs({"Snapshot","Smoke","Setup","Results"}) do
        local page=Instance.new("ScrollingFrame")
        page.Name=name; page.Position=UDim2.fromOffset(12,84); page.Size=UDim2.new(1,-24,1,-160)
        page.BackgroundTransparency=1; page.BorderSizePixel=0; page.ScrollBarThickness=5
        page.CanvasSize=UDim2.new(); page.AutomaticCanvasSize=Enum.AutomaticSize.Y
        page.ScrollingDirection=Enum.ScrollingDirection.Y; page.Parent=root
        local pad=Instance.new("UIPadding"); pad.PaddingRight=UDim.new(0,8); pad.PaddingBottom=UDim.new(0,12); pad.Parent=page
        local list=Instance.new("UIListLayout"); list.Padding=UDim.new(0,8); list.SortOrder=Enum.SortOrder.LayoutOrder; list.Parent=page
        U.pages[name]=page
        local tab=Instance.new("TextButton")
        tab.Name=name.."Tab"; tab.Position=UDim2.new((i-1)/4,2,0,0); tab.Size=UDim2.new(0.25,-4,1,0)
        tab.BackgroundColor3=C.card; tab.TextColor3=C.text; tab.Font=Enum.Font.GothamBold; tab.TextSize=12
        tab.Text=name; tab.BorderSizePixel=0; corner(tab); tab.Parent=tabs
        tab.TextScaled=true
        local limit=Instance.new("UITextSizeConstraint"); limit.MinTextSize=9; limit.MaxTextSize=12; limit.Parent=tab
        U.tabs[name]=tab
        tab.MouseButton1Click:Connect(function() if not U.disposed then U:show(name) end end)
    end
    local function place(page,item,height)
        U.order[page]=(U.order[page] or 0)+1; item.LayoutOrder=U.order[page]
        item.Size=UDim2.new(1,0,0,height); item.Parent=page; return item
    end
    function U:label(page,text,height,heading)
        local item=Instance.new("TextLabel")
        item.BackgroundTransparency=1; item.TextColor3=C.text; item.TextWrapped=true
        item.TextXAlignment=Enum.TextXAlignment.Left; item.TextYAlignment=Enum.TextYAlignment.Top
        item.Font=heading and Enum.Font.GothamBold or Enum.Font.Gotham; item.TextSize=heading and 17 or 12
        item.Text=text; item.AutomaticSize=Enum.AutomaticSize.Y
        return place(page,item,heading and 26 or 0)
    end
    function U:button(page,text,callback,primary,always)
        local item=Instance.new("TextButton")
        item.Name=text; item.BackgroundColor3=primary and C.accent or C.card; item.BorderSizePixel=0
        item.TextColor3=C.text; item.TextSize=13; item.TextWrapped=true; item.Font=Enum.Font.GothamBold; item.Text=text
        item.AutomaticSize=Enum.AutomaticSize.Y
        item:SetAttribute("RAAction",not always); corner(item); place(page,item,34)
        item.MouseButton1Click:Connect(function()
            if U.disposed or (U.busy and not always) then return end
            local ok,err=pcall(callback)
            if not ok then warn("Regression Arena action failed:",err); U:status("Action failed. Check Studio Output. "..tostring(err):sub(1,180),true) end
        end)
        return item
    end
    function U:input(page,label,value,multiline)
        self:label(page,label,18)
        local item=Instance.new("TextBox")
        item.Name=label; item.BackgroundColor3=C.card; item.BorderSizePixel=0; item.TextColor3=C.text
        item.Font=Enum.Font.Code; item.TextSize=13; item.ClearTextOnFocus=false; item.Text=value or ""
        item.TextXAlignment=Enum.TextXAlignment.Left
        item.TextYAlignment=multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
        local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,8); pad.PaddingRight=UDim.new(0,8)
        pad.PaddingTop=UDim.new(0,multiline and 6 or 0); pad.Parent=item
        item.MultiLine=multiline==true; item.TextWrapped=multiline==true; item:SetAttribute("RAInput",true)
        corner(item); return place(page,item,multiline and 80 or 30)
    end
    function U:group(page)
        local item=Instance.new("Frame")
        item.BackgroundTransparency=1; item.AutomaticSize=Enum.AutomaticSize.Y
        place(page,item,0)
        local list=Instance.new("UIListLayout")
        list.Padding=UDim.new(0,8); list.SortOrder=Enum.SortOrder.LayoutOrder; list.Parent=item
        return item
    end
    function U:setBusy(value)
        self.busy=value
        for _,node in ipairs(root:GetDescendants()) do
            if node:IsA("TextBox") and node:GetAttribute("RAInput") then node.TextEditable=not value end
            if node:IsA("TextButton") and node:GetAttribute("RAAction") then
                node.AutoButtonColor=not value; node.TextTransparency=value and 0.45 or 0
            end
        end
    end
    local resultPage=U.pages.Results
    U.resultTitle=U:label(resultPage,"No current run",28,true)
    U.resultRows=Instance.new("Frame"); U.resultRows.BackgroundTransparency=1
    U.resultRows.AutomaticSize=Enum.AutomaticSize.Y; place(resultPage,U.resultRows,0)
    local rowsLayout=Instance.new("UIListLayout"); rowsLayout.Padding=UDim.new(0,12); rowsLayout.SortOrder=Enum.SortOrder.LayoutOrder; rowsLayout.Parent=U.resultRows
    U:label(resultPage,"Export JSON: click Select JSON, then Ctrl+C. Paste into a local .json file. No network or clipboard API is used.",62)
    U.json=U:input(resultPage,"Report JSON","No report yet.",true)
    U.json.Size=UDim2.new(1,0,0,220); U.json.TextEditable=false; U.json.TextWrapped=false
    U.json:SetAttribute("RAInput",nil)
    U:button(resultPage,"Select JSON for export",function()
        U.json:CaptureFocus(); U.json.CursorPosition=#U.json.Text+1; U.json.SelectionStart=1
        U:status("JSON selected. Press Ctrl+C and save the pasted text as a local .json file.")
    end)
    function U:results(titleText,rows,json)
        self.resultTitle.Text=titleText
        for _,child in ipairs(self.resultRows:GetChildren()) do if child:IsA("TextLabel") then child:Destroy() end end
        self.order[self.resultRows]=0
        for _,row in ipairs(rows) do
            local item=self:label(self.resultRows,row.text,0)
            item.AutomaticSize=Enum.AutomaticSize.Y
            item.TextColor3=row.passed and C.good or C.bad
        end
        self.json.Text=json; self:show("Results")
    end
    U:show("Snapshot")
    return U
end
return Interface
