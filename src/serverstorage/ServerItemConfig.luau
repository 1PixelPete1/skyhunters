return {
    items = {
        prod_basic_common = {
            class = "Producer",
            price = 50,
            rarity = "Common",
            obtainable = true,
            adminOnly = false,
            tags = { "basic" },
        },
        prod_basic_uncommon = {
            class = "Producer",
            price = 200,
            rarity = "Uncommon",
            obtainable = true,
            adminOnly = false,
            tags = { "basic" },
        },
        prod_basic_rare = {
            class = "Producer",
            price = 750,
            rarity = "Rare",
            obtainable = true,
            adminOnly = false,
            tags = { "basic" },
        },
        prod_basic_legendary = {
            class = "Producer",
            price = 3000,
            rarity = "Legendary",
            obtainable = true,
            adminOnly = false,
            tags = { "basic" },
        },
        prod_basic_admin = {
            class = "Producer",
            price = 0,
            rarity = "Mythic",
            obtainable = false,
            adminOnly = true,
            tags = { "basic" },
        },
    },
    rarityOrder = { "Common", "Uncommon", "Rare", "Legendary", "Mythic" },
}

