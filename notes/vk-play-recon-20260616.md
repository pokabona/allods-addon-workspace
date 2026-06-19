# VK Play / Allods client findings - 2026-06-16

Scope: read-only scan of `C:\VK Play`.

## Valuable folders/files

- `C:\VK Play\Аллоды Онлайн\data\Mods\Docs\ModdingDocuments.zip`
  - Official user mod documentation.
  - Contains `ModdingDocuments/LuaApi/*.html` with categories, functions, events, enums.
  - Most valuable source for our local API database.
- `C:\VK Play\Аллоды Онлайн\data\Mods\SampleAddons`
  - Official sample addons: init, event registration, reaction handlers, zone announce.
  - Useful as clean examples for addon descriptor/form/event syntax.
- `C:\VK Play\Аллоды Онлайн\data\Mods\SampleCommon`
  - Official common widget/core scripts and button prototypes.
  - Useful for UI/widget work, less important for pure automation.
- `C:\VK Play\Аллоды Онлайн\data\Types\types.xml`
  - Type/resource schema metadata.
  - Useful for understanding XDB/resource structure, not runtime addon APIs.
- `C:\VK Play\Аллоды Онлайн\data\Mods\Addons`
  - Installed addons and real-world examples.
  - Useful for patterns, but noisy because it includes backups and old code.
- `C:\VK Play\Аллоды Онлайн\Personal\Logs\mods.txt`
  - Runtime truth for what is actually exported/working in this client.

## BagAutomation-relevant API

Docs confirm these are useful:

- `EVENT_CONTAINER_ITEM_ADDED`
- `EVENT_CONTAINER_ITEM_CHANGED`
- `EVENT_CONTAINER_ITEM_REMOVED`
- `EVENT_CONTAINER_CHANGED`
- `EVENT_INVENTORY_CHANGED`
- `EVENT_INVENTORY_SLOT_CHANGED`
- `containerLib.MoveItem(itemId, slotType, slot, count)`
- `containerLib.MoveSlotItem(slotTypeFrom, slotFrom, slotTypeTo, slotTo, count)`
- `containerLib.CheckMoveItem`
- `containerLib.CheckMoveSlotItem`
- `containerLib.GetItems`
- `containerLib.GetItem`
- `containerLib.GetSize`
- `itemLib.GetUsagesItemInfo`
- `itemLib.CanActivateForUseItem`
- `avatar.UseItem`
- `avatar.UseItemAndTakeActions`

Existing addons also use filtered events, for example:

```lua
common.RegisterEventHandler(OnAddItemToBag, "EVENT_CONTAINER_ITEM_ADDED", { slotType = ITEM_CONT_INVENTORY, isNewItem = true })
common.RegisterEventHandler(updateEquipped, "EVENT_CONTAINER_ITEM_CHANGED", { slotType = ITEM_CONT_EQUIPMENT_RITUAL, slot = 19 })
```

This is cleaner than reacting to every container change.

## Vendor/sell finding

Docs contain current vendor/buy functions:

- `avatar.RequestVendor()`
- `avatar.GetVendorList()`
- `avatar.GetVendorBuyback()`
- `avatar.IsInteractorVendor()`
- `avatar.Buy(objectId, quantity)`
- `avatar.BuyToSlot(objectId, quantity, slot)`
- `object.IsVendor(id)`
- `EVENT_VENDOR_LIST_UPDATED`
- vendor buy error events

Docs also mention drag-and-drop container type:

- `DND_VENDOR = 4`

But current Lua API docs do not contain a function page for `avatar.SellItemToVendor`.
It appears only in old changelog text. Runtime probe in this client showed:

- `avatar.SellItemToVendor type=nil`
- `containerLib.DropItem type=nil`
- `containerLib.OpenByInteractor type=nil`
- `containerLib.MoveSlotItem type=function`

Conclusion: direct safe autosell API is not currently available/exported. Possible remaining research path is DND/UI-based vendor drop, but that is likely fragile and should not go into stable BagAutomation yet.

## Practical next steps

- Import `ModdingDocuments.zip` into our local API knowledge/database as the primary docs source.
- Use docs + runtime logs together: docs show intended API, logs show what is actually exported.
- For BagAutomation, prefer filtered item events over broad `EVENT_CONTAINER_CHANGED` where possible.
- Keep vendor autosell out of stable addon until a real sell API or robust DND/vendor method is proven.
