fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
ox_lib 'locale'
lua54 'yes'

description 'rsg-inventory'
version '3.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/inventory_rules.lua', -- Единые правила метаданных и количества для клиента и сервера.
    'shared/helpers.lua',
}

client_scripts {
    'client/session.lua', -- Запуск игровых циклов только после входа персонажа.
    'client/dataview.lua',
    'client/drops/functions.lua',
    'client/functions.lua',
    'client/commands.lua',
    'client/item_index.lua', -- Кеш количества, веса и вместимости; загружается до HasItem.
    'client/exports.lua',
    'client/events.lua',
    'client/drops/events.lua',
    'client/ui/events.lua',
    'client/ui/callbacks.lua',
    'client/ui/trade_events.lua',
    'client/ui/trade_callbacks.lua',
    'client/ui/trade_target.lua',
    'client/drops/ui/callbacks.lua',
    'client/main.lua',
    'client/drops/loops.lua',
	'client/inputwheel.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/functions.lua',
    'server/inventory_ops.lua', -- Проверка и подготовка операций без изменения живых предметов.
    'server/item_index.lua', -- Автоматические индексы всех предметов, веса и занятых слотов.
	
	'server/item_states.lua',
	
    'server/shops/functions.lua',
    'server/exports.lua',
    'server/shops/exports.lua',
    'server/main.lua',
    'server/events/*.lua',
    'server/drops/events/*.lua',
    'server/shops/events/*.lua',
    'server/commands.lua',
	'server/inputwheel.lua',
    'server/versionchecker.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/main.css',
    'html/app.js',
	'html/effects-config.js',
    "shared/*.lua", --- for lib.load
    'locales/*.json',
    'html/images/*.png',
	'html/effects/*.png',
    'html/*.png',
    'html/assets/*.*',
}
