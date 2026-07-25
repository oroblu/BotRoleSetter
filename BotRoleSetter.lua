--[[
BotRoleSetter v5 — CMaNGOS Playerbots (Classic Era 1.14.x)
Auto-detects bot class from target. Picks the right talent spec for each role.
Uses `talents <specname>` from aiplayerbot.conf.dist.in spec names.
GossipFrame-style UI with Greeting texture corners.
--]]

SLASH_BRS1 = "/brs"
SlashCmdList["BRS"] = function()
    if BotRoleSetterFrame then
        BotRoleSetterFrame:SetShown(not BotRoleSetterFrame:IsShown())
    end
end

if not BRS_Options then BRS_Options = {} end
if not BRS_Options.role then BRS_Options.role = "tank" end

----------------------------- Class icons
local CLASS_ICONS = {
    WARRIOR     = { name = "Warrior",     icon = "Ability_Warrior_Charge" },
    PALADIN     = { name = "Paladin",     icon = "Spell_Holy_DevotionAura" },
    HUNTER      = { name = "Hunter",      icon = "Ability_Hunter_QuickShot" },
    ROGUE       = { name = "Rogue",       icon = "Ability_BackStab" },
    PRIEST      = { name = "Priest",      icon = "Spell_Holy_PowerWordShield" },
    SHAMAN      = { name = "Shaman",      icon = "Spell_Nature_LightningBolt" },
    MAGE        = { name = "Mage",        icon = "Spell_Frost_FrostBolt02" },
    WARLOCK     = { name = "Warlock",     icon = "Spell_Shadow_DeathCoil" },
    DRUID       = { name = "Druid",       icon = "Ability_Druid_Maul" },
}

----------------------------- Talent specs from aiplayerbot.conf.dist.in
local TALENTS = {
    WARRIOR     = { tank = "pve prot",                             dps = "pve fury" },
    PALADIN     = { tank = "pvp tank prot",     healer = "pve heal holy (sanctuary)", dps = "pve dps ret (basic ret)" },
    HUNTER      = {                                                                    dps = "pve dps mm (mm/sv)" },
    ROGUE       = {                                                                    dps = "pve dps combat" },
    PRIEST      = {                          healer = "pve heal holy",                dps = "pve dps shadow" },
    SHAMAN      = {                          healer = "pve heal resto (pure)",        dps = "pve dps elem (elemental mastery)" },
    MAGE        = {                                                                    dps = "pve dps fire" },
    WARLOCK     = {                                                                    dps = "pve dps demo (ds/ruin)" },
    DRUID       = { tank = "pve dps feral (dps/tank hybrid)", healer = "pve dps resto (swiftmend spec)", dps = "pve dps feral" },
}

-- Role strategy names for co command (checked by IsTank/IsHeal in PlayerbotAI.cpp)
local ROLE_STRATEGIES = { tank = "tank", healer = "heal", dps = "dps" }
local ALL_ROLE_STRS = { "tank", "heal", "dps" }

local function CanRole(cf, role)
    return TALENTS[cf] and TALENTS[cf][role] ~= nil
end

local function GetSpec(cf, role)
    if TALENTS[cf] and TALENTS[cf][role] then
        return TALENTS[cf][role]
    end
    return nil
end

----------------------------- Build command sequence
local function BuildCommands(cf, role, name)
    local spec = GetSpec(cf, role)
    local c = { "reset strats" }

    -- Set combat role strategy (reset strats clears all, then add the selected role)
    tinsert(c, "co +" .. ROLE_STRATEGIES[role] .. ",-cc,-behind")

    tinsert(c, "nc -quest,-loot,+ai chat,-grind")
    tinsert(c, ".bot init " .. name)
    if spec then
        tinsert(c, "talents " .. spec)
    end
    tinsert(c, ".bot gear " .. name)
    return c
end

local function SendToBot(cf, role)
    local name = GetUnitName("target", true)
    if not name then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[BRS] No target!|r")
        return
    end
    local cmds = BuildCommands(cf, role, name)
    for i, cmd in ipairs(cmds) do
        C_Timer.After(i - 1, function()
            SendChatMessage(cmd, "WHISPER", nil, name)
        end)
    end
    C_Timer.After(#cmds, function()
        SendChatMessage(".bot gear " .. name, "WHISPER", nil, name)
    end)

    local ci = CLASS_ICONS[cf]
    local cn = ci and ci.name or cf
    local spec = GetSpec(cf, role)
    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "|cff00ff00[BRS]|r %s -> |cffffcc00%s|r (%s)", name, cn, role:upper()))
    if spec then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cff88ddff  talents: %s|r", spec))
    end
    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "|cff88ddff  %d commands queued (3s intervals)|r", #cmds + 1))
end

----------------------------- GossipFrame-style UI
local FRAME_W, FRAME_H = 384, 512
local SCROLL_W, SCROLL_H = 300, 334

-- Helper: safe texture loading (pcall wrapper)
local function TryLoadTexture(parent, path, layer, sizeW, sizeH, anchor, offX, offY)
    local ok, tex = pcall(function()
        local t = parent:CreateTexture(nil, layer or "ARTWORK")
        t:SetTexture(path)
        t:SetSize(sizeW, sizeH)
        if offX and offX ~= 0 or offY and offY ~= 0 then
            t:SetPoint(anchor or "TOPLEFT", parent, anchor or "TOPLEFT", offX or 0, offY or 0)
        else
            t:SetPoint(anchor or "TOPLEFT")
        end
        return t
    end)
    return ok and tex or nil
end

-- UI state variables
local frame, greetingText, roleStatusText, classIcon, classNameText
local roleBtns = {}
local scrollFrame, scrollChild

----------------------------- Refresh greeting text + role status
local function RefreshGreeting()
    if not greetingText then return end
    local role = BRS_Options.role
    local cf = frame._currentClassFile
    local spec = cf and GetSpec(cf, role)
    local roleName = role and role:upper() or "?"

    -- Scroll text: only the instructional part (fixed)
    greetingText:SetText("Target a player bot, pick a role, click APPLY.")

    -- Role status: centered two-liner between buttons and APPLY
    if roleStatusText then
        if spec then
            roleStatusText:SetText("Role:\n" .. roleName .. " (" .. spec .. ")")
        else
            roleStatusText:SetText("Role:\n" .. roleName)
        end
    end

    -- Resize scroll child to fit content
    if scrollChild and scrollFrame then
        local textH = greetingText:GetStringHeight() or greetingText:GetHeight() or 30
        local neededH = math.max(textH + 20, SCROLL_H)
        scrollChild:SetHeight(neededH)
        scrollFrame:UpdateScrollChildRect()
    end
end

----------------------------- Refresh role button highlights
local function RefreshHLRoles()
    local cf = frame._currentClassFile
    for k, b in pairs(roleBtns) do
        if k == BRS_Options.role then
            b:LockHighlight()
        else
            b:UnlockHighlight()
        end
        if cf and not CanRole(cf, k) then
            b:Disable()
        else
            b:Enable()
        end
    end
    RefreshGreeting()
end

----------------------------- Make a role button (UIPanelButtonTemplate + icon)
local ROLE_ICONS = {
    tank   = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    healer = "Interface\\Icons\\Spell_Holy_Heal02",
    dps    = "Interface\\Icons\\Ability_Warrior_OffensiveStance",
}

local function MakeRoleBtn(parent, text, key)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(110, 24)
    b:RegisterForClicks("LeftButtonUp")
    b._key = key

    -- Icon (16x16, left side of button)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", 6, 0)
    icon:SetTexture(ROLE_ICONS[key] or "")

    -- Shift button text right to make room for icon
    local btnText = b:GetFontString()
    if btnText then
        btnText:ClearAllPoints()
        btnText:SetPoint("LEFT", 26, 0)
        btnText:SetPoint("RIGHT", -6, 0)
        btnText:SetJustifyH("LEFT")
    end
    b:SetText(text)

    b:SetScript("OnClick", function(self)
        BRS_Options.role = self._key
        RefreshHLRoles()
    end)
    return b
end

----------------------------- Refresh class display (icon + name)
local function UpdateClassDisplay()
    local name = GetUnitName("target", true)
    local cf = name and UnitExists("target") and UnitIsPlayer("target") and select(2, UnitClass("target"))

    if cf and CLASS_ICONS[cf] then
        local ci = CLASS_ICONS[cf]
        classIcon:SetTexture("Interface\\Icons\\" .. ci.icon)
        classNameText:SetText(ci.name)
        classNameText:SetTextColor(1, 1, 1)
    else
        classIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        if name and UnitExists("target") then
            classNameText:SetText("Not a player")
            classNameText:SetTextColor(0.8, 0.4, 0.4)
        else
            classNameText:SetText("<no target>")
            classNameText:SetTextColor(0.6, 0.6, 0.6)
        end
    end
end

----------------------------- On target changed
local function OnTargetChanged()
    local n = GetUnitName("target", true)
    if n and UnitExists("target") and UnitIsPlayer("target") then
        local cls, cf = UnitClass("target")
        if cf and CLASS_ICONS[cf] then
            frame._currentClassFile = cf
            UpdateClassDisplay()
            RefreshHLRoles()
        end
    else
        frame._currentClassFile = nil
        UpdateClassDisplay()
        RefreshHLRoles()
    end
end

----------------------------- Build UI
local function CreateUI()
    -- Main frame (GossipFrame-style: 384x512, TOPLEFT 0,-104)
    frame = CreateFrame("Frame", "BotRoleSetterFrame", UIParent)
    frame:SetSize(FRAME_W, FRAME_H)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true); frame:SetUserPlaced(true)
    frame:EnableMouse(true); frame:SetClampedToScreen(true)
    frame:SetToplevel(true); frame:Hide()

    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(s) s:StartMoving() end)
    frame:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)

    -- 4 texture corners (UI-QuestGreeting-*)
    TryLoadTexture(frame, "Interface\\QuestFrame\\UI-QuestGreeting-TopLeft", "BACKGROUND", 256, 256, "TOPLEFT")
    TryLoadTexture(frame, "Interface\\QuestFrame\\UI-QuestGreeting-TopRight", "BACKGROUND", 128, 256, "TOPRIGHT")
    TryLoadTexture(frame, "Interface\\QuestFrame\\UI-QuestGreeting-BotLeft", "BACKGROUND", 256, 256, "BOTTOMLEFT")
    TryLoadTexture(frame, "Interface\\QuestFrame\\UI-QuestGreeting-BotRight", "BACKGROUND", 128, 256, "BOTTOMRIGHT")

    -- Patch texture
    TryLoadTexture(frame, "Interface\\QuestFrame\\UI-Quest-BotLeftPatch", "ARTWORK", 128, 64, "BOTTOMLEFT", 22, 68)

    -- Class icon (60x60, TOPLEFT 7,-6 — same position as GossipFrame portrait)
    classIcon = frame:CreateTexture(nil, "ARTWORK")
    classIcon:SetSize(60, 60)
    classIcon:SetPoint("TOPLEFT", 7, -6)

    -- Class name (GameFontHighlight, TOP 0,-23 — same as GossipFrame NPC name)
    local nameFrame = CreateFrame("Frame", nil, frame)
    nameFrame:SetSize(1, 14)
    nameFrame:SetPoint("TOP", frame, "TOP", 0, -23)
    classNameText = nameFrame:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
    classNameText:SetPoint("LEFT")
    classNameText:SetPoint("RIGHT")

    -- Close button (CENTER to TOPRIGHT -42,-31 — same as GossipFrameCloseButton)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("CENTER", frame, "TOPRIGHT", -42, -31)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- ============================================================
    -- SCROLL FRAME: GossipGreetingScrollFrame pattern (ESATTO come GFC)
    -- UIPanelScrollFrameTemplate, 300x334, TOPLEFT (23,-81)
    -- Scroll si attiva solo se il testo supera l'altezza visibile
    -- ============================================================

    scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(SCROLL_W, SCROLL_H)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 23, -81)

    scrollChild = CreateFrame("Frame", nil, nil)
    scrollChild:SetSize(SCROLL_W, SCROLL_H)  -- min height = SCROLL_H, grows if text exceeds
    scrollFrame:SetScrollChild(scrollChild)

    -- Scrollbar positioning (agganciata al bordo destro, come GossipFrame)
    local sb = scrollFrame.ScrollBar
    if sb then
        sb:ClearAllPoints()
        sb:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 6, -16)
        sb:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 6, 16)
    end

    -- Mouse wheel (instradato attraverso la scrollbar)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local bar = self.ScrollBar
        if bar then
            local step = bar.scrollStep or 20
            bar:SetValue(bar:GetValue() - delta * step)
        end
    end)

    -- Greeting text (QuestFont, WordWrap, DENTRO lo scroll child)
    greetingText = scrollChild:CreateFontString(nil, "OVERLAY", "QuestFont")
    greetingText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -10)
    greetingText:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -30, -10)
    greetingText:SetJustifyH("LEFT")
    greetingText:SetWordWrap(true)
    greetingText:SetText("Target a player bot, pick a role, click APPLY.")

    -- Initial scroll child sizing
    scrollFrame:UpdateScrollChildRect()

    -- ============================================================
    -- Role buttons: TANK | HEALER | DPS (centered below scroll frame)
    -- ============================================================

    local roleDefs = {
        { k = "tank",   t = "TANK" },
        { k = "healer", t = "HEALER" },
        { k = "dps",    t = "DPS" },
    }
    for i, rd in ipairs(roleDefs) do
        local b = MakeRoleBtn(frame, rd.t, rd.k)
        roleBtns[rd.k] = b
    end

    -- Anchor at same height as scroll frame content (buttons overlap empty scroll area)
    -- 75px below scroll TOP = same position the text naturally ends (~3 lines of QuestFont)
    local anchor = CreateFrame("Frame", nil, frame)
    anchor:SetSize(1, 1)
    anchor:SetPoint("TOP", scrollFrame, "TOP", 0, -75)

    roleBtns["healer"]:SetPoint("LEFT", anchor, "CENTER", 4, 0)
    roleBtns["tank"]:SetPoint("RIGHT", anchor, "CENTER", -4, 0)
    roleBtns["dps"]:SetPoint("TOP", anchor, "BOTTOM", 0, -14)

    -- ============================================================
    -- Role status text (centered, two lines, between buttons and APPLY)
    -- ============================================================

    -- Separate anchor: stays below buttons regardless of button position
    local statusAnchor = CreateFrame("Frame", nil, frame)
    statusAnchor:SetSize(1, 1)
    statusAnchor:SetPoint("TOP", scrollFrame, "TOP", 0, -175)

    roleStatusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    roleStatusText:SetPoint("TOP", statusAnchor, "BOTTOM", 0, -20)
    roleStatusText:SetWidth(SCROLL_W)
    roleStatusText:SetJustifyH("CENTER")
    roleStatusText:SetJustifyV("TOP")
    roleStatusText:SetText("Role:\n?")
    roleStatusText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")

    -- ============================================================
    -- APPLY button (anchored inside scroll frame area, near bottom)
    -- ============================================================

    local applyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    applyBtn:SetSize(120, 24)
    applyBtn:SetPoint("BOTTOM", scrollFrame, "BOTTOM", 0, 35)
    applyBtn:SetText("APPLY")
    applyBtn:SetScript("OnClick", function()
        if not frame._currentClassFile then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[BRS] Target a player first!|r")
            return
        end
        if not CanRole(frame._currentClassFile, BRS_Options.role) then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[BRS] This class can't be " .. BRS_Options.role:upper() .. "!|r")
            return
        end
        local name = GetUnitName("target", true)
        if not name then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[BRS] Lost target!|r")
            return
        end
        if UnitIsUnit("target", "player") then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[BRS] Can't set role on yourself! Target a bot.|r")
            return
        end
        SendToBot(frame._currentClassFile, BRS_Options.role)
    end)

    -- ============================================================
    -- Close button (bottom-right, same position as GossipFrame Goodbye)
    -- ============================================================

    local closeBtn2 = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn2:SetSize(78, 22)
    closeBtn2:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -39, 73)
    closeBtn2:SetText("Close")
    closeBtn2:SetScript("OnClick", function()
        frame:Hide()
    end)
end

----------------------------- Init
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addon)
    if addon ~= "BotRoleSetter" then return end
    self:UnregisterAllEvents()

    CreateUI()
    OnTargetChanged()
    frame:Hide()

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    ev:SetScript("OnEvent", function()
        OnTargetChanged()
    end)

    DEFAULT_CHAT_FRAME:AddMessage("|cff88ddff[BotRoleSetter]|r /brs to toggle. Target a bot, pick role, APPLY.")
end)
