local ADDON_NAME = "AutoVendorHelper_v1"

local function logInfo(...)
	common.LogInfo(ADDON_NAME, ...)
end

local function safeItemName(itemId)
	local info = itemLib.GetItemInfo(itemId)
	if info and info.name then
		return info.name
	end
	return "<unknown item>"
end

local function scanInventoryForVendorSellables()
	local inventory = containerLib.GetItems(ITEM_CONT_INVENTORY)
	if not inventory then
		logInfo("Inventory is not available")
		return
	end

	local sellableCount = 0
	local estimatedSellValue = 0
	local preview = {}
	local previewLimit = 8

	for _, itemId in pairs(inventory) do
		if itemId then
			local priceInfo = itemLib.GetPriceInfo(itemId)
			if priceInfo and priceInfo.sellPrice and priceInfo.sellPrice > 0 then
				sellableCount = sellableCount + 1
				estimatedSellValue = estimatedSellValue + priceInfo.sellPrice
				if #preview < previewLimit then
					table.insert(preview, safeItemName(itemId))
				end
			end
		end
	end

	if sellableCount == 0 then
		logInfo("[Vendor] Sellable items: 0")
		return
	end

	logInfo("[Vendor] Sellable items: ", sellableCount, ", estimated value: ", estimatedSellValue)
	for i = 1, #preview do
		logInfo("[Vendor] #", i, " ", preview[i])
	end
	logInfo("[Vendor] Auto-sell action is not used in this addon")
end

function OnEventInteractionStarted()
	if avatar.IsInteractorVendor() then
		avatar.RequestVendor()
	end
end

function OnEventVendorListUpdated()
	scanInventoryForVendorSellables()
end

function Init()
	common.RegisterEventHandler(OnEventInteractionStarted, "EVENT_INTERACTION_STARTED")
	common.RegisterEventHandler(OnEventVendorListUpdated, "EVENT_VENDOR_LIST_UPDATED")
	logInfo("Loaded")
end

Init()
