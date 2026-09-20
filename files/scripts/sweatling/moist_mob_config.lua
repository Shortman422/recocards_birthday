-- moist_mob_config.lua
-- Settings for Moist Mobbing sub/gift detection. Always needed -- this is the
-- single source of truth the streaming hook and spawner read at load.
--
-- DEBUG vs LIVE: the "Debug Moist Mobbing" mod setting
-- (recocards_birthday.debug_moist_mobbing) picks between two detection profiles that
-- differ ONLY in `bot_name` + `triggers` (everything else is shared):
--   * DEBUG: bot_name = "" (match ANY sender, so you can self-type test
--     messages) and simple "sub"/"gift" triggers. Also auto-plays the recorded
--     dnkM burst (simulate_chat_moist_mob) so a lone tester sees a full mob.
--   * LIVE:  bot_name = "WizeBot" and the real WizeBot announcement patterns.
-- The consuming check (is_configured_bot in streaming_hook.lua) treats an empty
-- bot_name as "match any sender".
--
-- DETECTION MODEL: a chat message triggers Moist Mobbing when
--   (a) it is sent by `bot_name` (case-insensitive; "" matches ANY sender), AND
--   (b) its text contains ANY trigger entry's `phrase` (plain substring).
-- We do NOT distinguish sub vs resub vs gift -- every sub/gift is celebrated
-- equally. We DO want the celebrant's NAME: the SUBSCRIBER (self/re-sub) or the
-- GIFTER (gift) -- never the gift recipient.
--
-- NAME EXTRACTION: each trigger entry may carry a `name` = a Lua PATTERN with
-- ONE capture that pulls the celebrant out of the bot's message text. For the
-- FIRST entry whose `phrase` matches, its `name` pattern (if set) is applied.
-- If `name` is nil or fails to match, we STILL trigger, using `fallback_name`.
--
-- ASCII CAVEAT (observed in-game): the engine decodes chat to ASCII 1-255, so
-- decorative unicode (arrows, gift/person emoji) arrives MANGLED and non-ASCII
-- characters are dropped. Anchor phrases/patterns ONLY on pure-ASCII text (e.g.
-- "RE-SUB", "NEW SUB", "subscriptions to the community"). A subscriber/gifter
-- with a NON-ASCII display name may not be extractable from the message; that's
-- fine -- we fall back to `fallback_name` and still celebrate.

-- Is the "Debug Moist Mobbing" mod setting on? Guarded for sandboxed contexts
-- that lack ModSettingGet (defaults to LIVE if it can't be read).
local function debug_moist_mobbing()
    if ModSettingGet == nil then return false end
    return ModSettingGet("recocards_birthday.debug_moist_mobbing") == true
end

local debug_enabled = debug_moist_mobbing()

-- DEBUG profile: any sender ("" bot_name) + self-typable "sub"/"gift" triggers.
-- The `name` pattern grabs a word after a colon (e.g. "test sub: alice"); when
-- it doesn't match we fall back to `fallback_name`.
local debug_profile = {
    bot_name = "",
    triggers = {
        { phrase = "sub",  name = ": ([%w_]+)" },
        { phrase = "gift", name = ": ([%w_]+)" },
    },
}

-- LIVE profile: the real WizeBot on dunkorslam. WizeBot decorates messages with
-- emoji/stars that the engine STRIPS (non-ASCII dropped), so patterns anchor on
-- the ASCII residue. Real formats (shown here with emoji, then the ASCII residue
-- the engine actually delivers):
--   RE-SUB, ascii display name:
--     "* RE-SUB * SchafersGaming (+23) *" -> " RE-SUB  SchafersGaming (+23) "
--   RE-SUB, NON-ascii display name (login kept in parens):
--     "* RE-SUB * <jp> (creamy_mami) (+42) *" -> " RE-SUB   (creamy_mami) (+42) "
--   NEW SUB, self:
--     "* NEW SUB * Alacron5 (+14) *" -> " NEW SUB  Alacron5 (+14) "
--   NEW SUB, gifted (celebrate the GIFTER, not the recipient):
--     "* NEW SUB * chasemynuts (+4) * (gift Offered by shankmo)"
--       -> " NEW SUB  chasemynuts (+4)  ( Offered by shankmo)"
--   COMMUNITY bulk gift (celebrate the GIFTER):
--     "gift junjiwow * just offered 10 subscriptions to the community!"
--       -> " junjiwow  just offered 10 subscriptions to the community!"
--
-- ORDER MATTERS: matched_trigger returns the FIRST entry whose plain-substring
-- `phrase` is present. A gifted NEW SUB contains BOTH "Offered by" and "NEW SUB",
-- so the gifter ("Offered by") entry MUST come before the plain "NEW SUB" entry
-- to celebrate the gifter rather than the recipient.
--
-- The RE-SUB / self-NEW-SUB name pattern captures the login immediately before
-- " (+N)": `([%w_]+)%)?%s*%(%+`. The `%)?` absorbs the closing paren in the
-- non-ASCII-display-name form " (creamy_mami) (+42)", and the greedy [%w_]+ lands
-- on the login token regardless of any stripped-emoji whitespace before it.
local live_profile = {
    bot_name = "WizeBot",
    triggers = {
        -- community bulk gift: gifter before "just offered". (Checked first; its
        -- message has neither RE-SUB nor NEW SUB, but keep it early for clarity.)
        { phrase = "just offered", name = "([%w_]+)%s+just offered" },
        -- gifted NEW SUB: celebrate the GIFTER after "Offered by". MUST precede
        -- the plain "NEW SUB" entry (a gifted sub contains both phrases).
        { phrase = "Offered by", name = "Offered by%s+([%w_]+)" },
        -- resub: login sits right before " (+N)" (handles both the plain name and
        -- the "(login) (+N)" non-ASCII-display-name form).
        { phrase = "RE-SUB", name = "([%w_]+)%)?%s*%(%+" },
        -- self NEW SUB: same "login before (+N)" capture.
        { phrase = "NEW SUB", name = "([%w_]+)%)?%s*%(%+" },
    },
}

local profile = debug_enabled and debug_profile or live_profile

return {
    -- Profile-driven (DEBUG vs LIVE): see above.
    bot_name = profile.bot_name,
    triggers = profile.triggers,

    -- Shared across both profiles.
    fallback_name = "someone",

    -- MOB keyword: any chatter (NOT just the bot) whose message contains any of
    -- these plain substrings joins the mob pulse -- a nameless sweatling spawns
    -- in the ring around the gifter -- but ONLY while the sub/gift window is
    -- open. Matched case-sensitively.
    mob_phrases = { "dnkMM", "dnkM" },

    -- Lifetimes (frames) set on each spawn's LifetimeComponent. Single source of
    -- truth: the entity XML has a placeholder that we overwrite at spawn.
    --   mob: a ring sweatling; also the ring-LOCK duration (a ring locks when
    --        its last slot fills and unlocks this many frames later).
    --   gifter: the central sweatling; persists the whole 30s window.
    mob_lifetime_frames    = 3 * 60,     -- 3s
    gifter_lifetime_frames = 30 * 60,    -- 30s (matches the window)

    -- When true, a sub/gift also auto-plays the recorded dnkM burst
    -- (moist_mob_test_data.lua) into the mob, so a lone tester sees a full pulse
    -- without a live chat. Tied to debug mode -- never replays on a live channel.
    simulate_chat_moist_mob = debug_enabled,
}
