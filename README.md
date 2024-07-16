# Nitrous Script for FiveM

![Nitrous Script Preview](https://media.discordapp.net/attachments/627114895183446016/1262694156866686998/nitros-github.png?ex=66978712&is=66963592&hm=922f0b39f5f20e13fa8fbc7e4ffe0c9e355f8a7604c928a99badc739fa9234d8&=&format=webp&quality=lossless&width=1609&height=905)

[![YouTube Subscribe](https://img.shields.io/badge/YouTube-Subscribe-red?style=for-the-badge&logo=youtube)](https://youtu.be/_z_xKWVrZmg)
[![Discord](https://img.shields.io/badge/Discord-Join-blue?style=for-the-badge&logo=discord)](https://discord.gg/EkwWvFS)
[![Tebex Store](https://img.shields.io/badge/Tebex-Store-green?style=for-the-badge&logo=shopify)](https://eyestore.tebex.io/)

Integrate this nitrous script into your FiveM server to enhance your vehicle customization experience. This script uses `qb-target` and interacts with the `nitrous` item to allow players to install nitrous on their vehicles dynamically.

## Script Overview

This script allows players to approach a vehicle, target the nitrous item, and initiate a progress bar. Once the progress is complete, the vehicle will have nitrous installed, providing an enhanced driving experience.

### Code Implementation

Here's the implementation of the nitrous script for your FiveM server:

```lua
-- qb-target setup
exports['qb-target']:AddTargetModel('car', {
    options = {
        {
            event = "nitrous:install",
            icon = "fas fa-wrench",
            label = "Install Nitrous",
            item = "nitrous",
        },
    },
    distance = 2.5,
})

-- Register the event for nitrous installation
RegisterNetEvent('nitrous:install')
AddEventHandler('nitrous:install', function(data)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if vehicle and data.item == "nitrous" then
        -- Open the vehicle's hood
        SetVehicleDoorOpen(vehicle, 4, false, false)
        
        -- Focus camera on the engine
        local coords = GetEntityCoords(vehicle)
        local cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", coords.x, coords.y, coords.z + 0.5, 0, 0, 0, 45.0, false, 0)
        PointCamAtEntity(cam, vehicle, 0, 0, 0, true)
        RenderScriptCams(true, false, 0, true, true)

        -- Show progress bar
        exports['progressbar']:Progress({
            name = "installing_nitrous",
            duration = 10000,
            label = "Installing Nitrous...",
            useWhileDead = false,
            canCancel = false,
            controlDisables = {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            },
            animation = {
                animDict = "mini@repair",
                anim = "fixing_a_player",
                flags = 49,
            },
        }, function(status)
            if not status then
                -- Close the hood and reset camera
                SetVehicleDoorShut(vehicle, 4, false)
                RenderScriptCams(false, false, 0, true, true)
                DestroyCam(cam, false)

                -- Install nitrous
                TriggerServerEvent('nitrous:installOnServer', GetVehicleNumberPlateText(vehicle))
                TriggerEvent('chat:addMessage', {
                    color = {255, 0, 0},
                    multiline = true,
                    args = {"System", "Nitrous installed successfully!"}
                })
            end
        end)
    end
end)

-- Server-side event to handle nitrous installation
RegisterNetEvent('nitrous:installOnServer')
AddEventHandler('nitrous:installOnServer', function(plate)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local vehicle = GetVehicleByPlate(plate)
    
    -- Ensure the vehicle exists and the player has nitrous item
    if vehicle and xPlayer.Functions.GetItemByName('nitrous') then
        -- Add nitrous to the vehicle's metadata
        MySQL.Async.execute('UPDATE owned_vehicles SET nitrous = 1 WHERE plate = @plate', {
            ['@plate'] = plate
        })
        
        -- Remove nitrous item from player inventory
        xPlayer.Functions.RemoveItem('nitrous', 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['nitrous'], "remove")
    end
end)
