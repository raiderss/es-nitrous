Framework = nil
Framework = GetFramework()
Citizen.CreateThread(function()
    while Framework == nil do 
        Citizen.Wait(750) 
    end
    Citizen.Wait(2500)
end)

Callback = (Config.Framework == "ESX" or Config.Framework == "NewESX") and Framework.TriggerServerCallback or Framework.Functions.TriggerCallback

local NitroVeh = {}
local isPressing = false
local exhaustEffects = {}
local tireEffects = {}

RegisterKeyMapping('nitros', 'Toggle Nitro', 'keyboard', 'G')

Citizen.CreateThread(function()
    while true do
        PlayerPed = PlayerPedId()
        Citizen.Wait(4500)
    end
end)

function GetVehicleInDirection()
    local playerCoords = GetEntityCoords(PlayerPed)
    local forwardVector = GetEntityForwardVector(PlayerPed)
    local maxDistance = 10.0

    for i = 0, 360, 30 do
        local angle = math.rad(i)
        local direction = vector3(
            forwardVector.x * math.cos(angle) - forwardVector.y * math.sin(angle), 
            forwardVector.x * math.sin(angle) + forwardVector.y * math.cos(angle), 
            forwardVector.z
        )
        local endCoords = playerCoords + direction * maxDistance
        local rayHandle = StartShapeTestRay(playerCoords.x, playerCoords.y, playerCoords.z, endCoords.x, endCoords.y, endCoords.z, 10, PlayerPed, 0)
        local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)

        if hit == 1 and IsEntityAVehicle(entityHit) then
            return entityHit
        end
    end
    return nil
end

Citizen.CreateThread(function()
    TriggerServerEvent('RequestNitroData')
end)

RegisterNetEvent('UpdateData')
AddEventHandler('UpdateData', function(Get)
    NitroVeh = Get
end)

function CheckOwnership(vehicle, cb)
    local plate = GetVehicleNumberPlateText(vehicle)
    Callback('Owner', function(owned)
        cb(owned)
    end, plate)
end

function SetupCinematicCam(vehicle)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local camPos = GetOffsetFromEntityInWorldCoords(vehicle, 0, -2.5, 1.0)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtEntity(cam, vehicle)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 2000, true, true)
    return cam
end

function MoveToEngineAndInstallNitro(vehicle, plate)
    local engineBone = GetEntityBoneIndexByName(vehicle, "engine")
    local enginePos = engineBone ~= -1 and GetWorldPositionOfEntityBone(vehicle, engineBone) or GetOffsetFromEntityInWorldCoords(vehicle, 0, -1.5, 0)
    TaskGoToCoordAnyMeans(PlayerPed, enginePos.x, enginePos.y, enginePos.z, 1.0, 0, 0, 786603, 0xbf800000)
    Citizen.Wait(3000)
    SetVehicleDoorOpen(vehicle, 4, false, false)
    TaskStartScenarioInPlace(PlayerPed, 'PROP_HUMAN_BUM_BIN', 0, true)
    local cam = SetupCinematicCam(vehicle)
    print("Starting Progressbar...")
    Framework.Functions.Progressbar("install_nos", "Installing NOS...", 5000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        ClearPedTasksImmediately(PlayerPed)
        SetVehicleDoorShut(vehicle, 4, false)
        RenderScriptCams(false, false, 2000, true, true)
        DestroyCam(cam, false)
        TriggerServerEvent('RemoveNitroItem', plate)
        Framework.Functions.Notify("NOS installed successfully!", "success")
        FlashVehicleHeadlights(vehicle, 3)
        TriggerServerEvent('vehicle:nitrous:saveData', json.encode({ plate = plate, nos = 100 }))
    end, function()
        ClearPedTasksImmediately(PlayerPed)
        SetVehicleDoorShut(vehicle, 4, false)
        RenderScriptCams(false, false, 2000, true, true)
        DestroyCam(cam, false)
        Framework.Functions.Notify("Installation cancelled", "error")
    end)
end

RegisterNetEvent('SetupNitro')
AddEventHandler('SetupNitro', function()
    local vehicle = GetVehicleInDirection()
    if vehicle then
        local plate = GetVehicleNumberPlateText(vehicle)
        print("Detected vehicle with plate: " .. plate)

        if vehicle and DoesEntityExist(vehicle) and IsPedOnFoot(PlayerPed) then
            CheckOwnership(vehicle, function(owned)
                if owned and (not NitroVeh[plate] or NitroVeh[plate] == 0) then
                    MoveToEngineAndInstallNitro(vehicle, plate)
                else
                    if NitroVeh[plate] and NitroVeh[plate] > 0 then
                        Framework.Functions.Notify("This vehicle already has nitro installed.", "error")
                    else
                        Framework.Functions.Notify("You do not own this vehicle or vehicle not found", "error")
                    end
                end
            end)
        else
            Framework.Functions.Notify("Vehicle not found or player not on foot", "error")
        end
    else
        Framework.Functions.Notify("No vehicle detected in direction.", "error")
    end
end)

RegisterCommand('nitros', function()
    local InVehicle = GetVehiclePedIsIn(PlayerPed, false)
    local Plate = GetVehicleNumberPlateText(InVehicle)
    local nitroStartTime = GetGameTimer()
    if isPressing then
        SetVehicleNitroBoostEnabled(InVehicle, false)
        ManageVehicleParticles(InVehicle, false)
        ClearTimecycleModifier() 
        isPressing = false
    else
        if InVehicle and NitroVeh[Plate] and NitroVeh[Plate] > 0 then
            SetVehicleNitroBoostEnabled(InVehicle, true)
            ManageVehicleParticles(InVehicle, true)
            isPressing = true
            Citizen.CreateThread(function()
                while isPressing and NitroVeh[Plate] > 0 do
                    CreateVehicleExhaustBackfire(InVehicle, 1.25, 5.0, nitroStartTime) -- Increased max scale for longer flames
                    CreateHeatedRimEffects(InVehicle, 5.0, nitroStartTime) -- Added heated rim effects
                    local delay = math.max(1500 - ((GetGameTimer() - nitroStartTime) / 500), 200)
                    Citizen.Wait(delay)
                    TriggerServerEvent('UpdateNitro', Plate, 5)
                    if IsEntityDead(InVehicle) or not IsPedInVehicle(PlayerPed, InVehicle, true) then
                        SetVehicleNitroBoostEnabled(InVehicle, false)
                        ManageVehicleParticles(InVehicle, false)
                        ClearTimecycleModifier() 
                        isPressing = false
                        Framework.Functions.Notify("Nitro stopped due to crash or exit.", "error")
                    end

                    if NitroVeh[Plate] <= 0 then
                        SetVehicleNitroBoostEnabled(InVehicle, false)
                        ManageVehicleParticles(InVehicle, false)
                        ClearTimecycleModifier() 
                        isPressing = false
                        Framework.Functions.Notify("Nitro depleted.", "error")
                    end
                end
            end)
        else
            Framework.Functions.Notify("This vehicle does not have nitro installed.", "error")
        end
    end
end)

function SetVehicleNitroBoostEnabled(vehicle, enabled)
    if enabled then
        SetVehicleEnginePowerMultiplier(vehicle, 100.0)
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "nitro_activate", 0.5)
    else
        SetVehicleEnginePowerMultiplier(vehicle, 1.0)
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "nitro_deactivate", 0.5)
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local InVehicle = GetVehiclePedIsIn(PlayerPed, false)
        local Plate = GetVehicleNumberPlateText(InVehicle)
        if InVehicle and NitroVeh[Plate] and NitroVeh[Plate] > 0 then
            DrawText3D(0.5, 0.9, 0.75, "Nitro: " .. NitroVeh[Plate], 0.5)
        end
    end
end)

function ManageVehicleParticles(vehicle, enabled)
    local plate = GetVehicleNumberPlateText(vehicle)
    exhaustEffects[plate] = exhaustEffects[plate] or {}
    tireEffects[plate] = tireEffects[plate] or {}
    
    if enabled then
        if not exhaustEffects[plate] then
            exhaustEffects[plate] = {}
        end
        
        Citizen.CreateThread(function()
            local particleDuration = 500 
            local lastColorChange = GetGameTimer()

            while isPressing do
                local elapsedTime = GetGameTimer() - lastColorChange
                local newColor = vector3(math.random(), math.random(), math.random()) 

                if elapsedTime >= particleDuration then
                    for i = 1, 16 do
                        UseParticleFxAssetNextCall('core')
                        local effect = StartParticleFxLoopedOnEntity('veh_backfire', vehicle, 0, 0, 0, 0, 0, 0, 2.0, false, false, false, newColor.x, newColor.y, newColor.z)
                        table.insert(exhaustEffects[plate], effect)
                    end
                    lastColorChange = GetGameTimer()
                end

                Citizen.Wait(0)
            end

            for _, effect in ipairs(exhaustEffects[plate]) do
                StopParticleFxLooped(effect, 0)
            end
            exhaustEffects[plate] = {}
        end)

        Citizen.CreateThread(function()
            while isPressing do
                for i = 0, 3 do
                    local boneIndex = GetEntityBoneIndexByName(vehicle, "wheel_" .. i)
                    if boneIndex ~= -1 then
                        UseParticleFxAssetNextCall('core')
                        local pos = GetWorldPositionOfEntityBone(vehicle, boneIndex)
                        local effect = StartParticleFxLoopedOnEntity("veh_backfire", vehicle, pos.x, pos.y, pos.z, 0, 0, 0, 0.5, false, false, false)
                        table.insert(tireEffects[plate], effect)
                    end
                end
                Citizen.Wait(100)
            end

            for _, effect in ipairs(tireEffects[plate]) do
                StopParticleFxLooped(effect, 0)
            end
            tireEffects[plate] = {}
        end)
    else
        if exhaustEffects[plate] then
            for _, effect in ipairs(exhaustEffects[plate]) do
                StopParticleFxLooped(effect, 0)
            end
            exhaustEffects[plate] = {}
        end

        if tireEffects[plate] then
            for _, effect in ipairs(tireEffects[plate]) do
                StopParticleFxLooped(effect, 0)
            end
            tireEffects[plate] = {}
        end
    end
end

function CreateVehicleExhaustBackfire(vehicle, initialScale, maxScale, startTime)
    local exhaustNames = {
        "exhaust", "exhaust_2", "exhaust_3", "exhaust_4", "exhaust_5",
        "exhaust_6", "exhaust_7", "exhaust_8", "exhaust_9", "exhaust_10",
        "exhaust_11", "exhaust_12", "exhaust_13", "exhaust_14", "exhaust_15", "exhaust_16"
    }
    local timeElapsed = GetGameTimer() - startTime
    local scaleIncrement = (maxScale - initialScale) * (timeElapsed / 10000)
    local scale = math.min(initialScale + scaleIncrement, maxScale)

    for _, exhaustName in ipairs(exhaustNames) do
        local boneIndex = GetEntityBoneIndexByName(vehicle, exhaustName)
        if boneIndex ~= -1 then
            local pos = GetWorldPositionOfEntityBone(vehicle, boneIndex)
            local off = GetOffsetFromEntityGivenWorldCoords(vehicle, pos.x, pos.y, pos.z)

            UseParticleFxAssetNextCall('core')
            local effect = StartParticleFxNonLoopedOnEntity('veh_backfire', vehicle, off.x, off.y, off.z, 0.0, 0.0, 0.0, scale, false, false, false)
            TriggerServerEvent("InteractSound_SV:PlayWithinDistance", 5.0, "exhaust_explosion", 0.5)
        end
    end
end

function CreateHeatedRimEffects(vehicle, scale, startTime)
    local tireNames = {"wheel_lf", "wheel_rf", "wheel_lr", "wheel_rr"}
    for _, tireName in ipairs(tireNames) do
        local boneIndex = GetEntityBoneIndexByName(vehicle, tireName)
        if boneIndex ~= -1 then
            local pos = GetWorldPositionOfEntityBone(vehicle, boneIndex)
            UseParticleFxAssetNextCall('core')
            local effect = StartParticleFxLoopedOnEntity("core_heated_wheel", vehicle, pos.x, pos.y, pos.z, 0, 0, 0, scale, false, false, false)
            table.insert(tireEffects[GetVehicleNumberPlateText(vehicle)], effect)
        end
    end
end

exports['qb-target']:AddTargetBone({'bonnet'}, {
    options = {
        {
            label = "Install NOS",
            icon = "fas fa-tools",
            action = function(entity)
                local vehicle = entity
                if vehicle then
                    TriggerEvent('SetupNitro', vehicle)
                else
                    Framework.Functions.Notify("You must be near a vehicle", "error")
                end
            end,
            canInteract = function(entity)
                local plate = GetVehicleNumberPlateText(entity)
                return not NitroVeh[plate] or NitroVeh[plate] == 0
            end
        }
    },
    distance = 2.5
})

function MoveCamToPosition(cam, targetX, targetY, targetZ, duration)
    local startTime = GetGameTimer()
    local startX, startY, startZ = table.unpack(GetCamCoord(cam))
    Citizen.CreateThread(function()
        while (GetGameTimer() - startTime) < duration do
            Citizen.Wait(0)
            local progress = (GetGameTimer() - startTime) / duration
            SetCamCoord(cam, startX + (targetX - startX) * progress, startY + (targetY - startY) * progress, startZ + (targetZ - startZ) * progress)
        end
    end)
end

function FlashVehicleHeadlights(vehicle, count)
    Citizen.CreateThread(function()
        for i = 1, count do
            SetVehicleLights(vehicle, 2)
            Citizen.Wait(300)
            SetVehicleLights(vehicle, 0)
            Citizen.Wait(300)
        end
    end)
end

function DrawText3D(x, y, scale, text, font)
    SetTextFont(font)
    SetTextProportional(1)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 215)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(1)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end
