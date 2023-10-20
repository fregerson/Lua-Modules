---
-- @Liquipedia
-- wiki=osu
-- page=Module:MatchSummary
--
-- Please see https://github.com/Liquipedia/Lua-Modules to contribute
--

local Abbreviation = require('Module:Abbreviation')
local Class = require('Module:Class')
local Logic = require('Module:Logic')
local Lua = require('Module:Lua')
local String = require('Module:StringUtils')
local Table = require('Module:Table')

local DisplayHelper = Lua.import('Module:MatchGroup/Display/Helper', {requireDevIfEnabled = true})
local MatchSummary = Lua.import('Module:MatchSummary/Base', {requireDevIfEnabled = true})

local EPOCH_TIME = '1970-01-01 00:00:00'
local EPOCH_TIME_EXTENDED = '1970-01-01T00:00:00+00:00'

local GREEN_CHECK = '<i class="fa fa-check forest-green-text" style="width: 14px; text-align: center" ></i>'
local NO_CHECK = '[[File:NoCheck.png|link=]]'
local MAP_VETO_START = '<b>Start Map Veto</b>'
local ARROW_LEFT = '[[File:Arrow sans left.svg|15x15px|link=|Left team starts]]'
local ARROW_RIGHT = '[[File:Arrow sans right.svg|15x15px|link=|Right team starts]]'
local NONE = '-'
local TBD = Abbreviation.make('TBD', 'To Be Determined') --[[@as string]]
local ICONS = {
	check = GREEN_CHECK,
}

local LINK_DATA = {
	preview = {icon = 'File:Preview Icon32.png', text = 'Preview'},
	mplink = {icon = 'File:Osu single color allmode.png', text = 'Match Data'},
	['mplink2'] = {icon = 'File:Osu single color allmode.png', text = 'Match Data'},
	['mplink3'] = {icon = 'File:Osu single color allmode.png', text = 'Match Data'},
}

local VETO_TYPE_TO_TEXT = {
	ban = 'BAN',
	pick = 'PICK',
	protect = 'PROTECT',
	decider = 'DECIDER',
	defaultban = 'DEFAULT BAN',

}
local CustomMatchSummary = {}

-- Map Veto Class
---@class osuMapVeto: MatchSummaryRowInterface
---@operator call: osuMapVeto
---@field root Html
---@field table Html
local MapVeto = Class.new(
	function(self)
		self.root = mw.html.create('div'):addClass('brkts-popup-mapveto')
		self.table = self.root:tag('table')
			:addClass('wikitable-striped'):addClass('collapsible'):addClass('collapsed')
		self:createHeader()
	end
)

---@return osuMapVeto
function MapVeto:createHeader()
	self.table:tag('tr')
		:tag('th'):css('width','33%'):done()
		:tag('th'):css('width','34%'):wikitext('Map Veto'):done()
		:tag('th'):css('width','33%'):done()
	return self
end

---@param firstVeto number?
---@param format string?
---@return osuMapVeto
function MapVeto:vetoStart(firstVeto, format)
	format = format and ('Veto format: ' .. format) or nil
	local textLeft
	local textCenter
	local textRight
	if firstVeto == 1 then
		textLeft = MAP_VETO_START
		textCenter = ARROW_LEFT
		textRight = format
	elseif firstVeto == 2 then
		textLeft = format
		textCenter = ARROW_RIGHT
		textRight = MAP_VETO_START
	else return self end

	self.table:tag('tr'):addClass('brkts-popup-mapveto-vetostart')
		:tag('th'):wikitext(textLeft or ''):done()
		:tag('th'):wikitext(textCenter):done()
		:tag('th'):wikitext(textRight or ''):done()

	return self
end

---@param map1 string?
---@param map2 string?
---@return string, string
function MapVeto._displayMaps(map1, map2)
	if Logic.isEmpty(map1) and Logic.isEmpty(map2) then
		return TBD, TBD
	end

	return Logic.isEmpty(map1) and NONE or ('[[' .. map1 .. ']]'),
		Logic.isEmpty(map2) and NONE or ('[[' .. map2 .. ']]')
end

---@param vetoType string?
---@param map1 string?
---@param map2 string?
---@return osuMapVeto
function MapVeto:addRound(vetoType, map1, map2)
	map1, map2 = MapVeto._displayMaps(map1, map2)

	local vetoText = VETO_TYPE_TO_TEXT[vetoType]

	if not vetoText then return self end

	local class = 'brkts-popup-mapveto-' .. vetoType

	local row = mw.html.create('tr'):addClass('brkts-popup-mapveto-vetoround')

	self:addColumnVetoMap(row, map1)
	self:addColumnVetoType(row, class, vetoText)
	self:addColumnVetoMap(row, map2)

	self.table:node(row)
	return self
end

---@param row Html
---@param styleClass string
---@param vetoText string
---@return osuMapVeto
function MapVeto:addColumnVetoType(row, styleClass, vetoText)
	row:tag('td')
		:tag('span')
			:addClass(styleClass)
			:addClass('brkts-popup-mapveto-vetotype')
			:wikitext(vetoText)
	return self
end

---@param row Html
---@param map string
---@return osuMapVeto
function MapVeto:addColumnVetoMap(row, map)
	row:tag('td'):wikitext(map):done()
	return self
end

---@return Html
function MapVeto:create()
	return self.root
end

---@param args table
---@return Html
function CustomMatchSummary.getByMatchId(args)
	return MatchSummary.defaultGetByMatchId(CustomMatchSummary, args)
end

---@param match MatchGroupUtilMatch
---@param footer MatchSummaryFooter
---@return MatchSummaryFooter
function CustomMatchSummary.addToFooter(match, footer)
	footer = MatchSummary.addVodsToFooter(match, footer)

	return footer:addLinks(LINK_DATA, match.links)
end

---@param match MatchGroupUtilMatch
---@return MatchSummaryBody
function CustomMatchSummary.createBody(match)
	local body = MatchSummary.Body()

	if match.dateIsExact or (match.date ~= EPOCH_TIME_EXTENDED and match.date ~= EPOCH_TIME) then
		-- dateIsExact means we have both date and time. Show countdown
		-- if match is not epoch=0, we have a date, so display the date
		body:addRow(MatchSummary.Row():addElement(
			DisplayHelper.MatchCountdownBlock(match)
		))
	end

	-- Iterate each map
	for _, game in ipairs(match.games) do
		if game.map then
			body:addRow(CustomMatchSummary._createMapRow(game))
		end
	end

	-- Add Match MVP(s)
	if match.extradata.mvp then
		local mvpData = match.extradata.mvp
		if not Table.isEmpty(mvpData) and mvpData.players then
			local mvp = MatchSummary.Mvp()
			for _, player in ipairs(mvpData.players) do
				mvp:addPlayer(player)
			end
			mvp:setPoints(mvpData.points)

			body:addRow(mvp)
		end

	end

		-- Add the Map Vetoes
	if match.extradata.mapveto then
		local vetoData = match.extradata.mapveto
		if vetoData then
			local mapVeto = MapVeto()
			if vetoData.vetostart then
				mapVeto:vetoStart(tonumber(vetoData.vetostart), vetoData.format)
			end

			for _,vetoRound in ipairs(vetoData) do
				mapVeto:addRound(vetoRound.type, vetoRound.team1, vetoRound.team2)
			end

			body:addRow(mapVeto)
		end
	end

	return body
end

---@param game MatchGroupUtilGame
---@param opponentIndex integer
---@return Html
function CustomMatchSummary._gameScore(game, opponentIndex)
	local score = game.scores[opponentIndex] or ''
	return mw.html.create('div'):wikitext(score)
end

---@param game MatchGroupUtilGame
---@return MatchSummaryRow
function CustomMatchSummary._createMapRow(game)
	local row = MatchSummary.Row()

	-- Add Header
	if Logic.isNotEmpty(game.header) then
		local mapHeader = mw.html.create('div')
			:wikitext(game.header)
			:css('font-weight','bold')
			:css('font-size','85%')
			:css('margin','auto')
		row:addElement(mapHeader)
		row:addElement(MatchSummary.Break():create())
	end

	local centerNode = mw.html.create('div')
		:addClass('brkts-popup-spaced')
		:wikitext(CustomMatchSummary._getMapDisplay(game))
		:css('text-align', 'center')

	if game.resultType == 'np' then
		centerNode:addClass('brkts-popup-spaced-map-skip')
	end

	local leftNode = mw.html.create('div')
		:addClass('brkts-popup-spaced')
		:node(CustomMatchSummary._createCheckMarkOrCross(game.winner == 1, 'check'))
		:node(CustomMatchSummary._gameScore(game, 1))

	local rightNode = mw.html.create('div')
		:addClass('brkts-popup-spaced')
		:node(CustomMatchSummary._gameScore(game, 2))
		:node(CustomMatchSummary._createCheckMarkOrCross(game.winner == 2, 'check'))

	row:addElement(leftNode)
		:addElement(centerNode)
		:addElement(rightNode)

	row:addClass('brkts-popup-body-game')
		:css('overflow', 'hidden')

	-- Add Comment
	if Logic.isNotEmpty(game.comment) then
		row:addElement(MatchSummary.Break():create())
		local comment = mw.html.create('div')
			:wikitext(game.comment)
			:css('margin', 'auto')
		row:addElement(comment)
	end

	return row
end

---@param game MatchGroupUtilGame
---@return string
function CustomMatchSummary._getMapDisplay(game)
	local mapDisplay = '[[' .. game.map .. ']]'
	return mapDisplay
end

---@param showIcon boolean?
---@param iconType string?
---@return Html
function CustomMatchSummary._createCheckMarkOrCross(showIcon, iconType)
	local container = mw.html.create('div')
	container:addClass('brkts-popup-spaced'):css('line-height', '27px')

	if showIcon then
		return container:node(ICONS[iconType])
	end
	return container:node(NO_CHECK)
end

return CustomMatchSummary
