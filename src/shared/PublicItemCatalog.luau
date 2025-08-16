local items = {
    prod_basic_common = {
        name = "Basic Producer",
        icon = "rbxassetid://0",
        displayPrice = 50,
        rarity = "Common",
    },
    prod_basic_uncommon = {
        name = "Sturdy Producer",
        icon = "rbxassetid://0",
        displayPrice = 200,
        rarity = "Uncommon",
    },
    prod_basic_rare = {
        name = "Rare Producer",
        icon = "rbxassetid://0",
        displayPrice = 750,
        rarity = "Rare",
    },
    prod_basic_legendary = {
        name = "Legendary Prod.",
        icon = "rbxassetid://0",
        displayPrice = 3000,
        rarity = "Legendary",
    },
}

return { items = items, rarityOrder = { "Common", "Uncommon", "Rare", "Legendary" } }

