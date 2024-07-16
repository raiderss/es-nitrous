fx_version 'adamant'
games {'gta5'}

client_script "client.lua"

server_scripts {
	'@mysql-async/lib/MySQL.lua',
	'server.lua'
}

shared_scripts {
'config.lua'
}

description "EyesStore"
author "Raider#0101"
version '1.0.0'
repository 'https://discord.com/invite/EkwWvFS'

lua54 'yes'