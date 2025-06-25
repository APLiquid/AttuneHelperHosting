-- ʕ •ᴥ•ʔ✿ Legacy compatibility layer ✿ ʕ •ᴥ•ʔ
-- This file provides backward compatibility for any external addons or scripts
-- that might reference the old global variables and functions.

-- Essential saved variables that must be initialized early
AHIgnoreList = AHIgnoreList or {}
AHSetList = AHSetList or {} -- Now stores itemName = "TargetSlotName"
AttuneHelperDB = AttuneHelperDB or {}

-- Get reference to the modular addon table
local AH = _G.AttuneHelper

-- Only set up legacy exports if the modular code is loaded
if AH then
    -- Legacy global exports for backward compatibility
    -- These point to the new modular functions but maintain the old global names

    -- Core functions (from core modules)
    _G.print_debug_general = AH.print_debug_general
    _G.print_debug = AH.print_debug_general -- Alias for backward compatibility
    _G.print_debug_ahset = AH.print_debug_ahset
    _G.print_debug_vendor_preview = AH.print_debug_vendor_preview
    _G.IsMythic = AH.IsMythic
    _G.GetItemIDFromLink = AH.GetItemIDFromLink
    _G.GetForgeLevelFromLink = AH.GetForgeLevelFromLink
    _G.tContains = AH.tContains
    _G.AH_wait = AH.Wait

    -- Bag and item functions (from gameplay modules)
    _G.UpdateBagCache = AH.UpdateBagCache
    _G.RefreshAllBagCaches = AH.RefreshAllBagCaches
    _G.UpdateItemCountText = AH.UpdateItemCountText
    _G.ItemIsActivelyLeveling = AH.ItemIsActivelyLeveling
    _G.ItemQualifiesForBagEquip = AH.ItemQualifiesForBagEquip
    _G.ShouldPrioritizeItem = AH.ShouldPrioritizeItem
    _G.CanEquipItemPolicyCheck = AH.CanEquipItemPolicyCheck
    _G.GetAttunableItemNamesList = AH.GetAttunableItemNamesList
    _G.performEquipAction = AH.performEquipAction
    _G.HideEquipPopups = AH.HideEquipPopups

    -- Vendor functions
    _G.GetQualifyingVendorItems = AH.GetQualifyingVendorItems
    _G.SellQualifiedItemsFromDialog = AH.SellQualifiedItemsFromDialog

    -- UI functions (from ui modules)
    _G.CreateButton = AH.CreateButton
    _G.CreateMiniIconButton = AH.CreateMiniIconButton
    _G.ApplyButtonTheme = AH.ApplyButtonTheme
    _G.CreateCheckbox = AH.CreateCheckbox
    _G.SaveAllSettings = AH.SaveAllSettings
    _G.LoadAllSettings = AH.LoadAllSettings
    _G.InitializeOptionCheckboxes = AH.InitializeOptionCheckboxes
    _G.InitializeForgeOptionCheckboxes = AH.InitializeForgeOptionCheckboxes
    _G.InitializeThemeOptions = AH.InitializeThemeOptions

    -- Settings and initialization
    _G.InitializeDefaultSettings = AH.InitializeDefaultSettings

    -- Legacy variables that external code might reference
    _G.currentAttunableItemCount = 0 -- This gets updated by the modular code
    _G.MYTHIC_MIN_ITEMID = AH.MYTHIC_MIN_ITEMID
    _G.FORGE_LEVEL_MAP = AH.FORGE_LEVEL_MAP
    _G.slotNumberMapping = AH.slotNumberMapping
    _G.itemTypeToUnifiedSlot = AH.itemTypeToUnifiedSlot
    _G.allInventorySlots = AH.allInventorySlots
    _G.slotAliases = AH.slotAliases
    _G.BgStyles = AH.BgStyles
    _G.themePaths = AH.themePaths

    -- Cache tables (these are managed by the modular code)
    _G.bagSlotCache = AH.bagSlotCache or {}
    _G.equipSlotCache = AH.equipSlotCache or {}

    -- UI element caches (managed by options module)
    _G.blacklist_checkboxes = AH.blacklist_checkboxes or {}
    _G.general_option_checkboxes = AH.general_option_checkboxes or {}
    _G.theme_option_controls = AH.theme_option_controls or {}
    _G.forge_type_checkboxes = AH.forge_type_checkboxes or {}

    -- Legacy frame references for backward compatibility
    local function SetupLegacyFrameReferences()
        if AH.UI then
            _G.AttuneHelper = AH.UI.mainFrame
            _G.AttuneHelperFrame = AH.UI.mainFrame
            _G.AttuneHelperMiniFrame = AH.UI.miniFrame
            
            if AH.UI.buttons then
                _G.EquipAllButton = AH.UI.buttons.equipAll
                _G.SortInventoryButton = AH.UI.buttons.sort
                _G.VendorAttunedButton = AH.UI.buttons.vendor
                _G.AttuneHelperEquipAllButton = AH.UI.buttons.equipAll
                _G.AttuneHelperSortInventoryButton = AH.UI.buttons.sort
                _G.AttuneHelperVendorAttunedButton = AH.UI.buttons.vendor
            end
            
            if AH.UI.miniButtons then
                _G.AttuneHelperMiniEquipButton = AH.UI.miniButtons.equip
                _G.AttuneHelperMiniSortButton = AH.UI.miniButtons.sort
                _G.AttuneHelperMiniVendorButton = AH.UI.miniButtons.vendor
            end
            
            if AH.UI.itemCountText then
                _G.AttuneHelperItemCountText = AH.UI.itemCountText
            end
        end
    end

    -- Legacy display mode function
    _G.AttuneHelper_UpdateDisplayMode = AH.UpdateDisplayMode

    -- Set up frame references when UI is ready
    if AH.UI and AH.UI.mainFrame then
        SetupLegacyFrameReferences()
    else
        -- Wait for UI to be initialized
        local legacyFrame = CreateFrame("Frame")
        legacyFrame:RegisterEvent("ADDON_LOADED")
        legacyFrame:SetScript("OnEvent", function(self, event, addonName)
            if addonName == "AttuneHelper" and AH.UI and AH.UI.mainFrame then
                SetupLegacyFrameReferences()
                self:UnregisterEvent("ADDON_LOADED")
      end
    end)
  end

    -- Ensure initialization happens
    if AH.InitializeDefaultSettings then
        AH.InitializeDefaultSettings()
    end

    -- Schedule display mode update
    if AH.Wait and AH.UpdateDisplayMode then
        AH.Wait(0.1, AH.UpdateDisplayMode)
    end

    -- ʕ •ᴥ•ʔ✿ Register slash commands ✿ ʕ •ᴥ•ʔ
    SLASH_ATTUNEHELPER1 = "/ah"
    SLASH_ATTUNEHELPER2 = "/attunehelper"
    SlashCmdList["ATTUNEHELPER"] = function(msg)
        if AH.SlashCommand then
            AH.SlashCommand(msg)
        end
    end

    -- ʕ •ᴥ•ʔ✿ Periodic memory cleanup to prevent excessive buildup ✿ ʕ •ᴥ•ʔ
    local function SchedulePeriodicCleanup()
        AH.Wait(300, function() -- Every 5 minutes
            if AH.CleanupCaches then
                AH.print_debug_general("Automatic periodic cleanup triggered")
                AH.CleanupCaches()
            end
            SchedulePeriodicCleanup() -- Reschedule
        end)
    end

    -- Start periodic cleanup after 60 seconds
    AH.Wait(60, SchedulePeriodicCleanup)
end 