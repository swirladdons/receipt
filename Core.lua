local _, LF = ...

LF.defaults = {
    duration = {
        ["0"] = 5,
        ["1"] = 5,
        ["2"] = 5,
        ["3"] = 5,
        ["4"] = 5,
        ["30"] = 5,
        ["6"] = 5,
        ["7"] = 5,
        gold = 5,
    },
    dispCopSilv = false,
    rep = 10,
    showRep = false,
    honor = 10,
    showHonor = false,
    showStackPrice = 3,
    showAH = 1,
    auctionAddon = 1,
    tsmDataSource = 2,
    stackColor = { 1, 1, 1, 1 },
    ahColor = { 0.137, 1, 0.212, 1 },
    showJunkAH = true,
    maxLength = 35,
    debug = false,
    invCount = false,
    advCount = false,
    highlightExpensive = false,
    highlightExpensiveSound = false,
    highlightSoundName = "Wilhelm Scream",
    highlightThreshold = 0,
    highlightUnit = 3,
    blacklist = {
        { type = 2, itemID = 2003, name = "Dragon Isles Supplies" },
        { type = 2, itemID = 1560, name = "War Resources" },
        { type = 2, itemID = 1220, name = "Order Resources" },
        { type = 2, itemID = 2815, name = "Resonance Crystals" },
        { type = 2, itemID = 3008, name = "Valorstones" },
        { type = 1, itemID = 211808, name = "Gilded Vial" },
        { type = 1, itemID = 211807, name = "Gilded Vial" },
    },
    posX = 0,
    posY = 200,
    growUp = false,
}

LF.FRAME_W = 280
LF.FRAME_H = 40
LF.FRAME_GAP = 2
LF.MAX_ROWS = 20
LF.FADE_TIME = 0.5
LF.ICON_SIZE = LF.FRAME_H

LF.entries = {}
LF.framePool = {}
LF.activeRows = {}
LF.anchor = nil

LF.bannedItems = {}
LF.bannedReps = {}
LF.bannedCurs = {}
LF.factionIDs = {}
LF.trackMoney = nil

function LF.IsBanned(index, itype)
    if not index then return false end
    if itype == 1 then return LF.bannedItems[index]
    elseif itype == 2 then return LF.bannedCurs[index]
    elseif itype == 3 then return LF.bannedReps[index]
    end
    return false
end

function LF.LoadBlacklist()
    LF.bannedItems = {}
    LF.bannedReps = {}
    LF.bannedCurs = {}
    for _, v in ipairs(ReceiptDB.blacklist or {}) do
        if v.type == 1 and v.itemID and v.itemID ~= 0 then
            local _, link = C_Item.GetItemInfo(v.itemID)
            if link then LF.bannedItems[link] = true end
        elseif v.type == 2 and v.itemID then
            LF.bannedCurs[v.itemID] = true
        elseif v.type == 3 and v.name then
            LF.bannedReps[v.name] = true
        end
    end
end

local repStrings = {
    enUS = {
        incName = ".*with ([%w %-',%(%):]+) increased by.*",
        decName = ".*with ([%w %-',%(%):]+) decreased by.*",
        incVal = ".*increased by (%d+)%.?",
        decVal = ".*decreased by (%d+)%.?",
        expName = "([%w %-',%(%):]+) has gained %d+ experience.",
        expVal = "[%w %-',%(%):]- has gained (%d+) experience.",
    },
    deDE = {
        incName = ".*der Fraktion '([%w %-',%(%):]+)' hat sich um.*",
        decName = ".*der Fraktion '([%w %-',%(%):]+)' hat sich um.*",
        incVal = ".-(%d+) verbessert%.?",
        decVal = ".-(%d+) verschlechtert%.?",
        expName = "([%w %-',%(%):]-) hat %d+ Erfahrung erlangt.",
        expVal = "[%w %-',%(%):]- hat (%d+) Erfahrung erlangt.",
    },
}

function LF.GetRepString(s)
    local locale = GetLocale()
    return (repStrings[locale] and repStrings[locale][s]) or ""
end

function LF.ScanFactions()
    C_Reputation.ExpandAllFactionHeaders()
    for i = 1, C_Reputation.GetNumFactions() do
        local info = C_Reputation.GetFactionDataByIndex(i)
        if info then
            LF.factionIDs[info.name] = info.factionID
        end
    end
end

function LF.GetFactionStanding(facName)
    local factionID
    if facName == "Guild" or facName == "Gilde" then
        factionID = 1168
    else
        factionID = LF.factionIDs[facName]
        if not factionID then
            LF.ScanFactions()
            factionID = LF.factionIDs[facName]
        end
    end
    if not factionID then return "", 0 end

    local info = C_Reputation.GetFactionDataByID(factionID)
    if not info then return "", 0 end

    local bv, tv, ev, renownLevel
    local rs = " R: "

    bv = info.currentReactionThreshold or 0
    tv = info.nextReactionThreshold or 0
    ev = info.currentStanding or 0

    if facName ~= "Inactive" and facName ~= "Other" then
        local fri = C_GossipInfo.GetFriendshipReputation(info.factionID)
        local maj = C_MajorFactions.GetMajorFactionData(info.factionID)

        if fri and fri.friendshipFactionID and fri.friendshipFactionID ~= 0 then
            bv = fri.reactionThreshold or 0; tv = fri.nextThreshold or fri.standing or 0
            ev = fri.standing or 0; renownLevel = fri.reaction
        end

        if maj and maj.renownLevelThreshold and C_Reputation.IsMajorFaction(info.factionID) then
            bv = 0; tv = maj.renownLevelThreshold
            ev = maj.renownReputationEarned; renownLevel = maj.renownLevel
        end
    end

    if C_Reputation.IsFactionParagon(info.factionID) then
        local cur, threshold, _, hasPending = C_Reputation.GetFactionParagonInfo(info.factionID)
        renownLevel = math.floor(cur / threshold) - (hasPending and 1 or 0)
        bv = 0; ev = math.floor(cur - (renownLevel * threshold)); tv = threshold
        rs = " P: "
    end

    local ret = " |r(" .. tostring(ev - bv) .. " / " .. tostring(tv - bv) .. ")" ..
                (renownLevel and (rs .. tostring(renownLevel)) or "")
    return ret, string.len(ret) - 3
end


function LF.Colorize(text, color)
    if not color then return text end
    return WrapTextInColorCode(text, CreateColor(color[1], color[2], color[3], color[4] or 1):GenerateHexColor())
end

function LF.FormatPrice(price, color)
    if type(price) == "string" then price = tonumber(price) or 0 end
    if not price or price <= 0 then return "" end

    local cfg = ReceiptDB
    local cv = price % 100
    local sv = math.floor(price / 100) % 100
    local gv = math.floor(price / 10000)

    local function wrap(n) return LF.Colorize(tostring(n), color) end

    local c = wrap(cv)
    local s = wrap(sv)
    local g = wrap(gv)

    if gv > 0 then
        g = g .. "|cffffff00g |r"
        if sv < 10 then s = " " .. s end
        if cv < 10 then c = " " .. c end
        s = s .. "|cffb0b0b0s |r"
        c = c .. "|cffd17c4bc |r"
        return g .. (cfg.dispCopSilv and (s .. c) or "")
    elseif sv > 0 then
        s = s .. "|cffb0b0b0s |r"
        if cv < 10 then c = " " .. c end
        c = c .. "|cffd17c4bc |r"
        return s .. (cfg.dispCopSilv and c or "")
    elseif cv > 0 then
        return c .. "|cffd17c4bc |r"
    end
    return ""
end


function LF.IsGear(classID)
    return classID == Enum.ItemClass.Armor or classID == Enum.ItemClass.Weapon
end

local socketKeys = {
    EMPTY_SOCKET_META = "|T136257:0|t",
    EMPTY_SOCKET_RED = "|T136258:0|t",
    EMPTY_SOCKET_YELLOW = "|T136259:0|t",
    EMPTY_SOCKET_BLUE = "|T136256:0|t",
    EMPTY_SOCKET_PRISMATIC = "|T458977:0|t",
}

function LF.BuildSocketText(stats)
    if not stats then return nil end
    local text = ""
    local found = false
    for key, tex in pairs(socketKeys) do
        local n = stats[key]
        if n then
            for _ = 1, n do text = text .. tex end
            found = true
        end
    end
    return found and (text .. "|cFFFF00FFSocket|r") or nil
end

function LF.BuildTertiaryText(stats)
    if not stats then return "" end
    local t = ""
    if stats["ITEM_MOD_CR_AVOIDANCE_SHORT"] then t = t .. " |cFF00FFFFAvoidance|r" end
    if stats["ITEM_MOD_CR_LIFESTEAL_SHORT"] then t = t .. " |cFF00FFFFLeech|r" end
    if stats["ITEM_MOD_CR_SPEED_SHORT"] then t = t .. " |cFF00FFFFSpeed|r" end
    if stats["ITEM_MOD_CR_STURDINESS_SHORT"] then t = t .. " |cFF00FFFFIndestructible|r" end
    return t
end


function LF.HasAuctionData()
    local cfg = ReceiptDB
    if cfg.showAH == 1 then return false end
    if cfg.auctionAddon == 1 then
        return C_AddOns.IsAddOnLoaded("Auctionator") and
               Auctionator and Auctionator.API and Auctionator.API.v1 and
               Auctionator.API.v1.GetAuctionPriceByItemLink
    elseif cfg.auctionAddon == 2 then
        return C_AddOns.IsAddOnLoaded("TradeSkillMaster") and TSM_API and TSM_API.GetCustomPriceValue
    end
    return false
end

function LF.GetAuctionValue(link)
    if not LF.HasAuctionData() then return nil end
    local cfg = ReceiptDB
    if cfg.auctionAddon == 1 then
        return Auctionator.API.v1.GetAuctionPriceByItemLink("Receipt", link)
    elseif cfg.auctionAddon == 2 then
        local id = strmatch(link, "item:(%d+)") or 0
        if id == 0 then return 0 end
        local tsmID = "i:" .. id
        if cfg.tsmDataSource == 1 then
            return TSM_API.GetCustomPriceValue("dbmarket", tsmID)
        else
            return TSM_API.GetCustomPriceValue("dbminbuyout", tsmID)
        end
    end
end


function LF.GetInvCount(entry)
    local cfg = ReceiptDB
    if not cfg.invCount or not entry.link then return "", 0 end

    local link = entry.link

    if cfg.advCount and string.match(link, "|A:Professions%-ChatIcon%-Quality%-Tier") then
        local base = tonumber(string.match(link, "|A:Professions%-ChatIcon%-Quality%-Tier(%d)") or 0)
        local baseID = tonumber(link:match("item:(%d*):") or 0)
        local pre = { "|r|cffd17c4b", "|r|cffb0b0b0", "|r|cffffff00" }
        local suf = { ":11:11::1|a", ":11:15::1|a", ":12:16::1|a" }
        local counts = ""
        local appLen = 0
        local hasParen = false
        for tier = 1, 3 do
            local tLink = link:gsub("Tier%d", "Tier" .. tier)
            tLink = tLink:gsub("item:(%d*):", "item:" .. tostring(baseID + (tier - base)) .. ":")
            tLink = tLink:gsub("38:(%d):", "38:" .. tostring(tier) .. ":")
            local count = C_Item.GetItemCount(tLink)
            if count and count > 0 then
                if not hasParen then counts = counts .. " |r("; appLen = appLen + 2; hasParen = true
                else counts = counts .. " "; appLen = appLen + 1 end
                local nc = pre[tier] .. tostring(count)
                appLen = appLen + string.len(nc) - 11
                nc = nc .. "|A:Professions-ChatIcon-Quality-Tier" .. tier .. suf[tier]
                counts = counts .. nc
            end
        end
        if hasParen then counts = counts .. "|r)"; appLen = appLen + 1 end
        return counts, appLen
    else
        local count = C_Item.GetItemCount(link)
        if count and count > 1 then
            local s = " |r(" .. tostring(count) .. ")"
            return s, string.len(tostring(count)) + 2
        end
    end
    return "", 0
end


function LF.BuildRowText(entry)
    local cfg = ReceiptDB
    if not entry or not entry.rarity then return "", "" end

    local color = select(4, C_Item.GetItemQualityColor(entry.rarity))
    local name = entry.name or ""
    local isItem = entry.source == 3 or entry.source == 4
    local isGear = entry.isGear
    local priceV = tonumber(entry.price) or 0
    local priceB = LF.FormatPrice(priceV)
    local stacks = tonumber(entry.stacks or 1)
    local stackV = stacks

    local append = entry.append or ""
    local appendLen = entry.appendLen or 0

    if isItem and not isGear then
        local ia, il = LF.GetInvCount(entry)
        if il > 0 then append = ia; appendLen = il end
    end

    local mLen = math.max(0, cfg.maxLength - appendLen)
    if string.len(name) > mLen then
        name = string.sub(name, 1, mLen) .. "..."
    end
    name = WrapTextInColorCode(name .. append, color)

    local stacksStr
    if entry.source == 5 then
        stacksStr = (stacks >= 0 and "+" or "|cffFF0000") ..
                    tostring(stacks) ..
                    (stacks >= 0 and " " or "|r ")
    else
        stacksStr = stackV > 1 and (tostring(stackV) .. "x ") or ""
    end

    local leftText = stacksStr .. name

    local tertiary = entry.tert
    local socket = entry.sock
    local hasExtra = (socket and socket ~= "") or (tertiary and tertiary ~= "")

    if hasExtra then
        leftText = leftText .. "\n"
        if tertiary and tertiary ~= "" then leftText = leftText .. tertiary end
        if socket and socket ~= "" then leftText = leftText .. " " .. socket end
    end

    local rightText = ""

    if cfg.showAH ~= 1 and
       (cfg.showJunkAH or tonumber(entry.rarity) > 0) and
       LF.HasAuctionData() and entry.link then
        local AH = LF.GetAuctionValue(entry.link)
        if AH and AH ~= "" then
            entry.AH = AH
            local ahPrice = (cfg.showAH == 3 and stackV > 1) and
                             LF.FormatPrice(AH * stackV, cfg.ahColor) or
                             LF.FormatPrice(AH, cfg.ahColor)
            rightText = ahPrice
        end
    end

    if cfg.showStackPrice ~= 3 or (cfg.showStackPrice == 3 and stackV == 1) then
        if rightText ~= "" then rightText = "\n" .. rightText end
        rightText = priceB .. rightText
    end

    if stackV > 1 and priceV > 0 and cfg.showStackPrice ~= 2 then
        local sp = LF.FormatPrice(stackV * priceV, cfg.stackColor)
        rightText = sp .. (rightText ~= "" and ("\n" .. rightText) or "")
    end

    return leftText, rightText
end


function LF.GetDur(rarity)
    return ReceiptDB.duration[tostring(rarity)] or 1
end


function LF.FindEntry(key, source, byName)
    local isDup = false
    for i, e in ipairs(LF.entries) do
        if (byName and e.name or e.link) == key then
            if e.source == source then return false, i end
            isDup = true
        end
    end
    return isDup, nil
end

function LF.FindBySource(source)
    for i, e in ipairs(LF.entries) do
        if e.source == source then return i end
    end
end

function LF.AddEntry(index, data)
    if index then
        LF.entries[index] = data
    else
        table.insert(LF.entries, data)
    end
    LF.RebuildDisplay()
    LF.CheckHighlight(data)
end

function LF.RemoveEntry(entry)
    for i, e in ipairs(LF.entries) do
        if e == entry then
            table.remove(LF.entries, i)
            return
        end
    end
end

function LF.IsExpensive(entry)
    local cfg = ReceiptDB
    if not cfg.highlightExpensive then return false end

    local thresh = cfg.highlightThreshold * (100 ^ (cfg.highlightUnit - 1))
    if thresh <= 0 then return false end

    local price = tonumber(entry.price) or 0
    local AH = tonumber(entry.AH) or 0
    return (price >= thresh) or
           (AH > 0 and tonumber(entry.rarity or 0) > 0 and AH >= thresh)
end

function LF.CheckHighlight(entry)
    local cfg = ReceiptDB
    if not cfg.highlightExpensiveSound or not LF.IsExpensive(entry) then return end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local path = LSM and LSM:Fetch("sound", cfg.highlightSoundName or "") or cfg.highlightSoundName
    if path then PlaySoundFile(path, "Master") end
end
