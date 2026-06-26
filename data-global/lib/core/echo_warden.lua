-- ============================================================================
-- Echo Raids / Echo Wardens - shared library (pure Lua)
-- IMPORTANT: lives in data/libs/functions/ (NOT data/global/lib/, which does
-- not exist in this fork). Registered from data/libs/functions/load.lua so it
-- loads before every revscriptsys data/scripts file at boot.
--
-- Verified APIs only:
--   Monster:setForgeStack/getForgeStack (C++; applyStacks buffs HP, icon "forge")
--   Creature:setMaxHealth/setHealth/getMaxHealth/setIcon (C++)
--   Monster:setStorageValue/getStorageValue (Lua fallback in monster.lua;
--       getStorageValue returns -1 when unset, so compare with == 1)
--   MonsterType:BestiaryStars/raceId/name/isRewardBoss/bossRace
--   Player:addCharmPoints/sendQuestProgress/kv():scoped() (boolean round-trips)
--   Game.createMonster(name,pos,extended,force,master,spawnEffect) (returns nil on fail)
--   Game.getSpectators(pos, multifloor, onlyPlayer, minX,maxX,minY,maxY)
--   addEvent, Tile:hasFlag/getGround, Position:sendMagicEffect
-- ============================================================================

EchoWarden = EchoWarden or {}

-- ----------------------------- TUNABLES -------------------------------------
EchoWarden.PORTAL_ITEM_ID = 54133
EchoWarden.PORTAL_ATTR_KIND = "echoKind" -- item:setCustomAttribute key
EchoWarden.PORTAL_TTL_MS = 120000 -- portal self-removes after 2 min (counted from when it appears)
EchoWarden.PORTAL_DELAY_MS = 30000 -- portal appears 30s AFTER the kill

EchoWarden.SPAWN_CHANCE_NUM = 200000 -- 100 / 200000 = 0.05%
EchoWarden.SPAWN_CHANCE_DEN = 200000

-- step outcome weights (must cover 1..100)
EchoWarden.OUT_REGULAR_MAX = 78 -- (unused: runRaid always spawns a warden raid)
EchoWarden.OUT_INFLUENCED_MAX = 98 -- (unused: runRaid always spawns a warden raid)

EchoWarden.REGULAR_MIN, EchoWarden.REGULAR_MAX = 5, 8
EchoWarden.INFLUENCED_MIN, EchoWarden.INFLUENCED_MAX = 3, 5
EchoWarden.WARDEN_ADDS_MIN, EchoWarden.WARDEN_ADDS_MAX = 7, 12
EchoWarden.MIN_INFLUENCED = 2 -- every raid spawns at least this many influenced (with level)
EchoWarden.WARDEN_ADDS_WINDOW_MS = 5000 -- trickle window for warden adds

EchoWarden.WARDEN_HP_MULT = 4.0
EchoWarden.WARDEN_ATK_MULT = 1.5 -- only used if optional C++ applied
EchoWarden.USE_CPP_ATK = true -- set true only if applyEchoWarden compiled

EchoWarden.AURA_RANGE = 5
EchoWarden.AURA_MS = 2000

EchoWarden.SCATTER_RADIUS = 3 -- (unused now: spawns land on the portal tile)
EchoWarden.SPAWN_EFFECT = CONST_ME_NONE -- monsters are born silently (no teleport flash)
EchoWarden.SPAWN_STEP_MS = 400 -- delay between each monster (born one after another)

-- creature storage flags (Monster:get/setStorageValue Lua fallback; -1 when unset)
EchoWarden.STORAGE_IS_WARDEN = 54133 -- 1 = this monster is THE echo warden
EchoWarden.STORAGE_IS_SPAWNED = 54134 -- 1 = spawned by an echo raid (never re-triggers)
EchoWarden.KV_SCOPE = "echo_warden" -- player:kv():scoped(...) for first-kill

-- first-kill charm reward by bestiary difficulty (stars). 0-star commons fall back to 10.
EchoWarden.CHARM_BY_STARS = { [0] = 1, [1] = 10, [2] = 15, [3] = 20, [4] = 25, [5] = 30 } -- charm by difficulty, range 1..30 (tunable)

-- runtime map: wardenCreatureId -> baseKindName (aura loop + reward lookup)
EchoWarden.activeWardens = EchoWarden.activeWardens or {}

-- ----------------------------- HELPERS --------------------------------------

-- find a walkable tile around a center position to scatter spawns
function EchoWarden.pickTile(center, radius)
	radius = radius or EchoWarden.SCATTER_RADIUS
	for _ = 1, 12 do
		local dx = math.random(-radius, radius)
		local dy = math.random(-radius, radius)
		local p = Position(center.x + dx, center.y + dy, center.z)
		local tile = Tile(p)
		if tile and tile:getGround() and not tile:hasFlag(TILESTATE_BLOCKSOLID) and not tile:hasFlag(TILESTATE_PROTECTIONZONE) and not tile:hasFlag(TILESTATE_FLOORCHANGE) and not tile:hasFlag(TILESTATE_TELEPORT) then
			return p
		end
	end
	return center -- fallback: stack on center; force=true lets the engine resolve
end

-- mark a freshly spawned raid creature so it can NEVER re-trigger a portal
function EchoWarden.markSpawned(m)
	if m and m.setStorageValue then
		m:setStorageValue(EchoWarden.STORAGE_IS_SPAWNED, 1)
	end
end

-- INFLUENCED: lighter glow + HP buff (setForgeStack -> Influenced icon + applyStacks),
-- classification stays NORMAL so vanilla loot, no sliver/forge bookkeeping.
function EchoWarden.makeInfluenced(m)
	if m and m.getForgeStack and m:getForgeStack() == 0 then
		m:setForgeStack(math.random(1, 5))
	end
end

-- ECHO WARDEN: stronger + intense fiendish glow, NO rename, classification NORMAL.
function EchoWarden.makeWarden(w, kindName)
	if not w then
		return
	end
	if EchoWarden.USE_CPP_ATK and w.applyEchoWarden then
		w:applyEchoWarden(EchoWarden.WARDEN_HP_MULT, EchoWarden.WARDEN_ATK_MULT)
	else
		w:setMaxHealth(math.floor(w:getMaxHealth() * EchoWarden.WARDEN_HP_MULT))
		w:setHealth(w:getMaxHealth())
		-- intense glow, no badge; key "warden" (NOT "forge") so it never collides with setForgeStack
		w:setIcon("warden", CreatureIconCategory_Modifications, CreatureIconModifications_Fiendish, 0)
	end
	w:setStorageValue(EchoWarden.STORAGE_IS_WARDEN, 1)
	w:setStorageValue(EchoWarden.STORAGE_IS_SPAWNED, 1) -- warden never re-triggers either
	EchoWarden.activeWardens[w:getId()] = kindName
end

-- EMPOWER-NEARBY aura (pure Lua); same-kind wanderers get influenced over time.
function EchoWarden.aura(wardenId, kindName)
	local w = Monster(wardenId)
	if not w or w:isRemoved() or w:getHealth() <= 0 then
		EchoWarden.activeWardens[wardenId] = nil
		return
	end
	local p = w:getPosition()
	local r = EchoWarden.AURA_RANGE
	for _, c in ipairs(Game.getSpectators(p, false, false, r, r, r, r)) do
		local m = c:getMonster()
		if m and m:getId() ~= wardenId and m:getName() == kindName and m.getForgeStack and m:getForgeStack() == 0 and m:getStorageValue(EchoWarden.STORAGE_IS_WARDEN) ~= 1 then
			EchoWarden.makeInfluenced(m)
			EchoWarden.markSpawned(m) -- aura-empowered wanderers also stop re-triggering
		end
	end
	addEvent(EchoWarden.aura, EchoWarden.AURA_MS, wardenId, kindName)
end

-- Spawn `remaining` monsters of `kind` ONE AT A TIME, all on the portal tile (cx,cy,cz),
-- `stepMs` apart, with NO spawn effect. force=true lets them stack; they spread out as
-- they path toward the player(s). asInfluenced=true gives each the lighter influenced glow.
-- Position is passed as components (not userdata) so addEvent never holds a stale ref.
function EchoWarden.trickleSpawn(kindName, cx, cy, cz, remaining, stepMs, asInfluenced)
	if remaining <= 0 then
		return
	end
	local m = Game.createMonster(kindName, Position(cx, cy, cz), false, true, nil, EchoWarden.SPAWN_EFFECT)
	if m then
		EchoWarden.markSpawned(m)
		if asInfluenced then
			EchoWarden.makeInfluenced(m)
		end
	end
	addEvent(EchoWarden.trickleSpawn, stepMs, kindName, cx, cy, cz, remaining - 1, stepMs, asInfluenced)
end

-- full raid resolution when a portal is stepped
-- Create the echo portal on a tile; called via addEvent PORTAL_DELAY_MS after the kill.
-- Position passed as components so addEvent never holds stale userdata.
function EchoWarden.spawnPortal(px, py, pz, kindName)
	local pos = Position(px, py, pz)
	local tile = Tile(pos)
	if not tile or not tile:getGround() then
		return
	end
	local portal = Game.createItem(EchoWarden.PORTAL_ITEM_ID, 1, pos)
	if not portal then
		return
	end
	portal:setCustomAttribute(EchoWarden.PORTAL_ATTR_KIND, kindName)
	pos:sendMagicEffect(CONST_ME_TELEPORT)
	-- failsafe cleanup if nobody steps on it
	addEvent(function(qx, qy, qz)
		local t = Tile(Position(qx, qy, qz))
		if t then
			local it = t:getItemById(EchoWarden.PORTAL_ITEM_ID)
			if it then
				it:remove()
			end
		end
	end, EchoWarden.PORTAL_TTL_MS, px, py, pz)
end

function EchoWarden.runRaid(kindName, center)
	if not kindName or kindName == "" then
		return
	end
	local cx, cy, cz = center.x, center.y, center.z
	local step = EchoWarden.SPAWN_STEP_MS

	-- Every echo raid is a WARDEN raid: always >= 1 Echo Warden + >= MIN_INFLUENCED influenced
	-- ("with level"), the rest normal adds. The portal's rarity gates the encounter, not the outcome.
	local w = Game.createMonster(kindName, Position(cx, cy, cz), false, true, nil, EchoWarden.SPAWN_EFFECT)
	if w then
		EchoWarden.makeWarden(w, kindName)
		addEvent(EchoWarden.aura, EchoWarden.AURA_MS, w:getId(), kindName)
	end

	local adds = math.random(EchoWarden.WARDEN_ADDS_MIN, EchoWarden.WARDEN_ADDS_MAX)
	local influencedCount = math.min(EchoWarden.MIN_INFLUENCED, adds)
	EchoWarden.trickleSpawn(kindName, cx, cy, cz, influencedCount, step, true)
	if adds > influencedCount then
		EchoWarden.trickleSpawn(kindName, cx, cy, cz, adds - influencedCount, step, false)
	end
end

-- FIRST-KILL charm + banner (per player, per creature type). Returns true if granted.
function EchoWarden.grantReward(player, baseKind)
	if not player or not baseKind or baseKind == "" then
		return false
	end
	local kv = player:kv():scoped(EchoWarden.KV_SCOPE)
	if kv:get(baseKind) then
		return false
	end
	local mt = MonsterType(baseKind)
	local stars = (mt and mt:BestiaryStars()) or 0
	local amount = EchoWarden.CHARM_BY_STARS[stars] or EchoWarden.CHARM_BY_STARS[0]
	player:addCharmPoints(amount)
	kv:set(baseKind, true)
	-- Real "Echo Warden Killed" banner (0x75 subtype 0x0e): client shows the creature by raceId + charm points.
	local raceId = (mt and mt:raceId()) or 0
	if raceId > 0 then
		player:sendLeaderMonsterKilledBanner(raceId, amount)
	end
	return true
end
