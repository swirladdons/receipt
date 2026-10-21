local _, LF = ...
local LCG = LibStub("LibCustomGlow-1.0")

function LF.AcquireFrame()
    for _, f in ipairs(LF.framePool) do
        if not f._inUse then
            f._inUse = true
            return f
        end
    end

    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(LF.FRAME_W, LF.FRAME_H)
    f:SetFrameStrata("MEDIUM")

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetColorTexture(0.074, 0.070, 0.047, 0.664)
    bg:SetAllPoints()
    f._bg = bg

    local function makeBorderLine(point1, point2, isHoriz)
        local b = f:CreateTexture(nil, "BORDER")
        b:SetColorTexture(0, 0, 0, 1)
        if isHoriz then b:SetHeight(1) else b:SetWidth(1) end
        b:SetPoint(point1, f, point1, 0, 0)
        b:SetPoint(point2, f, point2, 0, 0)
    end
    makeBorderLine("TOPLEFT", "TOPRIGHT", true)
    makeBorderLine("BOTTOMLEFT", "BOTTOMRIGHT", true)
    makeBorderLine("TOPLEFT", "BOTTOMLEFT", false)
    makeBorderLine("TOPRIGHT", "BOTTOMRIGHT", false)

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(LF.ICON_SIZE, LF.ICON_SIZE)
    icon:SetPoint("LEFT", f, "LEFT", 0, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f._icon = icon

    local glow = CreateFrame("Frame", nil, f)
    glow:SetSize(LF.ICON_SIZE, LF.ICON_SIZE)
    glow:SetPoint("CENTER", icon, "CENTER", 0, 0)
    f._glow = glow

    local ilvlTxt = f:CreateFontString(nil, "OVERLAY")
    ilvlTxt:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    ilvlTxt:SetPoint("BOTTOM", icon, "BOTTOM", 0, 3)
    ilvlTxt:SetJustifyH("CENTER")
    f._ilvlTxt = ilvlTxt

    local leftTxt = f:CreateFontString(nil, "OVERLAY")
    leftTxt:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    leftTxt:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    leftTxt:SetWidth(185)
    leftTxt:SetJustifyH("LEFT")
    leftTxt:SetJustifyV("MIDDLE")
    leftTxt:SetWordWrap(true)
    f._leftTxt = leftTxt

    local rightTxt = f:CreateFontString(nil, "OVERLAY")
    rightTxt:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    rightTxt:SetPoint("RIGHT", f, "RIGHT", -4, 0)
    rightTxt:SetJustifyH("RIGHT")
    rightTxt:SetJustifyV("MIDDLE")
    f._rightTxt = rightTxt

    local qualityBar = f:CreateTexture(nil, "OVERLAY")
    qualityBar:SetWidth(2)
    qualityBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    qualityBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    f._qualityBar = qualityBar

    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        local entry = self._entry
        if not entry then return end
        entry._hovered = true
        if entry.link then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT", 10, 0)
            GameTooltip:SetHyperlink(entry.link)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function(self)
        local entry = self._entry
        if entry then entry._hovered = false end
        GameTooltip:Hide()
    end)
    f:SetScript("OnMouseUp", function(self, btn)
        if btn ~= "RightButton" or not self._entry then return end
        LF.RemoveEntry(self._entry)
        GameTooltip:Hide()
        LF.RebuildDisplay()
    end)

    f._inUse = true
    table.insert(LF.framePool, f)
    return f
end

function LF.ReleaseFrame(f)
    if GameTooltip:GetOwner() == f then GameTooltip:Hide() end
    LCG.ProcGlow_Stop(f._glow)
    f:Hide()
    f:ClearAllPoints()
    f._inUse = false
    f._entry = nil
    f._leftTxt:SetText("")
    f._rightTxt:SetText("")
    f._ilvlTxt:SetText("")
end

function LF.RebuildDisplay()
    for _, row in ipairs(LF.activeRows) do
        LF.ReleaseFrame(row.frame)
    end
    LF.activeRows = {}

    local visible = {}
    for _, entry in ipairs(LF.entries) do
        table.insert(visible, entry)
    end

    table.sort(visible, function(a, b)
        return (a.prio or 0) < (b.prio or 0)
    end)

    local cfg = ReceiptDB
    for idx, entry in ipairs(visible) do
        if idx > LF.MAX_ROWS then break end

        local f = LF.AcquireFrame()

        local leftT, rightT = LF.BuildRowText(entry)
        f._leftTxt:SetText(leftT)
        f._rightTxt:SetText(rightT)
        f._icon:SetTexture(entry.icon)
        f._ilvlTxt:SetText(entry.ilvl and tostring(entry.ilvl) or "")

        local r, g, b = C_Item.GetItemQualityColor(entry.rarity or 1)
        f._qualityBar:SetColorTexture(r, g, b, 0.9)

        if entry.testGlow or LF.IsExpensive(entry) then
            LCG.ProcGlow_Start(f._glow)
        else
            LCG.ProcGlow_Stop(f._glow)
        end

        local offsetY = (idx - 1) * (LF.FRAME_H + LF.FRAME_GAP)
        f:ClearAllPoints()
        if cfg.growUp then
            f:SetPoint("BOTTOMLEFT", LF.anchor, "BOTTOMLEFT", 0, offsetY)
        else
            f:SetPoint("TOPLEFT", LF.anchor, "TOPLEFT", 0, -offsetY)
        end

        f._entry = entry

        local remaining = entry.expirationTime - GetTime()
        f:SetAlpha(math.min(1, remaining / LF.FADE_TIME))
        f:Show()
        table.insert(LF.activeRows, { frame = f, entry = entry })
    end
end

local ticker = CreateFrame("Frame")

function LF.StartTicker()
    ticker:SetScript("OnUpdate", function()
        local now = GetTime()
        local needRebuild = false

        for i = #LF.entries, 1, -1 do
            local entry = LF.entries[i]
            if entry._hovered then
                entry.expirationTime = now + entry.duration
            elseif entry.expirationTime - now <= 0 then
                table.remove(LF.entries, i)
                needRebuild = true
            end
        end

        for _, row in ipairs(LF.activeRows) do
            local remaining = row.entry.expirationTime - now
            row.frame:SetAlpha(math.min(1, remaining / LF.FADE_TIME))
        end

        if needRebuild then LF.RebuildDisplay() end
    end)
end

function LF.CreateAnchor()
    local a = CreateFrame("Frame", "ReceiptAnchor", UIParent)
    a:SetSize(LF.FRAME_W, LF.FRAME_H)
    a:SetMovable(true)
    a:EnableMouse(false)
    a:RegisterForDrag("LeftButton")
    a:SetClampedToScreen(true)

    a:SetScript("OnDragStart", function(self) self:StartMoving() end)
    a:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        ReceiptDB.posX = x - (GetScreenWidth() / 2)
        ReceiptDB.posY = y - (GetScreenHeight() / 2)
    end)

    local hl = CreateFrame("Frame", nil, a)
    hl:SetAllPoints()
    hl:Hide()
    local function makeLine(p1, p2, horiz)
        local t = hl:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(0.2, 0.8, 1, 1)
        if horiz then t:SetHeight(2) else t:SetWidth(2) end
        t:SetPoint(p1, hl, p1)
        t:SetPoint(p2, hl, p2)
    end
    makeLine("TOPLEFT", "TOPRIGHT", true)
    makeLine("BOTTOMLEFT", "BOTTOMRIGHT", true)
    makeLine("TOPLEFT", "BOTTOMLEFT", false)
    makeLine("TOPRIGHT", "BOTTOMRIGHT", false)
    a._highlight = hl

    local cfg = ReceiptDB
    a:SetPoint("CENTER", UIParent, "CENTER", cfg.posX or 0, cfg.posY or 200)
    a:Show()
    LF.anchor = a
end

local function SetPreviewEntry(show)
    local cur = LF.FindBySource(0)
    if show and not cur then
        table.insert(LF.entries, {
            source = 0,
            expirationTime = math.huge, duration = math.huge,
            stacks = 1, name = "Receipt · drag to move",
            icon = 135274, price = 0,
            rarity = 4, prio = -999,
        })
    elseif not show and cur then
        table.remove(LF.entries, cur)
    end
    LF.RebuildDisplay()
end

function LF.SetLocked(locked)
    LF.anchor:EnableMouse(not locked)
    if locked then
        LF.anchor._highlight:Hide()
        SetPreviewEntry(false)
    else
        LF.anchor._highlight:Show()
        SetPreviewEntry(true)
    end
end
