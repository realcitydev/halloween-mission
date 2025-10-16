ESX = exports['es_extended']:getSharedObject()

local halloweenLobbies = {}
local playerLobbies = {}
local vehicleSpawnCount = {}

RegisterServerEvent('halloween:collectPumpkin')
AddEventHandler('halloween:collectPumpkin', function()
    local src = source
    
    local canCarry = exports.ox_inventory:CanCarryItem(src, 'pumpkin', Config.Mission.rewardPerPumpkin.pumpkins)
    if not canCarry then
        TriggerClientEvent('esx:showNotification', src, 'No tienes espacio en el inventario')
        return
    end
    
    exports.ox_inventory:AddItem(src, 'pumpkin', Config.Mission.rewardPerPumpkin.pumpkins)
    
    TriggerClientEvent('chat:addMessage', src, { 
        args = {"Halloween", "Recibiste " .. Config.Mission.rewardPerPumpkin.pumpkins .. " calabaza"} 
    })
end)

RegisterServerEvent('halloween:completeMission')
AddEventHandler('halloween:completeMission', function(pumpkinsCollected)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    TriggerClientEvent('chat:addMessage', src, { 
        args = {"Halloween", string.format("Misión completada! Recolectaste %d calabazas", pumpkinsCollected)} 
    })
end)

RegisterServerEvent('halloween:claimReward')
AddEventHandler('halloween:claimReward', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    xPlayer.addMoney(Config.Mission.rewards.money)
    
    TriggerClientEvent('chat:addMessage', src, { 
        args = {"Halloween", string.format("Gracias por ayudarme! Aquí tienes tu recompensa: $%d", Config.Mission.rewards.money)} 
    })
end)

ESX.RegisterServerCallback('halloween:getPumpkinCount', function(source, cb)
    local pumpkinCount = exports.ox_inventory:GetItemCount(source, 'pumpkin')
    cb(pumpkinCount or 0)
end)

RegisterServerEvent('halloween:exchange')
AddEventHandler('halloween:exchange', function(exchangeId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local exchange = Config.Exchange[exchangeId]
    if not exchange then return end
    
    local pumpkinCount = exports.ox_inventory:GetItemCount(src, 'pumpkin')
    
    if pumpkinCount < exchange.pumpkinsRequired then
        TriggerClientEvent('esx:showNotification', src, 'No tienes suficientes calabazas')
        return
    end
    
    local removed = exports.ox_inventory:RemoveItem(src, 'pumpkin', exchange.pumpkinsRequired)
    if not removed then
        TriggerClientEvent('esx:showNotification', src, 'Error al procesar el intercambio')
        return
    end
    
    if exchange.reward.type == "money" then
        xPlayer.addMoney(exchange.reward.amount)
        TriggerClientEvent('esx:showNotification', src, 'Recibiste $' .. exchange.reward.amount)
    elseif exchange.reward.type == "weapon" then
        exports.ox_inventory:AddItem(src, exchange.reward.weapon, 1, {ammo = exchange.reward.ammo})
        TriggerClientEvent('esx:showNotification', src, 'Recibiste un arma especial')
    elseif exchange.reward.type == "items" then
        for _, item in ipairs(exchange.reward.items) do
            exports.ox_inventory:AddItem(src, item.name, item.amount)
        end
        TriggerClientEvent('esx:showNotification', src, 'Recibiste un pack de items')
    end
end)

RegisterServerEvent('halloween:createLobby')
AddEventHandler('halloween:createLobby', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    if playerLobbies[src] then
        TriggerClientEvent('esx:showNotification', src, 'Ya estás en un lobby')
        return
    end
    
    local lobbyId = 'lobby_' .. src .. '_' .. os.time()
    halloweenLobbies[lobbyId] = {
        leader = src,
        players = {src},
        createdAt = os.time()
    }
    
    playerLobbies[src] = lobbyId
    vehicleSpawnCount[lobbyId] = 0
    
    TriggerClientEvent('halloween:lobbyCreated', src, lobbyId, {src})
end)

RegisterServerEvent('halloween:joinLobby')
AddEventHandler('halloween:joinLobby', function(lobbyId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    if playerLobbies[src] then
        TriggerClientEvent('esx:showNotification', src, 'Ya estás en un lobby')
        return
    end
    
    local lobby = halloweenLobbies[lobbyId]
    if not lobby then
        TriggerClientEvent('esx:showNotification', src, 'El lobby no existe')
        return
    end
    
    if #lobby.players >= Config.Mission.maxPlayersInLobby then
        TriggerClientEvent('esx:showNotification', src, 'El lobby está lleno')
        return
    end
    
    table.insert(lobby.players, src)
    playerLobbies[src] = lobbyId
    
    local playerName = xPlayer.getName()
    
    for _, playerId in ipairs(lobby.players) do
        if playerId ~= src then
            TriggerClientEvent('halloween:lobbyUpdated', playerId, lobby.players, playerName)
        else
            TriggerClientEvent('halloween:lobbyUpdated', playerId, lobby.players, nil)
        end
    end
    
    TriggerClientEvent('halloween:joinedLobby', src, lobbyId, lobby.players)
end)

RegisterServerEvent('halloween:leaveLobby')
AddEventHandler('halloween:leaveLobby', function(lobbyId)
    local src = source
    local lobby = halloweenLobbies[lobbyId]
    if not lobby then return end
    
    for i, playerId in ipairs(lobby.players) do
        if playerId == src then
            table.remove(lobby.players, i)
            break
        end
    end
    
    playerLobbies[src] = nil
    
    if lobby.leader == src then
        halloweenLobbies[lobbyId] = nil
        vehicleSpawnCount[lobbyId] = nil
        for _, playerId in ipairs(lobby.players) do
            playerLobbies[playerId] = nil
            TriggerClientEvent('halloween:lobbyUpdated', playerId, {})
            TriggerClientEvent('esx:showNotification', playerId, 'El líder disolvió el lobby')
        end
    else
        for _, playerId in ipairs(lobby.players) do
            TriggerClientEvent('halloween:lobbyUpdated', playerId, lobby.players)
        end
    end
end)

RegisterServerEvent('halloween:dissolveLobby')
AddEventHandler('halloween:dissolveLobby', function(lobbyId)
    local src = source
    local lobby = halloweenLobbies[lobbyId]
    if not lobby or lobby.leader ~= src then return end
    
    halloweenLobbies[lobbyId] = nil
    vehicleSpawnCount[lobbyId] = nil
    
    for _, playerId in ipairs(lobby.players) do
        playerLobbies[playerId] = nil
        TriggerClientEvent('halloween:lobbyUpdated', playerId, {})
        if playerId ~= src then
            TriggerClientEvent('esx:showNotification', playerId, 'El líder disolvió el lobby')
        end
    end
end)

RegisterServerEvent('halloween:findNearbyLobbies')
AddEventHandler('halloween:findNearbyLobbies', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local nearbyLobbies = {}
    
    for lobbyId, lobby in pairs(halloweenLobbies) do
        if lobby.leader ~= src then
            local leaderCoords = GetEntityCoords(GetPlayerPed(lobby.leader))
            local distance = #(playerCoords - leaderCoords)
            
            if distance < 50.0 then
                local leaderPlayer = ESX.GetPlayerFromId(lobby.leader)
                table.insert(nearbyLobbies, {
                    id = lobbyId,
                    leaderName = leaderPlayer.getName(),
                    playerCount = #lobby.players
                })
            end
        end
    end
    
    TriggerClientEvent('halloween:showNearbyLobbies', src, nearbyLobbies)
end)

RegisterServerEvent('halloween:startLobbyMission')
AddEventHandler('halloween:startLobbyMission', function(lobbyId)
    local src = source
    local lobby = halloweenLobbies[lobbyId]
    if not lobby then return end
    
    if lobby.leader ~= src then
        TriggerClientEvent('esx:showNotification', src, 'Solo el líder puede iniciar la misión')
        return
    end
    
    for _, playerId in ipairs(lobby.players) do
        TriggerClientEvent('halloween:lobbyStartMission', playerId)
    end
end)

RegisterServerEvent('halloween:requestPumpkinSpawn')
AddEventHandler('halloween:requestPumpkinSpawn', function(lobbyId, usedLocations)
    local src = source
    local lobby = halloweenLobbies[lobbyId]
    if not lobby or lobby.leader ~= src then return end
    
    local availableLocations = {}
    for i, location in ipairs(Config.PumpkinLocations) do
        if not usedLocations[i] then
            table.insert(availableLocations, {index = i, coords = location})
        end
    end
    
    if #availableLocations == 0 then return end
    
    local selected = availableLocations[math.random(#availableLocations)]
    
    for _, playerId in ipairs(lobby.players) do
        TriggerClientEvent('halloween:syncPumpkinSpawn', playerId, selected.index, selected.coords)
    end
end)

RegisterServerEvent('halloween:requestZombieSpawn')
AddEventHandler('halloween:requestZombieSpawn', function(lobbyId, pumpkinCoords)
    local src = source
    local lobby = halloweenLobbies[lobbyId]
    if not lobby or lobby.leader ~= src then return end
    
    local zombiesData = {}
    
    for i = 1, Config.Zombies.amount do
        local zombieModel = Config.Zombies.models[math.random(#Config.Zombies.models)]
        local offset = vector3(math.random(-Config.Zombies.spawnRadius, Config.Zombies.spawnRadius), math.random(-Config.Zombies.spawnRadius, Config.Zombies.spawnRadius), 0)
        local spawnCoords = pumpkinCoords + offset
        local weapon = nil
        
        if Config.Zombies.useWeapons then
            weapon = Config.Zombies.weapons[math.random(#Config.Zombies.weapons)]
        end
        
        table.insert(zombiesData, {
            id = lobbyId .. '_zombie_' .. i .. '_' .. os.time(),
            model = zombieModel,
            coords = spawnCoords,
            weapon = weapon
        })
    end
    
    for _, playerId in ipairs(lobby.players) do
        TriggerClientEvent('halloween:syncZombieSpawn', playerId, zombiesData)
    end
end)

RegisterServerEvent('halloween:zombieDied')
AddEventHandler('halloween:zombieDied', function(lobbyId, zombieId)
    local src = source
    local lobby = halloweenLobbies[lobbyId]
    if not lobby then return end
    
    for _, playerId in ipairs(lobby.players) do
        if playerId ~= src then
            TriggerClientEvent('halloween:syncZombieDeath', playerId, zombieId)
        end
    end
end)

RegisterServerEvent('halloween:collectPumpkinLobby')
AddEventHandler('halloween:collectPumpkinLobby', function(lobbyId)
    local src = source
    local lobby = halloweenLobbies[lobbyId]
    if not lobby then return end
    
    local canCarry = exports.ox_inventory:CanCarryItem(src, 'pumpkin', Config.Mission.rewardPerPumpkin.pumpkins)
    if not canCarry then
        TriggerClientEvent('esx:showNotification', src, 'No tienes espacio en el inventario')
        return
    end
    
    exports.ox_inventory:AddItem(src, 'pumpkin', Config.Mission.rewardPerPumpkin.pumpkins)
    
    TriggerClientEvent('chat:addMessage', src, { 
        args = {"Halloween", "Recibiste " .. Config.Mission.rewardPerPumpkin.pumpkins .. " calabaza"} 
    })
    
    for _, playerId in ipairs(lobby.players) do
        TriggerClientEvent('halloween:syncPumpkinCollect', playerId)
    end
end)

RegisterServerEvent('halloween:cancelLobbyMission')
AddEventHandler('halloween:cancelLobbyMission', function(lobbyId)
    local src = source
    local lobby = halloweenLobbies[lobbyId]
    if not lobby or lobby.leader ~= src then return end
    
    for _, playerId in ipairs(lobby.players) do
        TriggerClientEvent('halloween:lobbyCancelMission', playerId)
    end
end)

RegisterServerEvent('halloween:requestVehicleSpawn')
AddEventHandler('halloween:requestVehicleSpawn', function(lobbyId)
    local src = source
    local lobby = halloweenLobbies[lobbyId]
    if not lobby then return end
    
    if not vehicleSpawnCount[lobbyId] then
        vehicleSpawnCount[lobbyId] = 0
    end
    
    local baseCoords = Config.Vehicle.baseCoords
    local spacing = Config.Vehicle.spacing or 2.5
    local offset = vehicleSpawnCount[lobbyId]
    local direction = Config.Vehicle.spawnDirection or "right"
    
    local headingRad = 0
    local offsetX = 0
    local offsetY = 0
    
    if direction == "back" then
        headingRad = math.rad(baseCoords.w - 90)
        offsetX = math.cos(headingRad) * (spacing * offset)
        offsetY = math.sin(headingRad) * (spacing * offset)
    elseif direction == "forward" then
        headingRad = math.rad(baseCoords.w + 90)
        offsetX = math.cos(headingRad) * (spacing * offset)
        offsetY = math.sin(headingRad) * (spacing * offset)
    elseif direction == "left" then
        headingRad = math.rad(baseCoords.w)
        offsetX = math.cos(headingRad) * (spacing * offset)
        offsetY = math.sin(headingRad) * (spacing * offset)
    elseif direction == "right" then
        headingRad = math.rad(baseCoords.w + 180)
        offsetX = math.cos(headingRad) * (spacing * offset)
        offsetY = math.sin(headingRad) * (spacing * offset)
    end
    
    local spawnCoords = vector4(
        baseCoords.x + offsetX,
        baseCoords.y + offsetY,
        baseCoords.z,
        baseCoords.w
    )
    
    vehicleSpawnCount[lobbyId] = vehicleSpawnCount[lobbyId] + 1
    
    TriggerClientEvent('halloween:spawnVehicleAtPosition', src, spawnCoords)
end)

RegisterServerEvent('halloween:transferLobbyLeadership')
AddEventHandler('halloween:transferLobbyLeadership', function(lobbyId)
    local src = source
    local lobby = halloweenLobbies[lobbyId]
    if not lobby or lobby.leader ~= src then return end
    
    for i, playerId in ipairs(lobby.players) do
        if playerId ~= src then
            lobby.leader = playerId
            TriggerClientEvent('halloween:becomeLeader', playerId)
            return
        end
    end
end)

RegisterServerEvent('halloween:activateZombieAttack')
AddEventHandler('halloween:activateZombieAttack', function(lobbyId)
    local src = source
    local lobby = halloweenLobbies[lobbyId]
    if not lobby then return end
    
    for _, playerId in ipairs(lobby.players) do
        TriggerClientEvent('halloween:activateAttack', playerId)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local lobbyId = playerLobbies[src]
    if lobbyId then
        local lobby = halloweenLobbies[lobbyId]
        if lobby and lobby.leader == src then
            for i, playerId in ipairs(lobby.players) do
                if playerId ~= src then
                    lobby.leader = playerId
                    TriggerClientEvent('halloween:becomeLeader', playerId)
                    break
                end
            end
        end
        TriggerEvent('halloween:leaveLobby', lobbyId)
    end
end)
