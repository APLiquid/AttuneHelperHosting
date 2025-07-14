-- ʕ •ᴥ•ʔ✿ Core utility helpers ✿ ʕ •ᴥ•ʔ
local AH = _G.AttuneHelper
local flags = AH.flags or {}

------------------------------------------------------------------------
-- Session state helpers
------------------------------------------------------------------------
function AH.IsWeaponTypeForOffHandCheck(equipLoc)
    return equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND" or equipLoc == "INVTYPE_WEAPONOFFHAND"
end
_G.IsWeaponTypeForOffHandCheck = AH.IsWeaponTypeForOffHandCheck

------------------------------------------------------------------------
-- Table helpers
------------------------------------------------------------------------
function AH.tContains(tbl, val)
    if type(tbl) ~= "table" then return false end
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end
_G.tContains = AH.tContains -- legacy

------------------------------------------------------------------------
-- Item helpers
------------------------------------------------------------------------
function AH.GetItemIDFromLink(itemLink)
    if not itemLink then return nil end
    if not ItemLocIsLoaded() or not CustomExtractItemId then 
        local itemIdStr = string.match(itemLink, "item:(%d+)")
        return itemIdStr and tonumber(itemIdStr) or nil
    end
    return CustomExtractItemId(itemLink)
end
_G.GetItemIDFromLink = AH.GetItemIDFromLink

-- Convert FORGE_LEVEL_MAP value to 3-param API format (0–3)
function AH.ConvertForgeMapToApiParam(forgeLevelMapValue)
    local map = AH.FORGE_LEVEL_MAP
    if forgeLevelMapValue == map.TITANFORGED then return 1
    elseif forgeLevelMapValue == map.WARFORGED then return 2
    elseif forgeLevelMapValue == map.LIGHTFORGED then return 3
    end
    return 0
end
_G.ConvertForgeMapToApiParam = AH.ConvertForgeMapToApiParam

-- Uses Blizzard's (or custom) API to resolve forge level for a link
function AH.GetForgeLevelFromLink(itemLink)
    if not itemLink then return AH.FORGE_LEVEL_MAP.BASE end
    if _G.GetItemLinkTitanforge then
        local forgeValue = GetItemLinkTitanforge(itemLink)
        -- Validate against known values
        for _, v in pairs(AH.FORGE_LEVEL_MAP) do
            if forgeValue == v then return forgeValue end
        end
        AH.print_debug_general("GetForgeLevelFromLink: unexpected value "..tostring(forgeValue))
    else
        AH.print_debug_general("GetForgeLevelFromLink: API not available/disabled")
    end
    return AH.FORGE_LEVEL_MAP.BASE
end
_G.GetForgeLevelFromLink = AH.GetForgeLevelFromLink

-- Determine if an item is Mythic by any means available
function AH.IsMythic(itemID)
    if not itemID then return false end
    -- Primary: bitmask via GetItemTagsCustom
    if GetItemTagsCustom then
        local tags = GetItemTagsCustom(itemID)
        if tags then return bit.band(tags, 0x80) ~= 0 end
    end
    -- Fallback: numeric threshold
    if itemID >= AH.MYTHIC_MIN_ITEMID then return true end
    return false
end
_G.IsMythic = AH.IsMythic

------------------------------------------------------------------------
-- ʕ •ᴥ•ʔ✿ Optimized Wait helper with memory management ✿ ʕ •ᴥ•ʔ
------------------------------------------------------------------------
local waitTable = setmetatable({}, {__mode = "k"})  -- Weak keys for memory efficiency
local waitFrame = nil
local lastWaitCleanup = 0
local WAIT_CLEANUP_INTERVAL = 60  -- Clean every 60 seconds

function AH.Wait(delay, func, ...)
    if type(delay) ~= "number" or type(func) ~= "function" then return false end
    
    if not waitFrame then
        waitFrame = CreateFrame("Frame", nil, UIParent)
        waitFrame:SetScript("OnUpdate", function(_, elapsed)
            local currentTime = GetTime()
            
            -- Periodic cleanup to prevent memory accumulation
            if currentTime - lastWaitCleanup > WAIT_CLEANUP_INTERVAL then
                local oldCount = #waitTable
                -- Remove completed/invalid entries
                for i = #waitTable, 1, -1 do
                    local rec = waitTable[i]
                    if not rec or not rec[2] then
                        table.remove(waitTable, i)
                    end
                end
                local newCount = #waitTable
                if oldCount ~= newCount then
                    AH.print_debug_general(string.format("Wait table cleaned: %d -> %d entries", oldCount, newCount))
                end
                lastWaitCleanup = currentTime
            end
            
            local i = 1
            while i <= #waitTable do
                local rec = waitTable[i]
                if rec then
                    local d, f, params = rec[1], rec[2], rec[3]
                    if d > elapsed then
                        rec[1] = d - elapsed  -- Update delay in-place
                        i = i + 1
                    else
                        table.remove(waitTable, i)
                        -- Execute with pcall for safety
                        local success, err = pcall(f, unpack(params or {}))
                        if not success then
                            AH.print_debug_general("Wait function error: " .. tostring(err))
                        end
                    end
                else
                    table.remove(waitTable, i)
                end
            end
        end)
    end
    
    table.insert(waitTable, { delay, func, { ... } })
    return true
end
_G.AH_wait = AH.Wait -- maintain original global name

------------------------------------------------------------------------
-- Settings initialization
------------------------------------------------------------------------
function AH.InitializeDefaultSettings()
    if AttuneHelperDB["Background Style"] == nil then AttuneHelperDB["Background Style"] = "Tooltip" end
    if type(AttuneHelperDB["Background Color"]) ~= "table" or #AttuneHelperDB["Background Color"] < 4 then 
        AttuneHelperDB["Background Color"] = {0, 0, 0, 0.8} 
    end
    if AttuneHelperDB["Button Color"] == nil then AttuneHelperDB["Button Color"] = {1, 1, 1, 1} end
    if AttuneHelperDB["Button Theme"] == nil then AttuneHelperDB["Button Theme"] = "Normal" end
    if AttuneHelperDB["Disable Auto-Equip Mythic BoE"] == nil then AttuneHelperDB["Disable Auto-Equip Mythic BoE"] = 1 end
    if AttuneHelperDB["Auto Equip Attunable After Combat"] == nil then AttuneHelperDB["Auto Equip Attunable After Combat"] = 0 end
    if AttuneHelperDB["Equip BoE Bountied Items"] == nil then AttuneHelperDB["Equip BoE Bountied Items"] = 0 end
    if AttuneHelperDB["Mini Mode"] == nil then AttuneHelperDB["Mini Mode"] = 0 end
    if AttuneHelperDB["FramePosition"] == nil then AttuneHelperDB["FramePosition"] = { "CENTER", UIParent, "CENTER", 0, 0 } end
    if AttuneHelperDB["MiniFramePosition"] == nil then AttuneHelperDB["MiniFramePosition"] = { "CENTER", UIParent, "CENTER", 0, 0 } end
    if AttuneHelperDB["Disable Two-Handers"] == nil then AttuneHelperDB["Disable Two-Handers"] = 0 end
    if AttuneHelperDB["Language"] == nil then AttuneHelperDB["Language"] = "default" end
	if AttuneHelperDB["Do Not Sell Grey And White Items"] == nil then AttuneHelperDB["Do Not Sell Grey And White Items"] = 1 end

    -- Handle legacy setting migration
    if AttuneHelperDB["EquipUntouchedVariants"] ~= nil and AttuneHelperDB["EquipNewAffixesOnly"] == nil then
        AttuneHelperDB["EquipNewAffixesOnly"] = AttuneHelperDB["EquipUntouchedVariants"]
        AH.print_debug_general("AttuneHelper: Migrated old setting 'EquipUntouchedVariants' to 'EquipNewAffixesOnly'.")
    end
    AttuneHelperDB["EquipUntouchedVariants"] = nil

    if AttuneHelperDB["EquipNewAffixesOnly"] == nil then AttuneHelperDB["EquipNewAffixesOnly"] = 0 end

    -- Handle renaming of EnableVendorPreview to EnableVendorSellConfirmationDialog
    if AttuneHelperDB["EnableVendorPreview"] ~= nil and AttuneHelperDB["EnableVendorSellConfirmationDialog"] == nil then
        AttuneHelperDB["EnableVendorSellConfirmationDialog"] = AttuneHelperDB["EnableVendorPreview"]
        AH.print_debug_general("AttuneHelper: Migrated old setting 'EnableVendorPreview' to 'EnableVendorSellConfirmationDialog'.")
    end
    AttuneHelperDB["EnableVendorPreview"] = nil -- Remove old key

    -- Initialize forge types
    if type(AttuneHelperDB.AllowedForgeTypes) ~= "table" then
        AttuneHelperDB.AllowedForgeTypes = {}
        local defaultForgeKeysAndValues = AH.defaultForgeKeysAndValues or { BASE = true, TITANFORGED = true, WARFORGED = true, LIGHTFORGED = true }
        for keyName, defaultValue in pairs(defaultForgeKeysAndValues) do 
            AttuneHelperDB.AllowedForgeTypes[keyName] = defaultValue 
        end
    end
    
    -- Initialize general options
    local generalOptionDefaults = {
        ["Sell Attuned Mythic Gear?"] = 0, 
        ["Auto Equip Attunable After Combat"] = 0, 
        ["Do Not Sell BoE Items"] = 1,
		["Do Not Sell Grey And White Items"] = 1,
        ["Limit Selling to 12 Items?"] = 0, 
        ["Disable Auto-Equip Mythic BoE"] = 1, 
        ["Equip BoE Bountied Items"] = 0,
        ["Mini Mode"] = 0, 
        ["EquipNewAffixesOnly"] = 0, 
        ["Prioritize Low iLvl for Auto-Equip"] = 1,
        ["EnableVendorSellConfirmationDialog"] = 1,
        ["Use Bag 1 for Disenchant"] = 0,  -- ʕ •ᴥ•ʔ✿ Use bag 0 by default ✿ ʕ •ᴥ•ʔ
        -- ʕ •ᴥ•ʔ✿ Weapon type control options ✿ ʕ •ᴥ•ʔ
        ["Allow MainHand 1H Weapons"] = 1,
        ["Allow MainHand 2H Weapons"] = 1,
        ["Allow OffHand 1H Weapons"] = 1,
        ["Allow OffHand 2H Weapons"] = 0,  -- Disabled by default
        ["Allow OffHand Shields"] = 1,
        ["Allow OffHand Holdables"] = 1
    }
    for optName, defValue in pairs(generalOptionDefaults) do
        if AttuneHelperDB[optName] == nil then 
            AttuneHelperDB[optName] = defValue 
        end
    end
    
    -- ʕ •ᴥ•ʔ✿ Initialize blacklist defaults (all slots enabled by default) ✿ ʕ •ᴥ•ʔ
    local blacklistDefaults = {
        ["HeadSlot"] = 0, ["NeckSlot"] = 0, ["ShoulderSlot"] = 0, ["BackSlot"] = 0,
        ["ChestSlot"] = 0, ["WristSlot"] = 0, ["HandsSlot"] = 0, ["WaistSlot"] = 0,
        ["LegsSlot"] = 0, ["FeetSlot"] = 0, ["Finger0Slot"] = 0, ["Finger1Slot"] = 0,
        ["Trinket0Slot"] = 0, ["Trinket1Slot"] = 0, ["MainHandSlot"] = 0, 
        ["SecondaryHandSlot"] = 0, ["RangedSlot"] = 0
    }
    for slotName, defValue in pairs(blacklistDefaults) do
        if AttuneHelperDB[slotName] == nil then 
            AttuneHelperDB[slotName] = defValue 
        end
    end
    
    -- ʕ •ᴥ•ʔ✿ Force settings restoration message ✿ ʕ •ᴥ•ʔ
    print("|cff00ff00[AttuneHelper]|r Settings have been restored to safe defaults.")
end
_G.InitializeDefaultSettings = AH.InitializeDefaultSettings

------------------------------------------------------------------------
-- ʕ •ᴥ•ʔ✿ Blacklist management ✿ ʕ •ᴥ•ʔ
------------------------------------------------------------------------
function AH.ToggleSlotBlacklist(slotName)
    if not slotName then return end
    
    -- Toggle the blacklist status
    AttuneHelperDB[slotName] = 1 - (AttuneHelperDB[slotName] or 0)
    
    local status = (AttuneHelperDB[slotName] == 1) and "blacklisted" or "unblacklisted"
    print(string.format("|cffffd200[AH]|r %s %s.", slotName, status))
    
    -- Force save the setting
    AH.ForceSaveSettings()
end
_G.ToggleSlotBlacklist = AH.ToggleSlotBlacklist
