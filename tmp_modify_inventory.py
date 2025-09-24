import pathlib

path = pathlib.Path("src/server/Systems/InventoryService.luau")
text = path.read_text()
needle = "local function debugPrint(... )"
print('placeholder')
