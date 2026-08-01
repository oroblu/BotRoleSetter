--[[
BotRoleSetter v6 — CMaNGOS Playerbots (Classic Era 1.14.x)
Auto-detects bot class from target. Picks the right talent spec for each role.
Uses `talents <specname>` from aiplayerbot.conf.dist.in spec names.
GossipFrame-style UI with Greeting texture corners + spec dropdown.
--]]

-- Forward declarations (Lua 5.1: local functions must be declared before first use)
local OnTargetChanged

SLASH_BRS1 = "/brs"
SlashCmdList["BRS"] = function()
    if BotRoleSetterFrame then
        local opening = not BotRoleSetterFrame:IsShown()
        if opening then
            -- Auto-select first group member on open
            BotRoleSetterFrame._autoUnit = nil
            if IsInRaid() then
                for i = 1, 40 do
                    local u = "raid" .. i
                    if UnitExists(u) and UnitIsPlayer(u) and not UnitIsUnit(u, "player") then
                        BotRoleSetterFrame._autoUnit = u
                        break
                    end
                end
            elseif IsInGroup() then
                if UnitExists("party1") then
                    BotRoleSetterFrame._autoUnit = "party1"
                end
            end
            if not BotRoleSetterFrame._autoUnit then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[BRS] You are not in party, invite your bots|r")
            end
            OnTargetChanged()
        end
        BotRoleSetterFrame:SetShown(not BotRoleSetterFrame:IsShown())
    end
end

if not BRS_Options then BRS_Options = {} end
if not BRS_Options.role then BRS_Options.role = "tank" end
if not BRS_Options.spec then BRS_Options.spec = nil end

-- Returns the best available bot unit:
-- 1. Manual target (always takes priority — even NPC, UI handles the "?" state)
-- 2. Auto-selected unit from /brs open (only if no target)
-- 3. Falls back to "target"
local function GetBotUnit()
    if UnitExists("target") then
        return "target"
    end
    if BotRoleSetterFrame and BotRoleSetterFrame._autoUnit and UnitExists(BotRoleSetterFrame._autoUnit) then
        return BotRoleSetterFrame._autoUnit
    end
    return "target"
end

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

----------------------------- Talent specs from spp-classics-cmangos aiplayerbot.conf
-- Source: https://github.com/celguar/spp-classics-cmangos (Settings/vanilla/aiplayerbot.conf)
-- Every spec is a valid argument to the `talents` bot command.
local TALENTS = {
    ----------------------------- Warrior
    WARRIOR = {
        tank = {
            "pve prot",
            "pvp prot",
        },
        dps = {
            "pve arms",
            "pve fury",
            "pvp arms",
            "pvp fury",
        },
    },
    ----------------------------- Paladin
    PALADIN = {
        tank = {
            "pvp tank prot",
            "pve tank prot (stun reckoning)",
        },
        healer = {
            "pve heal holy (sanctuary)",
            "pve heal holy (holy shock)",
            "pvp heal holy",
            "pvp heal Holy",
        },
        dps = {
            "pve dps ret (basic ret)",
            "pve dps ret (geared ret)",
            "pvp dps ret",
            "pvp dps ret (Loaded Reck Bomb)",
        },
    },
    ----------------------------- Hunter
    HUNTER = {
        dps = {
            "pve dps mm (mm/sv)",
            "pve dps mm (mm/bm)",
            "pve dps bm (farmer)",
            "pve dps mm",
            "pvp dps surv",
            "pvp dps mm",
            "pvp dps bm",
        },
    },
    ----------------------------- Rogue (duplicate indices in config — only last value per index)
    ROGUE = {
        dps = {
            "pve dps combat (swords)",
            "pve dps combat (daggers)",
            "pve dps assassination",
            "pvp dps combat (swords)",
            "pvp dps subtlety",
        },
    },
    ----------------------------- Priest
    PRIEST = {
        healer = {
            "pve heal disc",
            "pve heal holy",
            "pvp heal holy",
        },
        dps = {
            "pve dps shadow",
            "pvp dps disc",
            "pvp dps shadow",
        },
    },
    ----------------------------- Shaman
    SHAMAN = {
        healer = {
            "pve heal resto (pure)",
            "pve heal resto (melee support resto)",
            "pvp heal resto",
        },
        dps = {
            "pve dps elem (elemental mastery)",
            "pve dps elem (nature's swiftness)",
            "pve dps elem (force of nature + hand of edward the odd)",
            "pvp dps elem (nature's swiftness)",
            "pvp dps elem (elemental mastery)",
            "pvp dps enhan (2hand)",
        },
    },
    ----------------------------- Mage
    MAGE = {
        dps = {
            "pve dps arcane",
            "pve dps fire",
            "pve dps frost (winter's chill spec)",
            "pve dps frost (frost build for farming)",
            "pve dps frost (frost-arcane)",
            "pve dps frost (fun)",
            "pve dps frost (aoe farm)",
            "pve dps arcane (glass cannon)",
            "pve dps frost",
            "pvp dps frost",
            "pvp dps frost (frosted fun)",
            "pvp dps arcane (venruki)",
        },
    },
    ----------------------------- Warlock
    WARLOCK = {
        dps = {
            "pve dps demo (ds/ruin)",
            "pve dps demo (succubus sacrifice)",
            "pve dps dest (imp lord)",
            "pve dps demo (sm/ruin)",
            "pve dps affli",
            "pvp dps demo (sl)",
            "pvp dps demo (soul link/ shadowburn)",
            "pvp dps demo (soul link/ nightfall)",
            "pvp dps affli (sm/ruin)",
            "pvp dps affli (drakedog)",
            "pvp dps destro (conflagrate)",
        },
    },
    ----------------------------- Druid
    DRUID = {
        tank = {
            "pve dps feral (dps/tank hybrid)",
        },
        healer = {
            "pve dps resto (swiftmend spec)",
            "pve dps resto (regrowth spec bear aoe farm)",
            "pve dps resto (resto-balance)",
            "pvp dps resto (swiftmend / feral charge)",
            "pvp dps resto",
        },
        dps = {
            "pve dps feral",
            "pvp dps feral (heart of the wild / ns)",
            "pvp dps balance (moonfury)",
            "pvp dps balance (boomkin)",
        },
    },
}

-- Role strategy names for co command (checked by IsTank/IsHeal in PlayerbotAI.cpp)
local ROLE_STRATEGIES = { tank = "tank", healer = "heal", dps = "dps" }

----------------------------- Helpers

local function CanRole(cf, role)
    return TALENTS[cf] and TALENTS[cf][role] ~= nil
end

-- Returns the list of spec strings for a class+role, or nil
local function GetSpecList(cf, role)
    if TALENTS[cf] and TALENTS[cf][role] then
        return TALENTS[cf][role]
    end
    return nil
end

-- Returns the default (first) spec for a class+role, or nil
local function GetDefaultSpec(cf, role)
    local specs = GetSpecList(cf, role)
    return specs and specs[1] or nil
end

-- Returns the currently selected spec (from dropdown), or the default.
-- Warns in chat if the saved spec is no longer valid and falls back to default.
local function GetSpec(cf, role)
    if BRS_Options.spec then
        local specs = GetSpecList(cf, role)
        if specs then
            for _, s in ipairs(specs) do
                if s == BRS_Options.spec then
                    return BRS_Options.spec
                end
            end
        end
        -- Saved spec no longer valid (removed/renamed in TALENTS table)
        local old = BRS_Options.spec
        BRS_Options.spec = nil
        local fallback = GetDefaultSpec(cf, role)
        if fallback then
            DEFAULT_CHAT_FRAME:AddMessage(string.format(
                "|cffffaa44[BRS] Spec '%s' no longer available, using '%s'|r", old, fallback))
        end
    end
    return GetDefaultSpec(cf, role)
end

----------------------------- Build command sequence
-- Order matters for party bots:
-- 1. talents first → auto talents inside .bot init sees the spec and continues it,
--    so InitEquipment picks gear for the right role (tank/dps/healer).
-- 2. .bot init → gear + default strats (isRandomBot=false so talents survive).
-- 3. reset strats → recalc defaults on the new spec.
-- 4. co/nc → custom layer on top (must be AFTER .bot init, which wipes them).
local function BuildCommands(cf, role, name, spec)
    if not spec then spec = GetSpec(cf, role) end
    local c = {}

    if spec then
        tinsert(c, "talents " .. spec)
    end
    tinsert(c, ".bot init " .. name .. " rare")
    tinsert(c, "reset strats")
    tinsert(c, "nc -quest,-loot,+ai chat,-grind")
    tinsert(c, "follow")
    local coCmd = "co +" .. ROLE_STRATEGIES[role] .. ",-cc,-behind"
    if role ~= "dps" then
        coCmd = coCmd .. ",-dps"
    end
    tinsert(c, "summon")
    tinsert(c, coCmd)
    return c
end

local function SendToBot(cf, role)
    local unit = GetBotUnit()
    local name = GetUnitName(unit, true)
    if not name then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[BRS] No target!|r")
        return
    end
    local spec = GetSpec(cf, role)  -- Called once, used by BuildCommands and display
    local cmds = BuildCommands(cf, role, name, spec)
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ddff[BRS] Queueing " .. #cmds .. " commands to " .. name .. ":|r")
    for i, cmd in ipairs(cmds) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff888888  [%d/%d] t=%ds  %s|r", i, #cmds, i - 1, cmd))
        C_Timer.After(i - 1, function()
            SendChatMessage(cmd, "WHISPER", nil, name)
        end)
    end

    local ci = CLASS_ICONS[cf]
    local cn = ci and ci.name or cf
    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "|cff00ff00[BRS]|r %s -> |cffffcc00%s|r (%s)", name, cn, role:upper()))
    if spec then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cff88ddff  talents: %s|r", spec))
    end
    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "|cff88ddff  %d commands queued (1s intervals)|r", #cmds))
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
local frame, greetingText, titleText, classIcon
local roleBtns = {}
local scrollFrame, scrollChild
local specDropdown

----------------------------- Refresh greeting text
local function RefreshGreeting()
    if not greetingText then return end
    greetingText:SetText("Target a player bot, pick a role, choose a spec, click APPLY.")

    -- Resize scroll child to fit content
    if scrollChild and scrollFrame then
        local textH = greetingText:GetStringHeight() or greetingText:GetHeight() or 30
        local neededH = math.max(textH + 20, SCROLL_H)
        scrollChild:SetHeight(neededH)
        scrollFrame:UpdateScrollChildRect()
    end
end

----------------------------- Spec dropdown init (called every time dropdown opens)
-- Classic 1.14 pattern: reuse a plain {} table — UIDropDownMenu_AddButton copies fields at call time.
-- UIDropDownMenu_CreateInfo() is NOT used because it may not exist or behave differently in Classic.
local function SpecDropdown_Initialize()
    local cf = frame._currentClassFile
    local role = BRS_Options.role
    local specs = GetSpecList(cf, role)

    if not specs or #specs == 0 then
        local info = {}
        if cf then
            info.text = "Role not available"
        else
            info.text = "Select one of your bots before click!"
        end
        info.disabled = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info)
        return
    end

    for _, spec in ipairs(specs) do
        local info = {}
        info.text = spec
        info.func = function()
            BRS_Options.spec = spec
            UIDropDownMenu_SetText(specDropdown, spec)
        end
        info.checked = (spec == BRS_Options.spec)
        info.notCheckable = false
        info.disabled = false
        UIDropDownMenu_AddButton(info)
    end
end

----------------------------- Refresh spec dropdown state
-- Validates the currently selected spec and updates the dropdown button text.
-- Called whenever class, role, or target changes.
local function RefreshSpecDropdown()
    if not specDropdown then return end

    local cf = frame._currentClassFile
    local role = BRS_Options.role
    local specs = GetSpecList(cf, role)

    if not specs or #specs == 0 then
        if cf then
            UIDropDownMenu_SetText(specDropdown, "Role not available")
        else
            UIDropDownMenu_SetText(specDropdown, "Select one of your bots before click!")
        end
        return
    end

    -- Keep current spec if it still exists in the list, otherwise default to first
    local current = BRS_Options.spec
    local found = false
    if current then
        for _, s in ipairs(specs) do
            if s == current then
                found = true
                break
            end
        end
    end

    if not found then
        BRS_Options.spec = specs[1]
    end

    UIDropDownMenu_SetText(specDropdown, BRS_Options.spec)
end

----------------------------- Refresh role button highlights + dropdown
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
    RefreshSpecDropdown()
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
        CloseDropDownMenus()
        RefreshHLRoles()
    end)
    return b
end

----------------------------- Refresh class display (icon + title)
local function UpdateClassDisplay()
    local unit = GetBotUnit()
    local name = GetUnitName(unit, true)
    local cf = nil
    if name and UnitExists(unit) and UnitIsPlayer(unit) then
        local _, classFile = UnitClass(unit)
        cf = classFile
    end

    if cf and CLASS_ICONS[cf] then
        local ci = CLASS_ICONS[cf]
        classIcon:SetTexture("Interface\\Icons\\" .. ci.icon)
        classIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- Re-apply crop after SetTexture
        titleText:SetText(name .. " (" .. ci.name .. ")")   -- "Botname (Class)"
        titleText:SetTextColor(1, 1, 1)                     -- White
    else
        classIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        classIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)       -- Crop fallback icon too
        titleText:SetText("Select your bot!")
        titleText:SetTextColor(1, 1, 1)                     -- White
    end
end

----------------------------- On target changed
function OnTargetChanged()
    CloseDropDownMenus()
    local unit = GetBotUnit()
    local n = GetUnitName(unit, true)
    if n and UnitExists(unit) and UnitIsPlayer(unit) then
        local cls, cf = UnitClass(unit)
        if cf and CLASS_ICONS[cf] then
            frame._currentClassFile = cf
        else
            frame._currentClassFile = nil
        end
    else
        frame._currentClassFile = nil
    end
    UpdateClassDisplay()
    RefreshHLRoles()
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

    -- Class icon with circular mask (like GossipFrame portrait)
    classIcon = frame:CreateTexture(nil, "BACKGROUND")
    classIcon:SetSize(56, 56)
    classIcon:SetPoint("TOPLEFT", 9, -8)
    classIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- Crop the built-in icon border

    -- Circular mask (pcall guard — CreateMaskTexture may not exist on all Classic builds)
    if frame.CreateMaskTexture then
        local ok, iconMask = pcall(frame.CreateMaskTexture, frame, nil, "ARTWORK")
        if ok and iconMask then
            pcall(iconMask.SetTexture, iconMask, "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            iconMask:SetAllPoints(classIcon)
            pcall(classIcon.AddMaskTexture, classIcon, iconMask)
        end
    end

    -- Title: bot name + class on one line (QuestFont, white, same style as greeting)
    titleText = frame:CreateFontString(nil, "OVERLAY", "QuestFont")
    titleText:SetPoint("TOP", frame, "TOP", 0, -25)
    titleText:SetJustifyH("CENTER")
    titleText:SetText("Select your bot!")

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
    greetingText:SetText("Target a player bot, pick a role, choose a spec, click APPLY.")

    -- Initial scroll child sizing
    scrollFrame:UpdateScrollChildRect()

    -- ============================================================
    -- Role buttons: TANK | HEALER | DPS (centered below scroll frame)
    -- ============================================================

    local roleDefs = {
        { k = "tank",   t = "Tank" },
        { k = "healer", t = "Healer" },
        { k = "dps",    t = "Dps" },
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
    -- SPEC DROPDOWN (replaces old static roleStatusText)
    -- UIDropDownMenuTemplate with global name required by FrameXML.
    -- Positioned between role buttons and APPLY button.
    -- ============================================================

    -- Positioned below role buttons using the SAME anchor as the buttons (guaranteed centering)
    specDropdown = CreateFrame("Frame", "BRSSpecDropdown", frame, "UIDropDownMenuTemplate")

    specDropdown:ClearAllPoints()
    -- Same anchor point as dps button (anchor.BOTTOM), placed further down
    -- dps button is at anchor.BOTTOM (0, -14), 24px tall → its bottom edge is at -38
    -- Dropdown goes 20px below the dps button bottom edge
    specDropdown:SetPoint("TOP", anchor, "BOTTOM", -25, -55)

    -- Set dropdown widths (fits inside the scroll area, centered like role buttons)
    UIDropDownMenu_SetWidth(specDropdown, 240)
    specDropdown:SetWidth(240)

    -- Register init function (called each time dropdown opens — dynamic content)
    UIDropDownMenu_Initialize(specDropdown, SpecDropdown_Initialize)

    -- Hide the original button completely (arrow + its textures)
    local ddButton = _G["BRSSpecDropdownButton"]
    if ddButton then
        ddButton:Hide()
    end

    -- Transparent overlay button: matches dropdown area exactly
    local overlay = CreateFrame("Button", nil, specDropdown)
    overlay:SetAllPoints(specDropdown)
    overlay:SetScript("OnClick", function()
        ToggleDropDownMenu(1, nil, specDropdown)
    end)

    -- ============================================================
    -- QUERY button (above APPLY — sends "talents" whisper to bot)
    -- ============================================================

    local queryBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    queryBtn:SetSize(120, 24)
    queryBtn:SetPoint("BOTTOM", scrollFrame, "BOTTOM", 0, 65)
    queryBtn:SetText("Query")
    queryBtn:SetScript("OnClick", function()
        local unit = GetBotUnit()
        local name = GetUnitName(unit, true)
        if name and UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
            SendChatMessage("talents", "WHISPER", nil, name)
            DEFAULT_CHAT_FRAME:AddMessage("|cff88ddff[BRS] Sent 'talents' to " .. name .. "|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[BRS] Select one of your bots before click!|r")
        end
    end)

    -- ============================================================
    -- APPLY button (anchored inside scroll frame area, near bottom)
    -- ============================================================

    local applyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    applyBtn:SetSize(120, 24)
    applyBtn:SetPoint("BOTTOM", scrollFrame, "BOTTOM", 0, 35)
    applyBtn:SetText("Apply")
    applyBtn:SetScript("OnClick", function()
        if not frame._currentClassFile then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[BRS] Target a player first!|r")
            return
        end
        if not CanRole(frame._currentClassFile, BRS_Options.role) then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[BRS] This class can't be " .. BRS_Options.role:upper() .. "!|r")
            return
        end
        if not BRS_Options.spec then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[BRS] No spec selected! Pick one from the dropdown.|r")
            return
        end
        local unit = GetBotUnit()
        local name = GetUnitName(unit, true)
        if not name then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[BRS] Lost target!|r")
            return
        end
        if UnitIsUnit(unit, "player") then
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
        BotRoleSetterFrame._autoUnit = nil  -- Manual target always overrides auto-select
        OnTargetChanged()
    end)

    DEFAULT_CHAT_FRAME:AddMessage("|cff88ddff[BotRoleSetter]|r /brs to toggle. Target a bot, pick role, choose spec, APPLY.")
end)
