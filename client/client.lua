ESX = exports['es_extended']:getSharedObject()

local npcPed = nil
local currentPumpkin = nil
local currentPumpkinCoords = nil
local pumpkinBlip = nil
local zombies = {}
local inHalloweenZone = false
local savedHour = nil
local savedMinute = nil
local missionActive = false
local pumpkinsCollected = 0
local usedLocations = {}
local missionStartTime = 0
local attackStarted = false
local eventVehicle = nil
local canOpenMenu = true
local originalClothing = nil
local backgroundMusicId = nil
local lastDamageTime = 0

function CreateNPC()
    local model = GetHashKey(Config.NPC.model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(100)
    end
    
    npcPed = CreatePed(4, model, Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z - 1.0, Config.NPC.coords.w, false, true)
    SetEntityHeading(npcPed, Config.NPC.coords.w)
    FreezeEntityPosition(npcPed, true)
    SetEntityInvincible(npcPed, true)
    SetBlockingOfNonTemporaryEvents(npcPed, true)
    
    if Config.NPC.blip.enabled then
        local blip = AddBlipForCoord(Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z)
        SetBlipSprite(blip, Config.NPC.blip.sprite)
        SetBlipColour(blip, Config.NPC.blip.color)
        SetBlipScale(blip, Config.NPC.blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.NPC.blip.name)
        EndTextCommandSetBlipName(blip)
    end
end

function SpawnPumpkin()
    local availableLocations = {}
    for i, location in ipairs(Config.PumpkinLocations) do
        if not usedLocations[i] then
            table.insert(availableLocations, {index = i, coords = location})
        end
    end
    
    if #availableLocations == 0 then
        return false
    end
    
    local selected = availableLocations[math.random(#availableLocations)]
    currentPumpkinCoords = selected.coords
    usedLocations[selected.index] = true
    
    currentPumpkin = CreateObject(GetHashKey("prop_veg_crop_03_pump"), currentPumpkinCoords.x, currentPumpkinCoords.y, currentPumpkinCoords.z - 1.0, true, true, true)
    PlaceObjectOnGroundProperly(currentPumpkin)
    SetEntityHeading(currentPumpkin, math.random(0, 360))
    
    pumpkinBlip = AddBlipForCoord(currentPumpkinCoords.x, currentPumpkinCoords.y, currentPumpkinCoords.z)
    SetBlipSprite(pumpkinBlip, 484)
    SetBlipColour(pumpkinBlip, 47)
    SetBlipScale(pumpkinBlip, 0.9)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Calabaza " .. (pumpkinsCollected + 1) .. "/" .. Config.Mission.pumpkinsToCollect)
    EndTextCommandSetBlipName(pumpkinBlip)
    
    SpawnZombies()
    attackStarted = false
    return true
end

function SpawnZombies()
    DeleteZombies()
    
    RequestAnimSet("move_m@drunk@verydrunk")
    while not HasAnimSetLoaded("move_m@drunk@verydrunk") do
        Citizen.Wait(100)
    end
    
    for i = 1, Config.Zombies.amount do
        local zombieModel = GetHashKey(Config.Zombies.models[math.random(#Config.Zombies.models)])
        RequestModel(zombieModel)
        while not HasModelLoaded(zombieModel) do
            Citizen.Wait(100)
        end
        
        local offset = vector3(math.random(-Config.Zombies.spawnRadius, Config.Zombies.spawnRadius), math.random(-Config.Zombies.spawnRadius, Config.Zombies.spawnRadius), 0)
        local spawnCoords = currentPumpkinCoords + offset
        local groundZ = spawnCoords.z
        local found, zCoord = GetGroundZFor_3dCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z + 999.0, false)
        if found then
            groundZ = zCoord
        end
        
        local zombie = CreatePed(4, zombieModel, spawnCoords.x, spawnCoords.y, groundZ, 0.0, true, true)
        
        SetEntityAsMissionEntity(zombie, true, true)
        SetEntityHealth(zombie, 200)
        SetPedMaxHealth(zombie, 200)
        SetPedArmour(zombie, 0)
        
        SetPedMovementClipset(zombie, "move_m@drunk@verydrunk", 1.0)
        SetPedRelationshipGroupHash(zombie, GetHashKey("HATES_PLAYER"))
        SetPedFleeAttributes(zombie, 0, false)
        SetPedSeeingRange(zombie, 100.0)
        SetPedHearingRange(zombie, 100.0)
        SetPedAlertness(zombie, 3)
        SetBlockingOfNonTemporaryEvents(zombie, true)
        SetPedPathCanUseClimbovers(zombie, false)
        SetPedPathCanUseLadders(zombie, false)
        SetPedConfigFlag(zombie, 208, true)
        
        ApplyPedDamagePack(zombie, "BigHitByVehicle", 0.0, 9.0)
        SetPedCanRagdoll(zombie, true)
        
        DisablePedPainAudio(zombie, false)
        local voices = {"PAIN_VOICE_1_MALE", "SCREAM_VOICE_1_MALE", "DEATH_VOICE_1_MALE"}
        SetAmbientVoiceName(zombie, voices[math.random(#voices)])
        
        SetPedEyeColor(zombie, 2)
        
        TaskWanderInArea(zombie, currentPumpkinCoords.x, currentPumpkinCoords.y, currentPumpkinCoords.z, 10.0, 0.5, 0.5)
        
        table.insert(zombies, zombie)
    end
    
    attackStarted = false
end

function FollowPlayer()
    local player = PlayerPedId()
    for _, zombie in ipairs(zombies) do
        if DoesEntityExist(zombie) and not IsEntityDead(zombie) then
            TaskGoToEntity(zombie, player, -1, 1.0, 2.0, 1073741824, 0)
        end
    end
end

function DeleteZombies()
    for _, zombie in ipairs(zombies) do
        if DoesEntityExist(zombie) then
            DeleteEntity(zombie)
        end
    end
    zombies = {}
end

function StopHalloweenEffects()
    inHalloweenZone = false
end

function StartMission()
    if missionActive then
        ESX.ShowNotification("Ya tienes una misión activa")
        return
    end
    
    missionActive = true
    pumpkinsCollected = 0
    usedLocations = {}
    missionStartTime = GetGameTimer()
    
    savedHour = GetClockHours()
    savedMinute = GetClockMinutes()
    
    StartBackgroundMusic()
    
    TriggerEvent('chat:addMessage', { 
        args = {"🎃 Halloween", "¡Misión iniciada! Recolecta " .. Config.Mission.pumpkinsToCollect .. " calabazas antes de que se acabe el tiempo!"} 
    })
    
    Citizen.Wait(500)
    SpawnPumpkin()
end

function StartBackgroundMusic()
    backgroundMusicId = GetSoundId()
    PlaySoundFrontend(backgroundMusicId, "DISTANT_TRAIN", "TRAIN_SOUNDS", true)
end

function StopBackgroundMusic()
    if backgroundMusicId then
        StopSound(backgroundMusicId)
        ReleaseSoundId(backgroundMusicId)
        backgroundMusicId = nil
    end
end

function EndMission(completed)
    if not missionActive then return end
    
    missionActive = false
    
    if currentPumpkin then
        DeleteObject(currentPumpkin)
        currentPumpkin = nil
    end
    
    if pumpkinBlip then
        RemoveBlip(pumpkinBlip)
        pumpkinBlip = nil
    end
    
    if eventVehicle and DoesEntityExist(eventVehicle) then
        ESX.Game.DeleteVehicle(eventVehicle)
        eventVehicle = nil
    end
    
    DeleteZombies()
    StopHalloweenEffects()
    RestoreOriginalClothing()
    StopBackgroundMusic()
    
    AnimpostfxStop("DrugsMichaelAliensFight")
    StopScreenEffect("DeathFailMPIn")
    AnimpostfxStop("DeathFailNeutralIn")
    StopScreenEffect("ExplosionJosh3")
    
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    SetTimecycleModifierStrength(0.0)
    
    ClearWeatherTypePersist()
    ClearOverrideWeather()
    SetWeatherTypeNow('CLEAR')
    SetWeatherTypeNowPersist('CLEAR')
    
    if savedHour and savedMinute then
        NetworkOverrideClockTime(savedHour, savedMinute, 0)
    end
    
    if completed then
        TriggerServerEvent('halloween:completeMission', pumpkinsCollected)
    else
        TriggerEvent('chat:addMessage', { 
            args = {"🎃 Halloween", "Misión fallida. Solo recolectaste " .. pumpkinsCollected .. "/" .. Config.Mission.pumpkinsToCollect .. " calabazas"} 
        })
    end
    
    pumpkinsCollected = 0
    usedLocations = {}
end

Citizen.CreateThread(function()
    Citizen.Wait(1000)
    CreateNPC()
end)

function OpenMainMenu()
    local pumpkinCount = exports.ox_inventory:Search('count', 'pumpkin')
    
    local menuOptions = {
        {
            title = 'Iniciar Misión',
            description = missionActive and 'Ya tienes una misión activa' or 'Recolecta ' .. Config.Mission.pumpkinsToCollect .. ' calabazas',
            icon = 'fas fa-play',
            iconColor = missionActive and '#95a5a6' or '#2ecc71',
            onSelect = function()
                if missionActive then
                    ESX.ShowNotification('Ya tienes una misión activa. Termínala primero.')
                else
                    StartMission()
                end
            end
        },
        {
            title = 'Detener Misión',
            description = not missionActive and 'No hay misión activa' or 'Cancelar la misión actual',
            icon = 'fas fa-stop',
            iconColor = not missionActive and '#95a5a6' or '#e74c3c',
            onSelect = function()
                if not missionActive then
                    ESX.ShowNotification('No hay ninguna misión activa para detener.')
                else
                    EndMission(false)
                    ESX.ShowNotification('Misión cancelada')
                end
            end
        },
        {
            title = 'Intercambiar Calabazas',
            description = pumpkinCount == 0 and 'No tienes calabazas' or 'Tienes: ' .. pumpkinCount .. ' calabazas',
            icon = 'fas fa-exchange-alt',
            iconColor = pumpkinCount == 0 and '#95a5a6' or '#f39c12',
            onSelect = function()
                if pumpkinCount == 0 then
                    ESX.ShowNotification('No tienes calabazas para intercambiar. Completa misiones para obtenerlas.')
                else
                    OpenExchangeMenu()
                end
            end
        },
        {
            title = 'Vehículo de Evento',
            description = not missionActive and 'Requiere misión activa' or 'Solicitar vehículo especial',
            icon = 'fas fa-motorcycle',
            iconColor = not missionActive and '#95a5a6' or '#9b59b6',
            onSelect = function()
                if not missionActive then
                    ESX.ShowNotification('Necesitas tener una misión activa para obtener el vehículo.')
                else
                    SpawnEventVehicle()
                end
            end
        },
        {
            title = 'Ropa de Evento',
            description = not missionActive and 'Requiere misión activa' or 'Obtener outfit de Halloween',
            icon = 'fas fa-tshirt',
            iconColor = not missionActive and '#95a5a6' or '#e67e22',
            onSelect = function()
                if not missionActive then
                    ESX.ShowNotification('Necesitas tener una misión activa para obtener la ropa.')
                else
                    ApplyEventClothing()
                end
            end
        }
    }
    
    lib.registerContext({
        id = 'halloween_main_menu',
        title = '🎃 Evento Halloween',
        options = menuOptions
    })
    
    lib.showContext('halloween_main_menu')
end

function OpenExchangeMenu()
    local pumpkinCount = exports.ox_inventory:Search('count', 'pumpkin')
    
    local exchangeOptions = {}
    
    for i, exchange in ipairs(Config.Exchange) do
        local canExchange = pumpkinCount >= exchange.pumpkinsRequired
        local missing = exchange.pumpkinsRequired - pumpkinCount
        
        table.insert(exchangeOptions, {
            title = exchange.label,
            description = canExchange and 'Requiere: ' .. exchange.pumpkinsRequired .. ' calabazas | Tienes: ' .. pumpkinCount or 'Te faltan ' .. missing .. ' calabazas (Tienes: ' .. pumpkinCount .. ')',
            icon = exchange.icon,
            iconColor = canExchange and exchange.iconColor or '#95a5a6',
            onSelect = function()
                if not canExchange then
                    ESX.ShowNotification('Te faltan ' .. missing .. ' calabazas para este intercambio.')
                else
                    TriggerServerEvent('halloween:exchange', i)
                    lib.hideContext()
                end
            end
        })
    end
    
    lib.registerContext({
        id = 'exchange_menu',
        title = '🎃 Intercambiar Calabazas',
        menu = 'halloween_main_menu',
        options = exchangeOptions
    })
    
    lib.showContext('exchange_menu')
end

function SpawnEventVehicle()
    if eventVehicle and DoesEntityExist(eventVehicle) then
        ESX.Game.DeleteVehicle(eventVehicle)
        Citizen.Wait(100)
    end
    
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    ESX.Game.SpawnVehicle(Config.Vehicle.model, Config.Vehicle.coords, Config.Vehicle.coords.w, function(vehicle)
        eventVehicle = vehicle
        SetVehicleNumberPlateText(vehicle, Config.Vehicle.plate)
        TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
        ESX.ShowNotification('Vehículo de Halloween spawneado')
    end)
end

function SaveOriginalClothing()
    local playerPed = PlayerPedId()
    originalClothing = {
        mask = {drawable = GetPedDrawableVariation(playerPed, 1), texture = GetPedTextureVariation(playerPed, 1)},
        torso = {drawable = GetPedDrawableVariation(playerPed, 3), texture = GetPedTextureVariation(playerPed, 3)},
        legs = {drawable = GetPedDrawableVariation(playerPed, 4), texture = GetPedTextureVariation(playerPed, 4)},
        bag = {drawable = GetPedDrawableVariation(playerPed, 5), texture = GetPedTextureVariation(playerPed, 5)},
        shoes = {drawable = GetPedDrawableVariation(playerPed, 6), texture = GetPedTextureVariation(playerPed, 6)},
        accessory = {drawable = GetPedDrawableVariation(playerPed, 7), texture = GetPedTextureVariation(playerPed, 7)},
        undershirt = {drawable = GetPedDrawableVariation(playerPed, 8), texture = GetPedTextureVariation(playerPed, 8)},
        kevlar = {drawable = GetPedDrawableVariation(playerPed, 9), texture = GetPedTextureVariation(playerPed, 9)},
        torso2 = {drawable = GetPedDrawableVariation(playerPed, 11), texture = GetPedTextureVariation(playerPed, 11)}
    }
end

function RestoreOriginalClothing()
    if not originalClothing then return end
    
    local playerPed = PlayerPedId()
    SetPedComponentVariation(playerPed, 1, originalClothing.mask.drawable, originalClothing.mask.texture, 0)
    SetPedComponentVariation(playerPed, 3, originalClothing.torso.drawable, originalClothing.torso.texture, 0)
    SetPedComponentVariation(playerPed, 4, originalClothing.legs.drawable, originalClothing.legs.texture, 0)
    SetPedComponentVariation(playerPed, 5, originalClothing.bag.drawable, originalClothing.bag.texture, 0)
    SetPedComponentVariation(playerPed, 6, originalClothing.shoes.drawable, originalClothing.shoes.texture, 0)
    SetPedComponentVariation(playerPed, 7, originalClothing.accessory.drawable, originalClothing.accessory.texture, 0)
    SetPedComponentVariation(playerPed, 8, originalClothing.undershirt.drawable, originalClothing.undershirt.texture, 0)
    SetPedComponentVariation(playerPed, 9, originalClothing.kevlar.drawable, originalClothing.kevlar.texture, 0)
    SetPedComponentVariation(playerPed, 11, originalClothing.torso2.drawable, originalClothing.torso2.texture, 0)
    
    originalClothing = nil
end

function ApplyEventClothing()
    SaveOriginalClothing()
    
    local playerPed = PlayerPedId()
    local sex = GetEntityModel(playerPed) == GetHashKey("mp_f_freemode_01") and "female" or "male"
    local clothing = Config.Clothing[sex]
    
    SetPedComponentVariation(playerPed, 1, clothing.mask.drawable, clothing.mask.texture, 0)
    SetPedComponentVariation(playerPed, 3, clothing.torso.drawable, clothing.torso.texture, 0)
    SetPedComponentVariation(playerPed, 4, clothing.legs.drawable, clothing.legs.texture, 0)
    SetPedComponentVariation(playerPed, 5, clothing.bag.drawable, clothing.bag.texture, 0)
    SetPedComponentVariation(playerPed, 6, clothing.shoes.drawable, clothing.shoes.texture, 0)
    SetPedComponentVariation(playerPed, 7, clothing.accessory.drawable, clothing.accessory.texture, 0)
    SetPedComponentVariation(playerPed, 8, clothing.undershirt.drawable, clothing.undershirt.texture, 0)
    SetPedComponentVariation(playerPed, 9, clothing.kevlar.drawable, clothing.kevlar.texture, 0)
    SetPedComponentVariation(playerPed, 11, clothing.torso2.drawable, clothing.torso2.texture, 0)
    
    ESX.ShowNotification('Ropa de Halloween aplicada')
end

Citizen.CreateThread(function()
    while true do
        local sleep = 500
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local npcCoords = Config.NPC.coords
        local distToNPC = #(playerCoords - vector3(npcCoords.x, npcCoords.y, npcCoords.z))
        
        if distToNPC < 2.5 then
            sleep = 0
            ESX.ShowHelpNotification("Presiona ~INPUT_CONTEXT~ para abrir el menú de Halloween")
            if IsControlJustPressed(0, 38) and canOpenMenu then
                canOpenMenu = false
                OpenMainMenu()
                Citizen.SetTimeout(500, function()
                    canOpenMenu = true
                end)
            end
        end
        
        if missionActive and currentPumpkin then
            local dist = #(playerCoords - currentPumpkinCoords)
            
            if dist < 100.0 then
                sleep = 0
                
                if dist < Config.Effects.zoneRadius then
                    DrawLightWithRange(currentPumpkinCoords.x, currentPumpkinCoords.y, currentPumpkinCoords.z + 2.0, Config.Effects.lightColor[1], Config.Effects.lightColor[2], Config.Effects.lightColor[3], Config.Effects.lightRange, Config.Effects.lightIntensity)
                    
                    if dist < 30.0 then
                        if not AnimpostfxIsRunning("DrugsMichaelAliensFight") then
                            AnimpostfxPlay("DrugsMichaelAliensFight", 0, false)
                        end
                    else
                        AnimpostfxStop("DrugsMichaelAliensFight")
                    end
                end
                
            if dist < Config.Zombies.attackDistance and not attackStarted then
                FollowPlayer()
                attackStarted = true
            end
                
                if dist < 15.0 then
                    DrawMarker(20, currentPumpkinCoords.x, currentPumpkinCoords.y, currentPumpkinCoords.z + 0.5, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.5, 255, 100, 0, 150, false, true, 2, nil, nil, false)
                end
                
            if dist < 2.0 then
                    ESX.ShowHelpNotification("~INPUT_CONTEXT~ Recolectar calabaza (" .. (pumpkinsCollected + 1) .. "/" .. Config.Mission.pumpkinsToCollect .. ")")
                if IsControlJustPressed(0, 38) then
                        TriggerServerEvent('halloween:collectPumpkin')
                        
                        DeleteObject(currentPumpkin)
                        RemoveBlip(pumpkinBlip)
                        
                        currentPumpkin = nil
                        pumpkinBlip = nil
                        
                        pumpkinsCollected = pumpkinsCollected + 1
                        
                        TriggerEvent('chat:addMessage', { 
                            args = {"🎃 Halloween", "Calabaza recolectada " .. pumpkinsCollected .. "/" .. Config.Mission.pumpkinsToCollect} 
                        })
                        
                        if pumpkinsCollected >= Config.Mission.pumpkinsToCollect then
                            EndMission(true)
                        else
                            SpawnPumpkin()
                        end
                    end
                end
            end
        else
            AnimpostfxStop("DrugsMichaelAliensFight")
        end
        
        Citizen.Wait(sleep)
    end
end)

Citizen.CreateThread(function()
    while true do
        local wait = 5000 + math.random(3000, 7000)
        
        if missionActive and currentPumpkin then
            local coords = GetEntityCoords(PlayerPedId())
            local dist = #(coords - currentPumpkinCoords)
            if dist < Config.Effects.zoneRadius then
                ForceLightningFlash()
                Citizen.Wait(100)
                local x, y, z = table.unpack(currentPumpkinCoords)
                AddExplosion(x + math.random(-15, 15), y + math.random(-15, 15), z + 50.0, 'EXPLOSION_FLARE', 0.0, true, true, 0.0, false)
            end
        else
            wait = 10000
        end
        
        Citizen.Wait(wait)
    end
end)

Citizen.CreateThread(function()
    while true do
        if missionActive then
            NetworkOverrideClockTime(0, 0, 0)
            SetWeatherTypePersist('THUNDER')
            SetWeatherTypeNowPersist('THUNDER')
            SetRainLevel(0.5)
            SetWindSpeed(15.0)
            SetTimecycleModifier('MP_Celeb_Lose')
            SetTimecycleModifierStrength(0.8)
            SetExtraTimecycleModifier('cinema')
            SetExtraTimecycleModifierStrength(0.5)
            Citizen.Wait(1000)
        else
            Citizen.Wait(5000)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        if missionActive then
            local elapsed = (GetGameTimer() - missionStartTime) / 1000
            if elapsed >= Config.Mission.timeLimit then
                EndMission(false)
            end
            Citizen.Wait(1000)
        else
            Citizen.Wait(5000)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        local wait = 1000
        
        if missionActive and #zombies > 0 then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local currentHealth = GetEntityHealth(playerPed)
            
            for _, zombie in ipairs(zombies) do
                if DoesEntityExist(zombie) and not IsEntityDead(zombie) then
                    local zombieCoords = GetEntityCoords(zombie)
                    local dist = #(playerCoords - zombieCoords)
                    
                    if dist < Config.Zombies.damageDistance then
                        wait = 500
                        if currentHealth > 100 then
                            SetEntityHealth(playerPed, currentHealth - Config.Zombies.damagePerSecond)
                            lastDamageTime = GetGameTimer()
                            
                            StartScreenEffect("ExplosionJosh3", 0, false)
                            Citizen.SetTimeout(500, function()
                                StopScreenEffect("ExplosionJosh3")
                            end)
                        end
                    end
                end
            end
            
            if currentHealth < 150 then
                local intensity = 1.0 - (currentHealth / 200)
                StartScreenEffect("DeathFailMPIn", 0, false)
                AnimpostfxPlay("DeathFailNeutralIn", 0, false)
            else
                StopScreenEffect("DeathFailMPIn")
                AnimpostfxStop("DeathFailNeutralIn")
            end
        else
            wait = 5000
        end
        
        Citizen.Wait(wait)
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3000 + math.random(2000, 4000))
        
        if missionActive and #zombies > 0 then
            local playerCoords = GetEntityCoords(PlayerPedId())
            
            for _, zombie in ipairs(zombies) do
                if DoesEntityExist(zombie) and not IsEntityDead(zombie) then
                    local zombieCoords = GetEntityCoords(zombie)
                    local dist = #(playerCoords - zombieCoords)
                    
                    if dist < 25.0 then
                        local zombieSounds = {"PAIN", "COWER", "FLEE_SHOCKED", "WHIMPER", "DYING"}
                        PlayPain(zombie, math.random(1, 25), 0)
                        
                        if math.random(1, 3) == 1 then
                            local soundId = GetSoundId()
                            PlaySoundFromEntity(soundId, "TIMER_STOP", zombie, "HUD_MINI_GAME_SOUNDSET", false, 0)
                            Citizen.SetTimeout(800, function()
                                StopSound(soundId)
                                ReleaseSoundId(soundId)
                            end)
                        end
                    end
                end
            end
        else
            Citizen.Wait(5000)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000 + math.random(5000, 10000))
        
        if missionActive then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local soundId = GetSoundId()
            PlaySoundFromCoord(soundId, "DISTANT_SIREN", playerCoords.x, playerCoords.y, playerCoords.z, "PROLOGUE_2_SOUNDS", false, 50.0, false)
            Citizen.SetTimeout(3000, function()
                StopSound(soundId)
                ReleaseSoundId(soundId)
            end)
        else
            Citizen.Wait(10000)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(15000 + math.random(5000, 10000))
        
        if missionActive then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local soundId = GetSoundId()
            PlaySoundFromCoord(soundId, "Retro_Explosion", playerCoords.x + math.random(-20, 20), playerCoords.y + math.random(-20, 20), playerCoords.z, "MP_LOBBY_SOUNDS", false, 30.0, false)
            ReleaseSoundId(soundId)
        else
            Citizen.Wait(10000)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if npcPed then
        DeleteEntity(npcPed)
    end
    
    if currentPumpkin then
        DeleteObject(currentPumpkin)
    end
    
    if pumpkinBlip then
        RemoveBlip(pumpkinBlip)
    end
    
    if eventVehicle and DoesEntityExist(eventVehicle) then
        DeleteEntity(eventVehicle)
    end
    
    DeleteZombies()
    StopBackgroundMusic()
    
    AnimpostfxStop("DrugsMichaelAliensFight")
    StopScreenEffect("DeathFailMPIn")
    AnimpostfxStop("DeathFailNeutralIn")
    StopScreenEffect("ExplosionJosh3")
    
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    SetTimecycleModifierStrength(0.0)
    ClearWeatherTypePersist()
    ClearOverrideWeather()
    SetWeatherTypeNow('CLEAR')
    SetWeatherTypeNowPersist('CLEAR')
    
    if savedHour and savedMinute then
        NetworkOverrideClockTime(savedHour, savedMinute, 0)
    end
end)
