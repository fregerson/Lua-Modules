---
-- @Liquipedia
-- wiki=commons
-- page=Module:Infobox/Game
--
-- Please see https://github.com/Liquipedia/Lua-Modules to contribute
--

local Class = require('Module:Class')
local Logic = require('Module:Logic')
local Lua = require('Module:Lua')
local Namespace = require('Module:Namespace')
local Table = require('Module:Table')
local Variables = require('Module:Variables')

local BasicInfobox = Lua.import('Module:Infobox/Basic', {requireDevIfEnabled = true})
local Links = Lua.import('Module:Links', {requireDevIfEnabled = true})

local Widgets = require('Module:Infobox/Widget/All')
local Cell = Widgets.Cell
local Header = Widgets.Header
local Title = Widgets.Title
local Center = Widgets.Center
local Customizable = Widgets.Customizable
local Builder = Widgets.Builder

---@Class GameInfobox: BasicInfobox
local Game = Class.new(BasicInfobox)

---@param frame Frame
---@return Html
function Game.run(frame)
	local game = Game(frame)
	return game:createInfobox()
end

---@return Html
function Game:createInfobox()
	local infobox = self.infobox
	local args = self.args
	local links = Links.transform(args)

	local widgets = {
		Header{
			name = args.name,
			image = args.image,
			imageDark = args.imagedark or args.imagedarkmode,
			size = args.imagesize,
		},
		Center{content = {args.caption}},
		Title{name = 'Game Information'},
		Cell{name = 'Developer', content = self:getAllArgsForBase(args, 'developer'), options = {makeLink = true}},
		Cell{name = 'Publisher', content = self:getAllArgsForBase(args, 'publisher'), options = {makeLink = true}},
		Cell{name = 'Release Date(s)', content = self:getAllArgsForBase(args, 'releasedate')},
		Cell{name = 'Platforms', content = self:getAllArgsForBase(args, 'platform')},
		Customizable{id = 'custom', children = {}},
		Builder{
			builder = function()
				if not Table.isEmpty(links) then
					return {
						Title{name = 'Links'},
						Widgets.Links{content = links}
					}
				end
			end
		},
		Center{content = {args.footnotes}},
	}

	-- Store LPDB data and Wiki-variables
	if self:shouldStore(args) then
		self:_setLpdbData(args, links)
	end

	return infobox:widgetInjector(self:createWidgetInjector()):build(widgets)
end

---@param args table
---@param links table
function Game:_setLpdbData(args, links)
	local name = args.romanized_name or self.name

	local lpdbData = {
		name = name,
		image = args.image,
		imagedark = args.imagedark,
		date = args.releasedate,
		type = 'game',
		extradata = {
			developer = args.developer,
			publisher = args.publisher,
			platform = args.platform,
			links = mw.ext.LiquipediaDB.lpdb_create_json(
				Links.makeFullLinksForTableItems(links or {}, 'game')
			),
		}
	}

	lpdbData = self:addToLpdb(lpdbData, args)

	lpdbData.extradata = mw.ext.LiquipediaDB.lpdb_create_json(lpdbData.extradata or {})
	mw.ext.LiquipediaDB.lpdb_datapoint('game_' .. self.name, lpdbData)
end

--- Allows for overriding this functionality
---@param lpdbData table
---@param args table
---@return table
function Game:addToLpdb(lpdbData, args)
	return lpdbData
end

--- Allows for overriding this functionality
---@param args table
---@return boolean
function Game:shouldStore(args)
	return Namespace.isMain() and not Logic.readBool(Variables.varDefault('disable_LPDB_storage'))
end

return Game
