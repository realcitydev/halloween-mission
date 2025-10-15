Config = {}

Config.NPC = {
    model = "cs_bradcadaver",
    coords = vector4(-1680.9419, -291.2061, 51.8835, 234.2983),
    blip = {
        enabled = true,
        sprite = 484,
        color = 47,
        scale = 0.8,
        name = "Evento Halloween"
    }
}

Config.Mission = {
    pumpkinsToCollect = 5,
    timeLimit = 600,
    rewards = {
        money = 5000
    },
    rewardPerPumpkin = {
        pumpkins = 1
    }
}

Config.Exchange = {
    {
        label = "Dinero ($10,000)",
        icon = "fas fa-dollar-sign",
        iconColor = "#2ecc71",
        pumpkinsRequired = 10,
        reward = {
            type = "money",
            amount = 10000
        }
    },
    {
        label = "Arma Especial",
        icon = "fas fa-gun",
        iconColor = "#e74c3c",
        pumpkinsRequired = 15,
        reward = {
            type = "weapon",
            weapon = "WEAPON_ASSAULTRIFLE",
            ammo = 250
        }
    },
    {
        label = "Pack de Items",
        icon = "fas fa-box",
        iconColor = "#3498db",
        pumpkinsRequired = 8,
        reward = {
            type = "items",
            items = {
                {name = "bread", amount = 10},
                {name = "water", amount = 10}
            }
        }
    }
}

Config.Vehicle = {
    model = "sanctus",
    coords = vector4(-1679.4551, -296.7683, 51.8120, 143.4243),
    plate = "HALLOW"
}

Config.Clothing = {
    male = {
        mask = {drawable = 205, texture = 0},      -- Máscara
        torso = {drawable = 4, texture = 0},      -- Torso/Brazos (Componente 3)
        legs = {drawable = 200, texture = 0},      -- Pantalones
        bag = {drawable = 0, texture = 0},         -- Bolsa/Mochila
        shoes = {drawable = 80, texture = 0},      -- Zapatos
        accessory = {drawable = 0, texture = 0},   -- Accesorios (cadenas, collares)
        undershirt = {drawable = 15, texture = 0}, -- Camiseta interior
        kevlar = {drawable = 0, texture = 0},      -- Chaleco antibalas
        torso2 = {drawable = 539, texture = 0}     -- Chaqueta/Torso principal (Componente 11)
    },
    female = {
        mask = {drawable = 0, texture = 0},        -- Máscara
        torso = {drawable = 15, texture = 0},      -- Torso/Brazos (Componente 3)
        legs = {drawable = 0, texture = 0},        -- Pantalones
        bag = {drawable = 0, texture = 0},         -- Bolsa/Mochila
        shoes = {drawable = 80, texture = 0},      -- Zapatos
        accessory = {drawable = 0, texture = 0},   -- Accesorios (cadenas, collares)
        undershirt = {drawable = 0, texture = 0},  -- Camiseta interior
        kevlar = {drawable = 0, texture = 0},      -- Chaleco antibalas
        torso2 = {drawable = 0, texture = 0}       -- Chaqueta/Torso principal (Componente 11)
    }
}

Config.PumpkinLocations = {
    vector3(204.9, -933.3, 30.7),
--    vector3(-426.1, 1123.7, 325.9),
--    vector3(2565.2, 4680.9, 34.1),
--    vector3(-1037.5, -2737.9, 20.2),
--    vector3(1692.5, 4829.6, 42.1),
--    vector3(-1552.5, -546.8, 34.9),
--    vector3(1981.2, 3053.1, 47.2),
--    vector3(-3163.8, 1095.3, 20.7)
}

Config.Zombies = {
    amount = 5,
    spawnRadius = 8,
    attackDistance = 30,
    models = {
        "u_m_y_zombie_01",
        "s_m_y_clown_01",
        "s_m_m_movalien_01",
        "u_m_m_jesus_01",
        "a_m_y_hipster_01"
    },
    damagePerSecond = 5,
    damageDistance = 2.0
}

Config.Effects = {
    zoneRadius = 60,
    lightColor = {255, 100, 0},
    lightRange = 40.0,
    lightIntensity = 8.0
}

