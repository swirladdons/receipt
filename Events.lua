local _, LF = ...

function LF.OnPlayerMoney()
    if LF.trackMoney == nil then LF.trackMoney = GetMoney(); return end

    local newMoney = GetMoney()
    local dMoney = newMoney - LF.trackMoney
    local cur = LF.FindBySource(1)
    if cur then
        dMoney = dMoney + (LF.entries[cur].price or 0)
    end

    if dMoney > 0 then
        local icon = dMoney > 9999 and 133784 or dMoney > 99 and 133786 or 133788
        local dur = LF.GetDur("gold")
        if dur > 0 then
            LF.AddEntry(cur, {
                duration = dur,
                expirationTime = GetTime() + dur,
                stacks = 1, name = "Money",
                icon = icon, price = dMoney,
                rarity = 1, prio = -1, source = 1,
            })
        end
    end
    LF.trackMoney = newMoney
end

local function BuildItemEntry(text, link, itemStacks, source, existingSlot, existingEntries)
    local name, _, itemRarity, _, _, _, _, _, _, icon, price, classID = C_Item.GetItemInfo(text)
    if not name then return end

    local isQuest = classID == Enum.ItemClass.Questitem
    local rarity = isQuest and 7 or itemRarity
    -- legendary and above share the "30" duration setting
    local dur = LF.GetDur((not isQuest and rarity >= 5) and "30" or rarity)
    if dur <= 0 then return end

    if existingSlot then
        itemStacks = itemStacks + tonumber(existingEntries[existingSlot].stacks)
    end

    local itemStats = C_Item.GetItemStats(link)

    return {
        duration = dur,
        expirationTime = GetTime() + dur,
        stacks = itemStacks,
        name = name,
        icon = icon,
        price = price,
        rarity = rarity,
        link = link,
        tert = LF.BuildTertiaryText(itemStats),
        sock = LF.BuildSocketText(itemStats),
        ilvl = C_Item.GetDetailedItemLevelInfo(link),
        isGear = LF.IsGear(classID),
        prio = rarity,
        source = source,
    }
end

function LF.OnLootSlotCleared(cached)
    local link = cached.link
    if LF.IsBanned(link, 1) then return end

    if ReceiptDB.debug then print("LOOT_SLOT_CLEARED", link, cached.qty) end

    local function tryBuild(retries)
        local isDup, cur = LF.FindEntry(link, 4)
        if isDup then return end
        local entry = BuildItemEntry(link, link, cached.qty or 1, 4, cur, LF.entries)
        if entry then
            LF.AddEntry(cur, entry)
        elseif retries < 5 then
            C_Timer.After(0.15, function() tryBuild(retries + 1) end)
        end
    end
    tryBuild(0)
end

function LF.OnEncounterLootReceived(retries, args)
    if not ReceiptDB then return end
    local _, _, text, _, playerName = unpack(args)
    if not text then return end
    if playerName ~= GetUnitName("player") then return end

    local link = select(2, C_Item.GetItemInfo(text))
    if not link then
        if retries < 5 then
            C_Timer.After(0.15, function() LF.OnEncounterLootReceived(retries + 1, args) end)
        end
        return
    end

    if LF.IsBanned(link, 1) then return end
    local isDup, cur = LF.FindEntry(link, 3)
    if isDup then return end

    if ReceiptDB.debug then print("ENCOUNTER_LOOT_RECEIVED", unpack(args)) end
    local itemStacks = tonumber(args[4]) or 1
    local entry = BuildItemEntry(text, link, itemStacks, 3, cur, LF.entries)
    if entry then LF.AddEntry(cur, entry) end
end

function LF.OnChatMsgCurrency(...)
    local cfg = ReceiptDB
    local str = select(1, ...)
    if not str then return end

    local itemLink, count = string.match(str, "(|c.-|r) ?x?(%d+)")
    if not itemLink then return end

    local info = C_CurrencyInfo.GetCurrencyInfoFromLink(itemLink)
    if not info then return end

    if LF.IsBanned(info.currencyID, 2) then return end
    local isDup, cur = LF.FindEntry(itemLink, 2)
    if isDup then return end

    count = tonumber(count) or 0
    if cur then count = count + tonumber(LF.entries[cur].stacks) end

    local append, appendLen
    if info.quantity then
        local qty = info.quantity
        local max = info.maxQuantity
        local ear = info.totalEarned
        appendLen = 2 + #tostring(qty) + ((max and max ~= 0) and 3 + #tostring(max) or 0)
        if ear and info.useTotalEarnedForMaxQty then
            appendLen = appendLen + 1 + #tostring(ear)
            append = " |r|cffffffff|r" .. qty ..
                     ((ear == max) and "|cffFF0000" or "") ..
                     " (" .. ear .. ((max and max ~= 0) and " / " .. max or "") ..
                     ((ear == max) and "|r" or "") .. "|cffffffff)|r"
        else
            append = " |r|cffffffff(|r" ..
                     ((max and qty == max) and "|cffFF0000" or "") ..
                     qty .. ((max and max ~= 0) and " / " .. max or "") ..
                     ((max and qty == max) and "|r" or "") .. "|cffffffff)|r"
        end
    end

    if cfg.debug then print("CHAT_MSG_CURRENCY", ...) end
    local dur = LF.GetDur(6)
    if dur <= 0 or count == 0 then return end

    LF.AddEntry(cur, {
        duration = dur,
        expirationTime = GetTime() + dur,
        stacks = count, name = info.name,
        append = append, appendLen = appendLen,
        icon = info.iconFileID, price = 0,
        rarity = 6, link = itemLink, prio = 9, source = 2,
    })
end

function LF.OnFactionChange(...)
    local cfg = ReceiptDB
    local text = select(1, ...)
    if not text then return end

    local suf = " Rep"
    local faction = string.match(text, LF.GetRepString("incName")) or
                    string.match(text, LF.GetRepString("decName")) or ""
    local stacks = tonumber(string.match(text, LF.GetRepString("incVal"))) or
                   (tonumber(string.match(text, LF.GetRepString("decVal")) or 0) * -1) or 0

    if faction == "" then
        faction = string.match(text, LF.GetRepString("expName")) or ""
        if faction ~= "" then
            suf = " Exp"
            stacks = tonumber(string.match(text, LF.GetRepString("expVal"))) or 0
        end
    end

    if LF.IsBanned(faction, 3) then return end
    local key = faction .. suf
    local isDup, cur = LF.FindEntry(key, 5, true)
    if isDup then return end

    if cur then stacks = stacks + tonumber(LF.entries[cur].stacks) end

    local append, appendLen = LF.GetFactionStanding(faction)
    if cfg.debug then print("CHAT_MSG_COMBAT_FACTION_CHANGE", ...) end

    local dur = cfg.rep
    if dur <= 0 then return end

    LF.AddEntry(cur, {
        duration = dur,
        expirationTime = GetTime() + dur,
        stacks = stacks, name = faction .. suf,
        append = append, appendLen = appendLen,
        icon = 236681, price = 0, rarity = 7, prio = 10, source = 5,
    })
end

function LF.OnHonorGain(...)
    local cfg = ReceiptDB
    local str = select(1, ...)
    if not str then return end

    local count = tonumber(string.match(str, "awarded (%d*) honor points") or
                           string.match(str, "Estimated Honor Points: (%d*)"))
    if not count or count == 0 then return end

    local cur = LF.FindBySource(7)
    if cur then count = count + tonumber(LF.entries[cur].stacks) end

    if cfg.debug then print("CHAT_MSG_COMBAT_HONOR_GAIN", ...) end
    local dur = cfg.honor or 10
    if dur <= 0 then return end

    LF.AddEntry(cur, {
        duration = dur,
        expirationTime = GetTime() + dur,
        stacks = count, name = "Honor",
        icon = 1455894, price = 0, rarity = 6, prio = 9, source = 7,
    })
end

local lootSlotCache = {}

local function CacheLootSlots()
    lootSlotCache = {}
    for i = 1, GetNumLootItems() do
        local icon, name, qty, _, rarity, locked = GetLootSlotInfo(i)
        if icon and not locked then
            local link = GetLootSlotLink(i)
            lootSlotCache[i] = { icon = icon, name = name, qty = qty, rarity = rarity, link = link }
        end
    end
end

local eventFrame = CreateFrame("Frame", "ReceiptEvents", UIParent)
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("LOOT_SLOT_CLEARED")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:RegisterEvent("CHAT_MSG_CURRENCY")
eventFrame:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
eventFrame:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
eventFrame:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if select(1, ...) == "Receipt" then LF.OnAddonLoaded() end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        if ReceiptDB then LF.OnPlayerEnteringWorld() end
        return
    end

    if event == "LOOT_OPENED" then
        CacheLootSlots()
        return
    end

    if event == "LOOT_CLOSED" then
        lootSlotCache = {}
        return
    end

    if event == "LOOT_SLOT_CLEARED" then
        if not ReceiptDB then return end
        local slot = select(1, ...)
        local cached = lootSlotCache[slot]
        lootSlotCache[slot] = nil
        if not cached or not cached.link then return end
        LF.OnLootSlotCleared(cached)
        return
    end

    local cfg = ReceiptDB
    if not cfg then return end

    if event == "PLAYER_MONEY" then
        LF.OnPlayerMoney()
    elseif event == "CHAT_MSG_CURRENCY" then
        LF.OnChatMsgCurrency(...)
    elseif event == "ENCOUNTER_LOOT_RECEIVED" then
        LF.OnEncounterLootReceived(0, { ... })
    elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        if cfg.showRep then LF.OnFactionChange(...) end
    elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
        if cfg.showHonor then LF.OnHonorGain(...) end
    end
end)

local testItemIDs = { 19019, 17182, 22691, 32837, 32838, 28773, 46017, 40395, 18803, 871 }
local testItems = nil
local testItemIdx = 0

local testTertOptions = {
    "", " |cFF00FFFFLeech|r", " |cFF00FFFFSpeed|r",
    " |cFF00FFFFAvoidance|r", " |cFF00FFFFLeech|r |cFF00FFFFSpeed|r",
}

function LF.SpawnTestEntry()
    if not testItems then
        local items = {}
        for _, itemID in ipairs(testItemIDs) do
            local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
            if name and icon then
                items[#items + 1] = { name = name, icon = icon }
            end
        end
        if #items == 0 then
            for _, itemID in ipairs(testItemIDs) do
                C_Item.RequestLoadItemDataByID(itemID)
            end
            C_Timer.After(0.5, LF.SpawnTestEntry)
            return
        end
        testItems = items
    end
    testItemIdx = (testItemIdx % #testItems) + 1
    local item = testItems[testItemIdx]
    local rarity = math.random(1, 5)
    local ilvl = math.random(580, 639)
    local price = math.random(0, 500000)
    local stacks = math.random(1, 3) == 1 and math.random(2, 20) or 1
    local tert = testTertOptions[math.random(1, #testTertOptions)]
    local dur = ReceiptDB.duration[tostring(rarity)] or 8

    LF.AddEntry(nil, {
        duration = dur,
        expirationTime = GetTime() + dur,
        stacks = stacks, name = item.name,
        icon = item.icon, price = price,
        rarity = rarity, prio = rarity, source = 4,
        isGear = true, ilvl = ilvl,
        tert = tert,
        testGlow = math.random(1, 4) == 1,
    })
end

SLASH_RECEIPT1 = "/receipt"
SLASH_RECEIPT2 = "/lf"
SlashCmdList["RECEIPT"] = function(msg)
    local cmd = (msg:match("^(%S*)") or ""):lower()
    if cmd == "debug" then
        ReceiptDB.debug = not ReceiptDB.debug
        print("|cff00ccffReceipt|r: Debug " .. (ReceiptDB.debug and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    else
        LF.OpenSettings()
    end
end

function LF.OnAddonLoaded()
    if not ReceiptDB then ReceiptDB = {} end

    -- migrate old saved-variable layout
    if ReceiptDB.duration and ReceiptDB.duration.dispCopSilv ~= nil then
        ReceiptDB.dispCopSilv = ReceiptDB.duration.dispCopSilv
        ReceiptDB.duration.dispCopSilv = nil
    end
    if ReceiptDB.highlightThreshold3 ~= nil then
        ReceiptDB.highlightThreshold = ReceiptDB.highlightThreshold3
        ReceiptDB.highlightThreshold3 = nil
    end

    local function mergeDefaults(target, source)
        for k, v in pairs(source) do
            if target[k] == nil then
                target[k] = type(v) == "table" and {} or v
            end
            if type(v) == "table" then
                mergeDefaults(target[k], v)
            end
        end
    end
    mergeDefaults(ReceiptDB, LF.defaults)

    LF.CreateAnchor()
    LF.LoadBlacklist()
    LF.StartTicker()
    LF.RegisterSettings()
end

function LF.OnPlayerEnteringWorld()
    LF.ScanFactions()
    LF.trackMoney = GetMoney()
end
