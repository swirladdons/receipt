local _, LF = ...
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local lsmSoundCache = nil

local function GetSoundList()
    if lsmSoundCache then return lsmSoundCache end
    if not LSM then lsmSoundCache = {}; return lsmSoundCache end
    local raw = LSM:List("sound") or {}
    local sorted = {}
    for i, name in ipairs(raw) do sorted[i] = name end
    table.sort(sorted)
    local deduped = {}
    local seenPaths = {}
    for _, name in ipairs(sorted) do
        local path = LSM:Fetch("sound", name)
        if not path or not seenPaths[path] then
            if path then seenPaths[path] = true end
            deduped[#deduped + 1] = name
        end
    end
    lsmSoundCache = deduped
    return lsmSoundCache
end


local durLabels = { "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary+", "Currency", "Quest", "Gold" }
local durKeys = { "0", "1", "2", "3", "4", "30", "6", "7", "gold" }

local function BuildDisplayCard(C, tab)
    local card = C:CreateCard(tab, "Display")

    local btnRow = CreateFrame("Frame", nil, card)
    btnRow:SetHeight(24)

    local lockBtn
    lockBtn = C:CreateButton(btnRow, LF.anchor:IsMouseEnabled() and "Lock Frame" or "Unlock Frame", {
        width = 120,
        callback = function()
            LF.SetLocked(LF.anchor:IsMouseEnabled())
            lockBtn.label:SetText(LF.anchor:IsMouseEnabled() and "Lock Frame" or "Unlock Frame")
        end,
    })
    lockBtn:SetPoint("TOPLEFT", btnRow, "TOPLEFT", 0, 0)

    local testBtn = C:CreateButton(btnRow, "Test Entry", {
        width = 120,
        callback = function() LF.SpawnTestEntry() end,
    })
    testBtn:SetPoint("LEFT", lockBtn, "RIGHT", 8, 0)
    card:AddWidget(btnRow)

    card:AddWidget(C:CreateSlider(card, "Max Name Length", 10, 60, 1,
        function() return ReceiptDB.maxLength end,
        function(v) ReceiptDB.maxLength = math.floor(v + 0.5) end))

    card:AddWidget(C:CreateToggle(card, "Grow Upward", ReceiptDB.growUp,
        function(v) ReceiptDB.growUp = v; LF.RebuildDisplay() end))

    card:AddWidget(C:CreateToggle(card, "Show Copper / Silver in prices", ReceiptDB.dispCopSilv,
        function(v) ReceiptDB.dispCopSilv = v end))

    tab:AddCard(card)
end

local function BuildDurationsCard(C, tab)
    local card = C:CreateCard(tab, "Durations")

    local selectedDurIdx = 1
    local durSlider

    local function DurOptions()
        local opts = {}
        for i, key in ipairs(durKeys) do
            local secs = ReceiptDB.duration[key] or 0
            opts[i] = { text = durLabels[i] .. " (" .. tostring(secs) .. "s)", value = i }
        end
        return opts
    end

    local durDropdown
    durDropdown = C:CreateDropdown(card, "Quality", DurOptions(), 1, function(val)
        selectedDurIdx = val
        durSlider.label:SetText("Duration: " .. durLabels[val])
        durSlider:SetVal(ReceiptDB.duration[durKeys[val]] or 0)
    end)
    card:AddWidget(durDropdown)

    durSlider = C:CreateSlider(card, "Duration: " .. durLabels[1], 0, 60, 1,
        function() return ReceiptDB.duration[durKeys[selectedDurIdx]] or 0 end,
        function(v)
            ReceiptDB.duration[durKeys[selectedDurIdx]] = math.floor(v + 0.5)
            durDropdown:SetOptions(DurOptions())
        end)
    card:AddWidget(durSlider)

    tab:AddCard(card)
end

local function BuildGainsCard(C, tab, title, enableKey, durKey)
    local card = C:CreateCard(tab, title)

    card:AddEnableToggle("Show " .. title .. " gains", ReceiptDB[enableKey],
        function(v) ReceiptDB[enableKey] = v end)

    local slider = C:CreateSlider(card, "Display duration", 1, 60, 1,
        function() return ReceiptDB[durKey] end,
        function(v) ReceiptDB[durKey] = math.floor(v + 0.5) end)
    card:AddWidget(slider)
    card:SetDependents(slider)

    tab:AddCard(card)
end

local function BuildInvCountCard(C, tab)
    local card = C:CreateCard(tab, "Inventory Count")

    card:AddEnableToggle("Show bag count on items", ReceiptDB.invCount,
        function(v) ReceiptDB.invCount = v end)

    local advToggle = C:CreateToggle(card, "Advanced count (crafted quality tiers)", ReceiptDB.advCount,
        function(v) ReceiptDB.advCount = v end)
    card:AddWidget(advToggle)
    card:SetDependents(advToggle)

    tab:AddCard(card)
end

local function BuildPricingCard(C, tab)
    local card = C:CreateCard(tab, "Pricing")

    card:AddWidget(C:CreateDropdown(card, "Show stack price", {
        { text = "Off", value = 1 },
        { text = "Stack total only", value = 2 },
        { text = "Per-item (hide if qty=1)", value = 3 },
    }, ReceiptDB.showStackPrice, function(v) ReceiptDB.showStackPrice = v end))

    card:AddWidget(C:CreateDropdown(card, "Show AH value", {
        { text = "Off", value = 1 },
        { text = "Per-item", value = 2 },
        { text = "Stack total (if qty > 1)", value = 3 },
    }, ReceiptDB.showAH, function(v) ReceiptDB.showAH = v end))

    card:AddWidget(C:CreateToggle(card, "Show AH value for junk (grey) items", ReceiptDB.showJunkAH,
        function(v) ReceiptDB.showJunkAH = v end))

    card:AddWidget(C:CreateDropdown(card, "Auction addon", {
        { text = "Auctionator", value = 1 },
        { text = "TradeSkillMaster", value = 2 },
    }, ReceiptDB.auctionAddon, function(v) ReceiptDB.auctionAddon = v end))

    card:AddWidget(C:CreateDropdown(card, "TSM data source", {
        { text = "DBMarket", value = 1 },
        { text = "DBMinBuyout", value = 2 },
    }, ReceiptDB.tsmDataSource, function(v) ReceiptDB.tsmDataSource = v end))

    tab:AddCard(card)
end

local function BuildHighlightCard(C, tab)
    local card = C:CreateCard(tab, "Highlight Expensive Items")

    card:AddEnableToggle("Highlight expensive items (glow)", ReceiptDB.highlightExpensive,
        function(v) ReceiptDB.highlightExpensive = v; LF.RebuildDisplay() end)

    local dependents = {}

    local soundToggle = C:CreateToggle(card, "Play sound when highlighted", ReceiptDB.highlightExpensiveSound,
        function(v) ReceiptDB.highlightExpensiveSound = v end)
    card:AddWidget(soundToggle)
    dependents[#dependents + 1] = soundToggle

    local sounds = GetSoundList()
    if #sounds > 0 then
        local opts = {}
        for i, name in ipairs(sounds) do opts[i] = { text = name, value = name } end
        local soundDD = C:CreateDropdown(card, "Alert sound", opts, ReceiptDB.highlightSoundName, function(v)
            ReceiptDB.highlightSoundName = v
            local path = LSM and LSM:Fetch("sound", v) or v
            if path then PlaySoundFile(path, "Master") end
        end)
        card:AddWidget(soundDD)
        dependents[#dependents + 1] = soundDD
    end

    local unitDD = C:CreateDropdown(card, "Price threshold unit", {
        { text = "Copper", value = 1 },
        { text = "Silver", value = 2 },
        { text = "Gold", value = 3 },
    }, ReceiptDB.highlightUnit, function(v) ReceiptDB.highlightUnit = v end)
    card:AddWidget(unitDD)
    dependents[#dependents + 1] = unitDD

    local threshSlider = C:CreateSlider(card, "Threshold value", 0, 10000, 1,
        function() return ReceiptDB.highlightThreshold end,
        function(v) ReceiptDB.highlightThreshold = math.floor(v + 0.5) end)
    card:AddWidget(threshSlider)
    dependents[#dependents + 1] = threshSlider

    card:SetDependents(unpack(dependents))

    tab:AddCard(card)
end

local typeLabels = { "Item", "Currency", "Faction" }

local function BuildBlacklistCard(C, tab)
    local card = C:CreateCard(tab, "Blacklist")

    local selectedIdx = 1
    local entryDD, typeDD, idEB, nameEB

    local function EntryOptions()
        local opts = {}
        for i, v in ipairs(ReceiptDB.blacklist) do
            local name = (v.name and v.name ~= "") and v.name or ("id:" .. tostring(v.itemID or "?"))
            opts[i] = { text = (typeLabels[v.type] or "?") .. " · " .. name, value = i }
        end
        if #opts == 0 then
            opts[1] = { text = "(none)", value = 1 }
        end
        return opts
    end

    local function RefreshEditFields()
        local v = ReceiptDB.blacklist[selectedIdx]
        typeDD:SetValue(v and v.type or 1, true)
        idEB:SetValue(v and tostring(v.itemID or 0) or "")
        nameEB:SetValue(v and (v.name or "") or "")
    end

    local function RefreshEntryList()
        entryDD:SetOptions(EntryOptions())
        entryDD:SetValue(selectedIdx, true)
    end

    entryDD = C:CreateDropdown(card, "Blacklisted entries", EntryOptions(), 1, function(val)
        selectedIdx = val
        RefreshEditFields()
    end)
    card:AddWidget(entryDD)

    local btnRow = CreateFrame("Frame", nil, card)
    btnRow:SetHeight(24)

    local addBtn = C:CreateButton(btnRow, "Add", {
        width = 100,
        callback = function()
            table.insert(ReceiptDB.blacklist, { type = 1, itemID = 0, name = "" })
            selectedIdx = #ReceiptDB.blacklist
            RefreshEntryList()
            RefreshEditFields()
        end,
    })
    addBtn:SetPoint("TOPLEFT", btnRow, "TOPLEFT", 0, 0)

    local delBtn = C:CreateButton(btnRow, "Delete", {
        width = 100,
        callback = function()
            local bl = ReceiptDB.blacklist
            if #bl == 0 then return end
            table.remove(bl, selectedIdx)
            selectedIdx = math.max(1, math.min(selectedIdx, #bl))
            LF.LoadBlacklist()
            RefreshEntryList()
            RefreshEditFields()
        end,
    })
    delBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
    card:AddWidget(btnRow)

    typeDD = C:CreateDropdown(card, "Type", {
        { text = "Item", value = 1 },
        { text = "Currency", value = 2 },
        { text = "Faction", value = 3 },
    }, 1, function(val)
        local v = ReceiptDB.blacklist[selectedIdx]
        if v then
            v.type = val
            LF.LoadBlacklist()
            RefreshEntryList()
        end
    end)
    card:AddWidget(typeDD)

    idEB = C:CreateEditBox(card, "Item ID", "", function(text)
        local v = ReceiptDB.blacklist[selectedIdx]
        if v then
            v.itemID = tonumber(text) or 0
            LF.LoadBlacklist()
            RefreshEntryList()
        end
    end)
    card:AddWidget(idEB)

    nameEB = C:CreateEditBox(card, "Name", "", function(text)
        local v = ReceiptDB.blacklist[selectedIdx]
        if v then
            v.name = text
            LF.LoadBlacklist()
            RefreshEntryList()
        end
    end)
    card:AddWidget(nameEB)

    RefreshEditFields()

    tab:AddCard(card)
end

local function BuildSettings(content)
    local C = SwirlUI.Components
    local tab = C:CreateTabScroller(content)

    BuildDisplayCard(C, tab)
    BuildDurationsCard(C, tab)
    BuildGainsCard(C, tab, "Reputation", "showRep", "rep")
    BuildGainsCard(C, tab, "Honor", "showHonor", "honor")
    BuildInvCountCard(C, tab)
    BuildPricingCard(C, tab)
    BuildHighlightCard(C, tab)
    BuildBlacklistCard(C, tab)

    tab:Commit()
end

function LF.RegisterSettings()
    if not SwirlUI_AddTab then return end
    local built = false
    SwirlUI_AddTab("Receipt", "Receipt", function(content)
        if built then return end
        built = true
        BuildSettings(content)
    end)
end

function LF.OpenSettings()
    if not SwirlUI then
        print("Receipt: SwirlUI is required for settings.")
        return
    end
    SwirlUI.Show()
    if SwirlUI.frames.tabController then
        SwirlUI.frames.tabController.Select("Receipt")
    end
end
