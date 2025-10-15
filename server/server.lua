ESX = exports['es_extended']:getSharedObject()

local halloweenLobbies = {}
local playerLobbies = {}

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
    
    for _, playerId in ipairs(lobby.players) do
        TriggerClientEvent('halloween:lobbyUpdated', playerId, lobby.players)
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

AddEventHandler('playerDropped', function()
    local src = source
    local lobbyId = playerLobbies[src]
    if lobbyId then
        TriggerEvent('halloween:leaveLobby', lobbyId)
    end
end)
