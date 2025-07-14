-- ʕ •ᴥ•ʔ✿ Events · WoW event handling ✿ ʕ •ᴥ•ʔ
local AH = _G.AttuneHelper

-- Throttling variables
AH.deltaTime = 0
AH.CHAT_MSG_SYSTEM_THROTTLE = 0.2
AH.lastAutoEquipTime = 0
AH.AUTO_EQUIP_COOLDOWN = 2.0  -- ʕ •ᴥ•ʔ✿ Prevent spam equipping ✿ ʕ •ᴥ•ʔ

-- Session state variables
AH.isSCKLoaded = false
AH.cannotEquipOffHandWeaponThisSession = false
AH.lastAttemptedSlotForEquip = nil
AH.lastAttemptedItemTypeForEquip = nil

-- Export for legacy compatibility
_G.deltaTime = AH.deltaTime
_G.CHAT_MSG_SYSTEM_THROTTLE = AH.CHAT_MSG_SYSTEM_THROTTLE
_G.isSCKLoaded = AH.isSCKLoaded
_G.cannotEquipOffHandWeaponThisSession = AH.cannotEquipOffHandWeaponThisSession
_G.lastAttemptedSlotForEquip = AH.lastAttemptedSlotForEquip
_G.lastAttemptedItemTypeForEquip = AH.lastAttemptedItemTypeForEquip

-- ʕ •ᴥ•ʔ✿ Performance helper for auto-equip throttling ✿ ʕ •ᴥ•ʔ
function AH.ShouldTriggerAutoEquip()
    if AttuneHelperDB["Auto Equip Attunable After Combat"] ~= 1 then
        return false
    end
    
    local currentTime = GetTime()
    if currentTime - AH.lastAutoEquipTime < AH.AUTO_EQUIP_COOLDOWN then
        AH.print_debug_general("Auto-equip throttled (cooldown)")
        return false
    end
    
    return true
end

function AH.TriggerThrottledAutoEquip(delay)
    if not AH.ShouldTriggerAutoEquip() then return end
    
    delay = delay or 0.3
    AH.lastAutoEquipTime = GetTime()
    
    local equipButton = AH.UI.buttons and AH.UI.buttons.equipAll
    if equipButton and equipButton:GetScript("OnClick") then
        local fn = equipButton:GetScript("OnClick")
        AH.Wait(delay, fn)
    end
end

------------------------------------------------------------------------
-- UI Initialization
------------------------------------------------------------------------
function AH.InitializeUI()
    -- Create main frame first
    if AH.CreateMainFrame then
        AH.CreateMainFrame()
    end
    
    -- Create mini frame
    if AH.CreateMiniFrame then
        AH.CreateMiniFrame()
    end
    
    -- Create main buttons
    if AH.CreateMainButtons then
        AH.CreateMainButtons()
    end
    
    -- Create mini buttons
    if AH.CreateMiniButtons then
        AH.CreateMiniButtons()
    end
    
    -- Setup mini button handlers (after main buttons exist)
    if AH.SetupMiniButtonHandlers then
        AH.SetupMiniButtonHandlers()
    end
    
    -- Initialize options panels
    if AH.InitializeAllOptions then
        AH.InitializeAllOptions()
    end
    
    -- Register events now that UI is ready
    AH.RegisterEvents()
end

------------------------------------------------------------------------
-- Event registration
------------------------------------------------------------------------
function AH.RegisterEvents()
    if not AH.UI.mainFrame then return end
    
    AH.UI.mainFrame:RegisterEvent("ADDON_LOADED")
    AH.UI.mainFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    AH.UI.mainFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    AH.UI.mainFrame:RegisterEvent("PLAYER_LOGIN")
    AH.UI.mainFrame:RegisterEvent("BAG_UPDATE")
    AH.UI.mainFrame:RegisterEvent("UI_ERROR_MESSAGE")
    AH.UI.mainFrame:RegisterEvent("QUEST_COMPLETE")
    AH.UI.mainFrame:RegisterEvent("QUEST_TURNED_IN")
    AH.UI.mainFrame:RegisterEvent("LOOT_CLOSED")
    AH.UI.mainFrame:RegisterEvent("ITEM_PUSH")
    
    -- Set the event handler
    AH.UI.mainFrame:SetScript("OnEvent", AH.OnEvent)
end

------------------------------------------------------------------------
-- Event handler
------------------------------------------------------------------------
function AH.OnEvent(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "AttuneHelper" then
        print("|cff00ff00[AttuneHelper]|r ADDON_LOADED event fired, initializing...")
        AH.InitializeDefaultSettings()
        
        -- Check for SCK addon
        if _G["SCK"] and type(_G["SCK"].loop) == "function" then
            AH.isSCKLoaded = true
            AH.print_debug_general("SCK detected.")
        end
        
        -- Initialize UI components now that saved variables are loaded
        print("|cff00ff00[AttuneHelper]|r Initializing UI...")
        AH.InitializeUI()
        print("|cff00ff00[AttuneHelper]|r UI initialization complete.")
        
        if AH.LoadAllSettings then
            AH.LoadAllSettings()
        end
        
        -- Update display mode after everything is loaded
        if AH.UpdateDisplayMode then
            AH.Wait(0.1, AH.UpdateDisplayMode)
        end
        
        self:UnregisterEvent("ADDON_LOADED")
        
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        
        AH.Wait(1, function()
            if AH.LoadAllSettings then
                AH.LoadAllSettings()
            end
        end)
        
        AH.Wait(3, function()
            -- Only update regular bags, not bank
            for b = 0, 4 do
                if AH.UpdateBagCache then
                    AH.UpdateBagCache(b)
                end
            end
            if AH.UpdateItemCountText then
                AH.UpdateItemCountText()
            end
        end)
        
    elseif event == "BAG_UPDATE" then
        if not ItemLocIsLoaded() then
            return
        end
        
        -- Only update regular bags (0-4), skip bank bags (5+)
        if arg1 <= 4 then
            if AH.UpdateBagCache then
                AH.UpdateBagCache(arg1)
            end
            if AH.UpdateItemCountText then
                AH.UpdateItemCountText()
            end
        end
        
        -- ʕ •ᴥ•ʔ✿ Throttle BAG_UPDATE auto-equip to prevent spam ✿ ʕ •ᴥ•ʔ
        local nT = GetTime()
        if nT - (AH.deltaTime or 0) < AH.CHAT_MSG_SYSTEM_THROTTLE then
            return
        end
        AH.deltaTime = nT
        
        -- Only trigger auto-equip if throttle allows it
        AH.TriggerThrottledAutoEquip(InCombatLockdown() and 0.1 or 0.2)
        
    elseif event == "QUEST_COMPLETE" or event == "QUEST_TURNED_IN" then
        AH.print_debug_general("Quest event detected: " .. event .. ". Scheduling bag cache refresh.")
        
        AH.Wait(0.5, function()
            if AH.RefreshAllBagCaches then
                AH.RefreshAllBagCaches()
            end
            
            -- ʕ •ᴥ•ʔ✿ Quest rewards are significant, allow auto-equip ✿ ʕ •ᴥ•ʔ
            AH.TriggerThrottledAutoEquip(0.2)
        end)
        
    elseif event == "LOOT_CLOSED" then
        -- Sometimes loot doesn't trigger BAG_UPDATE properly
        AH.print_debug_general("Loot closed. Scheduling bag cache refresh.")
        
        AH.Wait(0.3, function()
            if AH.RefreshAllBagCaches then
                AH.RefreshAllBagCaches()
            end
            
            -- ʕ •ᴥ•ʔ✿ Only equip after loot if sufficient time has passed ✿ ʕ •ᴥ•ʔ
            AH.TriggerThrottledAutoEquip(0.3)
        end)
        
    elseif event == "ITEM_PUSH" then
        -- Item push events for items being added to bags
        AH.print_debug_general("Item push event detected. Scheduling bag cache refresh.")
        
        AH.Wait(0.2, function()
            if AH.RefreshAllBagCaches then
                AH.RefreshAllBagCaches()
            end
            
            -- ʕ •ᴥ•ʔ✿ ITEM_PUSH is very frequent, throttle heavily ✿ ʕ •ᴥ•ʔ
            AH.TriggerThrottledAutoEquip(0.1)
        end)
        
    elseif event == "PLAYER_REGEN_ENABLED" and AttuneHelperDB["Auto Equip Attunable After Combat"] == 1 then
        -- When leaving combat, do a full equip cycle with fresh cache
        AH.print_debug_general("Left combat. Refreshing cache and equipping.")
        
        AH.Wait(0.2, function()
            if AH.RefreshAllBagCaches then
                AH.RefreshAllBagCaches()
            end
            
            -- ʕ •ᴥ•ʔ✿ Combat end is important, bypass throttle ✿ ʕ •ᴥ•ʔ
            AH.lastAutoEquipTime = 0  -- Reset throttle
            local equipButton = AH.UI.buttons and AH.UI.buttons.equipAll
            if equipButton and equipButton:GetScript("OnClick") then
                local fn = equipButton:GetScript("OnClick")
                fn()
            end
        end)
        
        -- ʕ •ᴥ•ʔ✿ Periodic memory cleanup after combat ✿ ʕ •ᴥ•ʔ
        AH.Wait(2.0, function()
            if AH.CleanupCaches then
                AH.CleanupCaches()
            end
        end)
        
    elseif event == "UI_ERROR_MESSAGE" and arg1 == ERR_ITEM_CANNOT_BE_EQUIPPED then
        if AH.lastAttemptedSlotForEquip == "SecondaryHandSlot" and AH.IsWeaponTypeForOffHandCheck and AH.IsWeaponTypeForOffHandCheck(AH.lastAttemptedItemTypeForEquip) then
            AH.cannotEquipOffHandWeaponThisSession = true
        end
        AH.lastAttemptedSlotForEquip = nil
        AH.lastAttemptedItemTypeForEquip = nil
    end
end

------------------------------------------------------------------------
-- Initialize events system
------------------------------------------------------------------------
-- Create initial event frame to handle ADDON_LOADED
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", AH.OnEvent)

------------------------------------------------------------------------
-- Initialize events
------------------------------------------------------------------------
function AH.InitializeEvents()
    if AH.UI.mainFrame then
        AH.UI.mainFrame:SetScript("OnEvent", AH.OnEvent)
        AH.RegisterEvents()
    end
end

-- Events will be initialized after UI is created in ADDON_LOADED 