-- ʕ •ᴥ•ʔ✿ Gameplay · Bag cache & item counts ✿ ʕ •ᴥ•ʔ
local AH = _G.AttuneHelper

-- ʕ •ᴥ•ʔ✿ Weak table optimizations for memory management ✿ ʕ •ᴥ•ʔ
AH.bagSlotCache   = AH.bagSlotCache   or setmetatable({}, {__mode = "v"})
AH.equipSlotCache = AH.equipSlotCache or setmetatable({}, {__mode = "v"})

-- ʕ •ᴥ•ʔ✿ GetItemInfo cache with weak references to reduce memory bloat ✿ ʕ •ᴥ•ʔ
AH.itemInfoCache = AH.itemInfoCache or setmetatable({}, {__mode = "v"})
AH.lastItemInfoCleanup = AH.lastItemInfoCleanup or 0
AH.ITEMINFO_CACHE_CLEANUP_INTERVAL = 30 -- Clean every 30 seconds

local bagSlotCache   = AH.bagSlotCache
local equipSlotCache = AH.equipSlotCache

-- ʕ •ᴥ•ʔ✿ Cached GetItemInfo to prevent expensive repeated API calls ✿ ʕ •ᴥ•ʔ
local function GetCachedItemInfo(link)
    if not link then return nil end
    
    -- Clean cache periodically
    local currentTime = GetTime()
    if currentTime - AH.lastItemInfoCleanup > AH.ITEMINFO_CACHE_CLEANUP_INTERVAL then
        AH.itemInfoCache = setmetatable({}, {__mode = "v"})
        AH.lastItemInfoCleanup = currentTime
        AH.print_debug_general("ItemInfo cache cleaned")
    end
    
    if not AH.itemInfoCache[link] then
        local name, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
        if name then
            AH.itemInfoCache[link] = {name, equipLoc}
        elseif not name then
            local id = CustomExtractItemId(link)
            local name, _, _, _, _, _, _, _, equipLoc = GetItemInfoCustom(id) -- prob fine to cache this like this
            AH.itemInfoCache[link] = {name, equipLoc}
        end
    end
    
    local cached = AH.itemInfoCache[link]
    return cached and cached[1], cached and cached[2]
end

------------------------------------------------------------------------
-- UpdateBagCache(bagID)
-- stores the results in AH.bagSlotCache / AH.equipSlotCache.
------------------------------------------------------------------------
function AH.UpdateBagCache(bagID)
    -- Skip bank bags (5-11 on WotLK)
    if bagID >= 5 then
        AH.print_debug_general("UpdateBagCache: Skipping bank bag " .. bagID)
        return
    end

    -- ʕ •ᴥ•ʔ✿ Efficient cleanup of old records ✿ ʕ •ᴥ•ʔ
    local oldRecords = bagSlotCache[bagID]
    if oldRecords then
        for _, rec in pairs(oldRecords) do
            local rawInvType = rec.equipSlot
            local unifiedKeys = AH.itemTypeToUnifiedSlot[rawInvType]
            if unifiedKeys then
                if type(unifiedKeys) == "string" then
                    local list = equipSlotCache[unifiedKeys]
                    if list then
                        for i = #list, 1, -1 do if list[i] == rec then table.remove(list, i) end end
                    end
                elseif type(unifiedKeys) == "table" then
                    for _, key in ipairs(unifiedKeys) do
                        local list = equipSlotCache[key]
                        if list then
                            for i = #list, 1, -1 do if list[i] == rec then table.remove(list, i) end end
                        end
                    end
                end
            end
        end
    end

    bagSlotCache[bagID] = {}

    -- Iterate slots in this bag
    for slotID = 1, GetContainerNumSlots(bagID) do
        local link = GetContainerItemLink(bagID, slotID)
        if link then
            -- ʕ •ᴥ•ʔ✿ Use cached GetItemInfo to save memory and CPU ✿ ʕ •ᴥ•ʔ
            local name, equipLoc = GetCachedItemInfo(link)
            if name and equipLoc and equipLoc ~= "" then
                local unified = AH.itemTypeToUnifiedSlot[equipLoc]
                if unified then
                    local itemID = AH.GetItemIDFromLink(link)
                    local canPlayerAttune = false
                    if itemID and _G.CanAttuneItemHelper then
                        canPlayerAttune = (CanAttuneItemHelper(itemID) == 1)
                    end

                    local inSet = (AHSetList and AHSetList[name] ~= nil)

                    if canPlayerAttune or inSet then
                        -- ʕ •ᴥ•ʔ✿ Minimal record structure to save memory ✿ ʕ •ᴥ•ʔ
                        local rec = {
                            bag       = bagID,
                            slot      = slotID,
                            link      = link,
                            name      = name,
                            equipSlot = equipLoc,
                            isAttunable = canPlayerAttune,
                            inSet       = inSet,
                        }
                        bagSlotCache[bagID][slotID] = rec

                        local function insertRec(key)
                            equipSlotCache[key] = equipSlotCache[key] or {}
                            table.insert(equipSlotCache[key], rec)
                        end

                        if type(unified) == "string" then
                            insertRec(unified)
                        elseif type(unified) == "table" then
                            for _, k in ipairs(unified) do insertRec(k) end
                        end
                    end
                end
            end
        end
    end
end
_G.UpdateBagCache = AH.UpdateBagCache

------------------------------------------------------------------------
function AH.RefreshAllBagCaches()
    if not ItemLocIsLoaded() then return end
    AH.print_debug_general("RefreshAllBagCaches: refreshing all (bags 0-4)")
    for b = 0, 4 do AH.UpdateBagCache(b) end
    if AH.UpdateItemCountText then AH.UpdateItemCountText() end
end
_G.RefreshAllBagCaches = AH.RefreshAllBagCaches

------------------------------------------------------------------------
-- ʕ •ᴥ•ʔ✿ Optimized item count calculation with caching ✿ ʕ •ᴥ•ʔ
------------------------------------------------------------------------
AH.cachedItemCount = 0
AH.lastItemCountUpdate = 0
AH.ITEM_COUNT_CACHE_DURATION = 0.5  -- Cache for 0.5 seconds

function AH.UpdateItemCountText()
    local currentTime = GetTime()
    
    -- Use cached value if recent
    if currentTime - AH.lastItemCountUpdate < AH.ITEM_COUNT_CACHE_DURATION then
        if AttuneHelperItemCountText then
            AttuneHelperItemCountText:SetText("Attunables in Inventory: "..AH.cachedItemCount)
        end
        return
    end
    
    local count = 0
    if ItemLocIsLoaded() then
        local strict = (AttuneHelperDB["EquipNewAffixesOnly"] == 1)
        for _, bagTbl in pairs(bagSlotCache) do
            if bagTbl then
                for _, rec in pairs(bagTbl) do
                    if rec and rec.isAttunable then
                        local itemId = AH.GetItemIDFromLink(rec.link)
                        if itemId and AH.ItemQualifiesForBagEquip(itemId, rec.link, strict) then
                            count = count + 1
                        end
                    end
                end
            end
        end
    end
    
    AH.cachedItemCount = count
    AH.lastItemCountUpdate = currentTime
    currentAttunableItemCount = count -- keep legacy global up to date
    
    if AttuneHelperItemCountText then
        AttuneHelperItemCountText:SetText("Attunables in Inventory: "..count)
    end
end
_G.UpdateItemCountText = AH.UpdateItemCountText

------------------------------------------------------------------------
-- ʕ •ᴥ•ʔ✿ Memory management utilities ✿ ʕ •ᴥ•ʔ
------------------------------------------------------------------------
function AH.ForceGarbageCollection()
    collectgarbage("collect")
end

function AH.GetMemoryUsage()
    local beforeGC = collectgarbage("count")
    collectgarbage("collect")
    local afterGC = collectgarbage("count")
    return afterGC, beforeGC - afterGC
end

function AH.CleanupCaches()
    -- Clear item info cache
    AH.itemInfoCache = setmetatable({}, {__mode = "v"})
    AH.ForceGarbageCollection()
    
    local memAfter, memFreed = AH.GetMemoryUsage()
end

-- Export memory utilities
_G.AH_CleanupCaches = AH.CleanupCaches
_G.AH_GetMemoryUsage = AH.GetMemoryUsage 