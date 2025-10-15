ESX = exports['es_extended']:getSharedObject()

RegisterServerEvent('halloween:collectPumpkin')
AddEventHandler('halloween:collectPumpkin', function()
    local src = source
    
    local canCarry = exports.ox_inventory:CanCarryItem(src, 'pumpkin', Config.Mission.rewardPerPumpkin.pumpkins)
    if not canCarry then
        TriggerClientEvent('esx:showNotification', src, '❌ No tienes espacio en el inventario')
        return
    end
    
    exports.ox_inventory:AddItem(src, 'pumpkin', Config.Mission.rewardPerPumpkin.pumpkins)
    
    TriggerClientEvent('chat:addMessage', src, { 
        args = {"🎃 Halloween", "Recibiste " .. Config.Mission.rewardPerPumpkin.pumpkins .. " calabaza"} 
    })
end)

RegisterServerEvent('halloween:completeMission')
AddEventHandler('halloween:completeMission', function(pumpkinsCollected)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    
    xPlayer.addMoney(Config.Mission.rewards.money)
    
    TriggerClientEvent('chat:addMessage', src, { 
        args = {"🎉 Halloween", string.format("¡Misión completada! Recibiste $%d de bonificación", Config.Mission.rewards.money)} 
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
        TriggerClientEvent('esx:showNotification', src, '❌ No tienes suficientes calabazas')
        return
    end
    
    local removed = exports.ox_inventory:RemoveItem(src, 'pumpkin', exchange.pumpkinsRequired)
    if not removed then
        TriggerClientEvent('esx:showNotification', src, '❌ Error al procesar el intercambio')
        return
    end
    
    if exchange.reward.type == "money" then
        xPlayer.addMoney(exchange.reward.amount)
        TriggerClientEvent('esx:showNotification', src, '✅ Recibiste $' .. exchange.reward.amount)
    elseif exchange.reward.type == "weapon" then
        exports.ox_inventory:AddItem(src, exchange.reward.weapon, 1, {ammo = exchange.reward.ammo})
        TriggerClientEvent('esx:showNotification', src, '✅ Recibiste un arma especial')
    elseif exchange.reward.type == "items" then
        for _, item in ipairs(exchange.reward.items) do
            exports.ox_inventory:AddItem(src, item.name, item.amount)
        end
        TriggerClientEvent('esx:showNotification', src, '✅ Recibiste un pack de items')
    end
end)
