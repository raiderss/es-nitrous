Config = {}

Config = {
    Framework = 'QBCore',  -- QBCore or ESX or OLDQBCore or NewESX
    NitroItem = "nitrous", -- item to install nitro to a vehicle
    NitroControl = "H",
    NitroForce = 40.0, -- Nitro force when player using nitro
    RemoveNitroOnpress = 2, -- Determines of how much you want to remove nitro when player press nitro key
}

function GetFramework()
    local Get = nil
    if Config.Framework == "ESX" then
        while Get == nil do
            TriggerEvent('esx:getSharedObject', function(Set) Get = Set end)
            Citizen.Wait(0)
        end
    elseif Config.Framework == "NewESX" then
        Get = exports['es_extended']:getSharedObject()
    elseif Config.Framework == "QBCore" then
        Get = exports["qb-core"]:GetCoreObject()
    elseif Config.Framework == "OLDQBCore" then
        while Get == nil do
            TriggerEvent('QBCore:GetObject', function(Set) Get = Set end)
            Citizen.Wait(200)
        end
    end
    return Get
end