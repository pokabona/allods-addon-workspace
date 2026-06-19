# Game Folders Recon - 2026-06-16

Checked folders:

- `C:\VK Play\Аллоды Онлайн\Profiles`
- `C:\VK Play\Аллоды Онлайн\Personal`
- `C:\VK Play\Аллоды Онлайн\data\Types`

## Useful Findings

### Personal

`Personal` is useful for addon/runtime diagnostics and per-character UI state.

Important files:

- `Personal\global.cfg`
- `Personal\user.cfg`
- `Personal\Logs\mods.txt`

Important `global.cfg` flags found:

```cfg
addon_diagnostics=0
disable_user_mods=0
user_mods_log_enable=1
```

Meaning:

- `user_mods_log_enable=1` enables addon logging to `mods.txt`.
- `addon_diagnostics=0` means extra addon diagnostics are disabled.
- `disable_user_mods=0` means user addons are allowed.

`user.cfg` contains per-character/per-profile UI and chat state, including:

- enabled addons under `UserAddon/...=true`;
- chat filters like `system_useraddon`, `system_useraddon_notice`, `system_useraddon_error`, `system_useraddon_warning`;
- window placements such as `ContextBag`, `ContextBuyPopup`, `Trade`.

This can explain why addon chat messages appear on some characters but not others: chat filters and UI settings can be character/profile-specific.

### Profiles

`Profiles` contains base client startup/config files:

- `autoexec.cfg`
- `system.cfg`
- `ui.cfg`
- `input.cfg`
- `client.cfg`
- etc.

No vendor/sell/addon API unlock setting was found there.

### data\Types

`data\Types\types.xml` describes resource/XDB/editor types, useful for understanding widgets/resources.

No runtime vendor/sell mechanism was found there.

## Vendor/Sell Status

Searches in these folders did not reveal a config flag that exposes item selling to addons.

Known runtime evidence from our knowledge base:

- `avatar.SellItemToVendor` exists in old/candidate/changelog-style API names.
- Runtime probe history marked it as `missingMember` in the current addon Lua environment.
- `containerLib.DropItem` and `containerLib.OpenByInteractor` were also previously marked as `missingMember` candidates.

Conclusion for now:

- Logging was enabled by a real config flag: `user_mods_log_enable=1`.
- Selling is different: no equivalent config flag was found yet.
- The next useful evidence should come from `ChatGPT_VendorSellProbe_v1.pak` while a vendor/trader window is actually open.

## Probe Added

Installed safe probe addon:

`C:\VK Play\Аллоды Онлайн\data\Mods\Addons\ChatGPT_VendorSellProbe_v1.pak`

It only logs availability/state. It does not sell, move, drop, or use items.

Expected next step:

1. Restart game.
2. Open vendor/trader.
3. Open bag near vendor.
4. Inspect `C:\VK Play\Аллоды Онлайн\Personal\Logs\mods.txt` for `[VendorSellProbe]` lines.