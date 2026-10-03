extends RefCounted

const CHIKORITA := 152
const NATIONAL_PARK_GROUP := 3
const NATIONAL_PARK_NUMBER := 15
const COOLTRAINER_M_ROW := 0x23

class StarterPackState extends RefCounted:
	var host: Gen2ModHost
	var manifest: PokeModManifest
	var save = null
	var data: Dictionary = {}

	func _init(p_host: Gen2ModHost, p_manifest: PokeModManifest) -> void:
		host = p_host
		manifest = p_manifest

	func save_created(next_save) -> void:
		save = next_save
		data = {}
		_flush()

	func save_activated(next_save) -> void:
		save = next_save
		data = {} if save == null else host.read_save_data(manifest, save)
		if not (data is Dictionary):
			data = {}

	func save_deactivated() -> void:
		save = null
		data = {}

	func flag(key: StringName) -> bool:
		return bool(data.get(key, false))

	func set_flag(key: StringName, value: bool = true) -> void:
		data[key] = value
		_flush()

	func _flush() -> void:
		if save != null:
			host.write_save_data(manifest, save, data)

class ChikoritaActor extends RefCounted:
	var state: StarterPackState
	var world: Gen2WorldAPI = null
	var host: Gen2ModHost = null
	var actor_cell := Vector2i(-1, -1)
	var outbox: Array = []
	var waiting_tag: StringName = &""
	var demo_done := false
	var received := false

	const NPC_SPRITE := 0x23
	const CHIKORITA := 152
	const TEXT1 := &"chiko_intro"
	const DEMO := &"chiko_demo"
	const TEXT2 := &"chiko_after_demo"
	const TEXT3 := &"chiko_offer"
	const GIFT := &"chiko_gift"
	const YES_NO := &"chiko_yes_no"
	const TEXT4 := &"chiko_received"
	const TEXT5 := &"chiko_starter"

	func _init(p_host: Gen2ModHost, p_state: StarterPackState) -> void:
		host = p_host
		state = p_state

	func set_world(next_world: Gen2WorldAPI) -> void:
		world = next_world
		actor_cell = Vector2i(-1, -1)
		outbox.clear()
		waiting_tag = &""
		if world == null or world.current_map == null:
			return
		if int(world.current_map.group) != 3 or int(world.current_map.number) != 15:
			return
		actor_cell = world.player_cell + Vector2i(0, 1)

	func advance_frame() -> void:
		pass

	func sprites() -> Array:
		if world == null or actor_cell.x < 0:
			return []
		return [{
			"sprite": NPC_SPRITE,
			"facing": Gen2WorldSprite.FACING_LEFT,
			"position_cells": Vector2(actor_cell),
			"solid": true,
		}]

	func _starter_species() -> int:
		if host == null:
			return 0
		var progress: Dictionary = host.progress()
		return int(progress.get(&"starter_species", 0))

	func _whitney_defeated() -> bool:
		if host == null:
			return false
		var progress: Dictionary = host.progress()
		var badges: int = int(progress.get(&"badges", 0))
		return (badges & (1 << 2)) != 0

	func _text(text, tag: StringName) -> void:
		outbox.append({"kind": &"text", "text": text, "tag": tag})
		waiting_tag = tag

	func interact(cell: Vector2i, _facing: int) -> bool:
		if cell != actor_cell or waiting_tag != &"":
			return cell == actor_cell
		demo_done = state.flag(&"chikorita_demo_done")
		received = state.flag(&"chikorita_received")

		# Absolute priority: an originally chosen Chikorita can never enter the
		# catch-demo/gift route, even if it later evolves, is traded or released.
		if _starter_species() == CHIKORITA:
			_text("Oh! Is that a CHIKORITA?

You got it from PROF. ELM?

Take good care of it.

They say CHIKORITA have a special connection with nature...

NATIONAL PARK seems like the perfect place for one.", TEXT5)
			return true

		if received:
			_text("Who would have thought...

The POKéMON from the old legend really was CHIKORITA...

It makes me wonder...

Could there be other spirits protecting POKéMON in these woods?", TEXT4)
			return true

		if not demo_done:
			_text("There's an old legend around here...

They say the POKéMON in NATIONAL PARK are protected by a spirit in the woods.

But nobody has ever seen it...

Maybe it's just a myth...
Maybe it's true...

......

Huh?!
What was that?!", TEXT1)
			return true

		if not _whitney_defeated():
			_text("Oh! Could this CHIKORITA really be the protector of the woods...?", TEXT2)
			return true

		_text("Oh! You defeated WHITNEY?

You must be quite the TRAINER!

Maybe CHIKORITA would be happier traveling with you...", TEXT3)
		return true

	func take_requests() -> Array:
		var result := outbox.duplicate()
		outbox.clear()
		return result

	func request_completed(result: Dictionary) -> void:
		var tag: StringName = result.get("tag", &"")
		if tag == &"":
			return

		if tag == TEXT1:
			waiting_tag = DEMO
			outbox.append({"kind": &"catch_demo", "species": CHIKORITA, "level": 5, "tag": DEMO})
			return

		if tag == DEMO:
			demo_done = true
			state.set_flag(&"chikorita_demo_done")
			waiting_tag = &""
			return

		if tag == TEXT3:
			waiting_tag = YES_NO
			outbox.append({"kind": &"yes_no", "text": "Will you take good care of the protector of the woods?", "tag": YES_NO})
			return

		if tag == YES_NO:
			if not bool(result.get("accepted", false)):
				waiting_tag = &""
				return
			waiting_tag = GIFT
			outbox.append({"kind": &"pokemon_gift", "species": CHIKORITA, "level": 5, "tag": GIFT})
			return

		if tag == GIFT:
			waiting_tag = &""
			var ok := bool(result.get("success", result.get("ok", false)))
			if ok:
				received = true
				state.set_flag(&"chikorita_received")
				var lines: Array = []
				if bool(result.get("newly_caught", false)):
					lines.append("CHIKORITA's data was added to the POKéDEX!")
				if result.get("destination", &"") == &"box":
					lines.append("Your party is full.\nCHIKORITA was sent to your BOX.")
				else:
					lines.append("CHIKORITA was added to your party!")
				_text(lines, TEXT4)
			return

		# Plain text completion.
		waiting_tag = &""


class CyndaquilNpcActor extends RefCounted:
	var state: StarterPackState
	var world: Gen2WorldAPI = null
	var host: Gen2ModHost = null
	var actor_cell := Vector2i(-1, -1)
	var outbox: Array = []
	var waiting_tag: StringName = &""
	var talking := false
	var spoken_before_morty := false
	var received := false

	const CYNDAQUIL := 155
	const TEXT_BEFORE := &"cynda_before_morty"
	const TEXT_AFTER_KNOWN := &"cynda_after_morty_known"
	const TEXT_AFTER_NEW := &"cynda_after_morty_new"
	const TEXT_POST := &"cynda_post_gift"
	const TEXT_STARTER := &"cynda_starter"
	const GIFT := &"cynda_gift"

	func _init(p_host: Gen2ModHost, p_state: StarterPackState) -> void:
		host = p_host
		state = p_state

	func set_world(next_world: Gen2WorldAPI) -> void:
		world = next_world
		actor_cell = Vector2i(-1, -1)
		outbox.clear()
		waiting_tag = &""
		talking = false
		if world == null or world.current_map == null:
			return
		if int(world.current_map.group) != 4 or int(world.current_map.number) != 9:
			return
		actor_cell = world.player_cell + Vector2i(-2, -16)

	func advance_frame() -> void:
		pass

	func _talk_facing() -> int:
		if not talking or world == null:
			return Gen2WorldSprite.FACING_RIGHT
		var delta := world.player_cell - actor_cell
		if abs(delta.x) > abs(delta.y):
			return Gen2WorldSprite.FACING_RIGHT if delta.x > 0 else Gen2WorldSprite.FACING_LEFT
		return Gen2WorldSprite.FACING_DOWN if delta.y > 0 else Gen2WorldSprite.FACING_UP

	func sprites() -> Array:
		if world == null or actor_cell.x < 0:
			return []
		return [{
			"sprite": 0x2e,
			"facing": _talk_facing(),
			"position_cells": Vector2(actor_cell),
			"solid": true,
		}]

	func _progress() -> Dictionary:
		if host == null:
			return {}
		return host.progress()

	func _starter_species() -> int:
		return int(_progress().get(&"starter_species", 0))

	func _morty_defeated() -> bool:
		var badges: int = int(_progress().get(&"badges", 0))
		return (badges & (1 << 3)) != 0

	func _text(text, tag: StringName) -> void:
		outbox.append({"kind": &"text", "text": text, "tag": tag})
		waiting_tag = tag

	func interact(cell: Vector2i, _facing: int) -> bool:
		if cell != actor_cell or waiting_tag != &"":
			return cell == actor_cell
		talking = true
		spoken_before_morty = state.flag(&"cyndaquil_spoken_before_morty")
		received = state.flag(&"cyndaquil_received")

		# Test target for this build: an original Cyndaquil starter always gets
		# dialogue 5 and can never enter the gift route.
		if _starter_species() == CYNDAQUIL:
			_text("Oh! Is that a CYNDAQUIL?\n\nYou got it from PROF. ELM?\n\nWhat a sweet little POKéMON.\n\nCYNDAQUIL can be a little timid, but they become very attached to their TRAINER.\n\nTake good care of it.", TEXT_STARTER)
			return true

		if received:
			_text("CYNDAQUIL seems much happier with you.\n\nWhen I found it near the BURNED TOWER, it looked so frightened...\n\nI think it finally found the TRAINER it was waiting for.\n\nTake good care of it.", TEXT_POST)
			return true

		if not _morty_defeated():
			spoken_before_morty = true
			state.set_flag(&"cyndaquil_spoken_before_morty")
			_text("I found a CYNDAQUIL near the BURNED TOWER.\n\nIt seems to be looking for a strong TRAINER.", TEXT_BEFORE)
			return true

		if spoken_before_morty:
			_text("Ah, it's you again.\n\nI heard you defeated MORTY.\n\nYou're just the kind of TRAINER I was hoping to find.\n\nCYNDAQUIL should go with you.", TEXT_AFTER_KNOWN)
		else:
			_text("I found this little one near the BURNED TOWER.\n\nIt was frightened, but it wouldn't leave me.\n\nI think it's waiting for someone stronger than me.\n\nCYNDAQUIL should go with you.", TEXT_AFTER_NEW)
		return true

	func take_requests() -> Array:
		var result := outbox.duplicate()
		outbox.clear()
		return result

	func request_completed(result: Dictionary) -> void:
		var tag: StringName = result.get("tag", &"")
		if tag == &"":
			return
		if tag == TEXT_AFTER_KNOWN or tag == TEXT_AFTER_NEW:
			waiting_tag = GIFT
			outbox.append({"kind": &"pokemon_gift", "species": CYNDAQUIL, "level": 5, "tag": GIFT})
			return
		if tag == GIFT:
			waiting_tag = &""
			if bool(result.get("ok", result.get("success", false))):
				received = true
				state.set_flag(&"cyndaquil_received")
				var lines: Array = []
				if bool(result.get("newly_caught", false)):
					lines.append("CYNDAQUIL's data was added to the POKéDEX!")
				if result.get("destination", &"") == &"box":
					lines.append("Your party is full.\nCYNDAQUIL was sent to your BOX.")
				else:
					lines.append("CYNDAQUIL was added to your party!")
				_text(lines, TEXT_POST)
				return
			talking = false
			return
		waiting_tag = &""
		talking = false

class TotodileNpcActor extends RefCounted:
	var state: StarterPackState
	var host: Gen2ModHost
	var world: Gen2WorldAPI = null
	var actor_cell := Vector2i(-1, -1)
	var home_cell := Vector2i(-1, -1)
	var frame_counter := 0
	var step_pending := false
	var rng := RandomNumberGenerator.new()
	var facing := Gen2WorldSprite.FACING_DOWN
	var talking := false
	var received := false
	var spoken_before_chuck := false
	var waiting_tag: StringName = &""
	var outbox: Array = []

	const TOTODILE := 158
	const TEXT_BEFORE := &"toto_before"
	const TEXT_BEFORE_REPEAT := &"toto_before_repeat"
	const TEXT_AFTER := &"toto_after"
	const TEXT_AFTER_FIRST := &"toto_after_first"
	const TEXT_POST := &"toto_post"
	const TEXT_STARTER := &"toto_starter"
	const GIFT := &"toto_gift"
	const ACTOR_ID := &"totodile_man"
	const STEP_TAG := &"totodile_walk"
	const STEP_EVERY_FRAMES := 180
	const ROAM_X := 3
	const ROAM_Y := 2
	const DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

	func _init(next_host: Gen2ModHost, p_state: StarterPackState) -> void:
		host = next_host
		state = p_state
		rng.randomize()

	func set_world(next_world: Gen2WorldAPI) -> void:
		world = next_world
		actor_cell = Vector2i(-1, -1)
		home_cell = Vector2i(-1, -1)
		frame_counter = 0
		step_pending = false
		talking = false
		waiting_tag = &""
		outbox.clear()
		if world == null or world.current_map == null:
			return
		if int(world.current_map.group) != 22 or int(world.current_map.number) != 3:
			return
		# Start from the confirmed old cell. The first engine step moves him one
		# actual map cell right; that resulting cell becomes his roaming home.
		actor_cell = world.player_cell + Vector2i(-19, -20)
		home_cell = actor_cell + Vector2i.RIGHT
		outbox.append({"kind": &"step", "id": ACTOR_ID, "direction": Vector2i.RIGHT, "tag": STEP_TAG})
		step_pending = true

	func advance_frame() -> void:
		if world == null or actor_cell.x < 0 or step_pending or waiting_tag != &"":
			return
		frame_counter += 1
		if frame_counter < STEP_EVERY_FRAMES:
			return
		frame_counter = 0
		if rng.randi_range(0, 2) == 0:
			return
		var direction: Vector2i = DIRECTIONS[rng.randi_range(0, DIRECTIONS.size() - 1)]
		var candidate := actor_cell + direction
		if abs(candidate.x - home_cell.x) > ROAM_X or abs(candidate.y - home_cell.y) > ROAM_Y:
			return
		outbox.append({"kind": &"step", "id": ACTOR_ID, "direction": direction, "tag": STEP_TAG})
		step_pending = true

	func _starter_species() -> int:
		var progress: Dictionary = host.progress()
		return int(progress.get(&"starter_species", 0))

	func _chuck_defeated() -> bool:
		var progress: Dictionary = host.progress()
		var badges: int = int(progress.get(&"badges", 0))
		# Storm Badge = fifth Johto badge, bit index 4.
		return (badges & (1 << 4)) != 0

	func _talk_facing() -> int:
		if not talking or world == null:
			return facing
		var delta := world.player_cell - actor_cell
		if abs(delta.x) > abs(delta.y):
			return Gen2WorldSprite.FACING_RIGHT if delta.x > 0 else Gen2WorldSprite.FACING_LEFT
		return Gen2WorldSprite.FACING_DOWN if delta.y > 0 else Gen2WorldSprite.FACING_UP

	func sprites() -> Array:
		if world == null or actor_cell.x < 0:
			return []
		return [{
			"id": ACTOR_ID,
			"sprite": 0x2f,
			"facing": _talk_facing(),
			"position_cells": Vector2(actor_cell),
			"solid": true,
		}]

	func _queue_text(tag: StringName, text) -> void:
		waiting_tag = tag
		outbox.append({"kind": &"text", "text": text, "tag": tag})

	func interact(cell: Vector2i, _facing: int) -> bool:
		if cell != actor_cell or waiting_tag != &"":
			return cell == actor_cell
		talking = true
		spoken_before_chuck = state.flag(&"totodile_spoken_before_chuck")
		received = state.flag(&"totodile_received")

		# Original Totodile starter always has priority over Chuck/gift logic.
		if _starter_species() == TOTODILE:
			_queue_text(TEXT_STARTER, [
				"Oh! Is that a TOTODILE?",
				"You got it from PROF. ELM?",
				"What a lively little POKéMON!",
				"TOTODILE are full of energy,\nbut they become strong partners\nwith the right TRAINER.",
				"Take good care of it."
			])
			return true

		if received:
			_queue_text(TEXT_POST, [
				"TOTODILE certainly seems\nhappy with you.",
				"All that energy finally\nhas somewhere to go!",
				"Take it on a great\nadventure, will you?"
			])
			return true

		if not _chuck_defeated():
			if spoken_before_chuck:
				_queue_text(TEXT_BEFORE_REPEAT, [
					"That TOTODILE never seems\nto run out of energy.",
					"It needs someone strong\nenough to handle it."
				])
			else:
				spoken_before_chuck = true
				state.set_flag(&"totodile_spoken_before_chuck")
				_queue_text(TEXT_BEFORE, [
					"I've been watching this TOTODILE\nplay by the sea.",
					"It's full of energy!",
					"Maybe a little too much\nfor an old man like me...",
					"It needs a TRAINER\nwho can keep up with it."
				])
			return true

		if not spoken_before_chuck:
			_queue_text(TEXT_AFTER_FIRST, [
				"I've been watching this TOTODILE\nplay by the sea.",
				"It's full of energy!",
				"Maybe a little too much\nfor an old man like me...",
				"It needs a TRAINER\nwho can keep up with it.",
				"..........",
				"But wait a minute...",
				"You defeated CHUCK!",
				"Ha! Then you're certainly\nstrong enough!",
				"I think TOTODILE has found\nthe TRAINER it needs.",
				"Take good care of it."
			])
			return true

		_queue_text(TEXT_AFTER, [
			"You defeated CHUCK?",
			"Ha! Then you're certainly\nstrong enough!",
			"I think TOTODILE has found\nthe TRAINER it needs.",
			"Take good care of it."
		])
		return true

	func take_requests() -> Array:
		var result := outbox.duplicate()
		outbox.clear()
		return result

	func request_completed(result: Dictionary) -> void:
		var tag: StringName = result.get("tag", &"")
		if tag == &"":
			return
		if tag == STEP_TAG:
			step_pending = false
			if result.has("cell"):
				var c = result["cell"]
				actor_cell = Vector2i(int(c.x), int(c.y))
			if result.has("facing"):
				facing = int(result["facing"])
			# If this was the initial right-step, use the engine-confirmed cell
			# as the centre for subsequent random roaming.
			if home_cell != Vector2i(-1, -1) and actor_cell == home_cell:
				home_cell = actor_cell
			return
		if tag == TEXT_AFTER or tag == TEXT_AFTER_FIRST:
			waiting_tag = GIFT
			outbox.append({"kind": &"pokemon_gift", "species": TOTODILE, "level": 5, "tag": GIFT})
			return
		if tag == GIFT:
			waiting_tag = &""
			if bool(result.get("ok", result.get("success", false))):
				received = true
				state.set_flag(&"totodile_received")
				var lines: Array = []
				if bool(result.get("newly_caught", false)):
					lines.append("TOTODILE's data was added to the POKéDEX!")
				if result.get("destination", &"") == &"box":
					lines.append("Your party is full.\nTOTODILE was sent to your BOX.")
				else:
					lines.append("TOTODILE was added to your party!")
				_queue_text(TEXT_POST, lines)
				return
			talking = false
			return
		waiting_tag = &""
		talking = false

class VermilionTestActor extends RefCounted:
	var state: StarterPackState
	var host: Gen2ModHost
	var world: Gen2WorldAPI = null
	var actor_cell := Vector2i(-1, -1)
	var waiting_tag: StringName = &""
	var received := false
	var talking := false
	var outbox: Array = []

	const TEST_SPRITE := 0x43
	const SQUIRTLE := 7
	const TEXT_BEFORE := &"squirtle_before"
	const TEXT_OFFER := &"squirtle_offer"
	const TEXT_NO := &"squirtle_no"
	const TEXT_YES := &"squirtle_yes"
	const TEXT_POST := &"squirtle_post"
	const GIFT := &"squirtle_gift"
	const YES_NO := &"squirtle_yes_no"

	func _init(next_host: Gen2ModHost, p_state: StarterPackState) -> void:
		host = next_host
		state = p_state

	func set_world(next_world: Gen2WorldAPI) -> void:
		world = next_world
		actor_cell = Vector2i(-1, -1)
		waiting_tag = &""
		talking = false
		outbox.clear()
		if world == null or world.current_map == null:
			return
		if int(world.current_map.group) != 12 or int(world.current_map.number) != 3:
			return
		# Keep the confirmed Vermilion position unchanged.
		actor_cell = world.player_cell + Vector2i(14, 13)

	func advance_frame() -> void:
		pass

	func _thunder_badge() -> bool:
		var progress: Dictionary = host.progress()
		var badges: int = int(progress.get(&"badges", 0))
		# Kanto badges follow the eight Johto bits. Thunder Badge is Kanto badge 3.
		return (badges & (1 << 10)) != 0

	func _talk_facing() -> int:
		if not talking or world == null:
			return Gen2WorldSprite.FACING_RIGHT
		var delta := world.player_cell - actor_cell
		if abs(delta.x) > abs(delta.y):
			return Gen2WorldSprite.FACING_RIGHT if delta.x > 0 else Gen2WorldSprite.FACING_LEFT
		return Gen2WorldSprite.FACING_DOWN if delta.y > 0 else Gen2WorldSprite.FACING_UP

	func sprites() -> Array:
		if world == null or actor_cell.x < 0:
			return []
		return [{"sprite": TEST_SPRITE, "facing": _talk_facing(),
			"position_cells": Vector2(actor_cell), "solid": true}]

	func _queue_text(tag: StringName, text) -> void:
		waiting_tag = tag
		outbox.append({"kind": &"text", "text": text, "tag": tag})

	func interact(cell: Vector2i, _facing: int) -> bool:
		if cell != actor_cell or waiting_tag != &"":
			return cell == actor_cell
		talking = true
		received = state.flag(&"squirtle_received")

		if received:
			_queue_text(TEXT_POST, "How is SQUIRTLE doing?")
			return true

		if not _thunder_badge():
			_queue_text(TEXT_BEFORE, [
				"Around three years ago, my sister caught a SQUIRTLE that was always getting into mischief.",
				"Not long after, I found an EGG.",
				"When it hatched, I couldn't believe it...",
				"It was another SQUIRTLE!",
				"And this one seems to be just as mischievous.",
				"I think it needs a good TRAINER to get it straight."
			])
			return true

		_queue_text(TEXT_OFFER, [
			"You have the THUNDER BADGE!?",
			"You must be a good TRAINER!",
			"This SQUIRTLE is always getting into mischief, just like the one my sister caught three years ago."
		])
		return true

	func take_requests() -> Array:
		var result := outbox.duplicate()
		outbox.clear()
		return result

	func request_completed(result: Dictionary) -> void:
		var tag: StringName = result.get("tag", &"")
		if tag == &"":
			return

		if tag == TEXT_BEFORE or tag == TEXT_POST or tag == TEXT_NO:
			waiting_tag = &""
			talking = false
			return

		if tag == TEXT_OFFER:
			waiting_tag = YES_NO
			outbox.append({"kind": &"yes_no", "text": "Would you take good care of it?", "tag": YES_NO})
			return

		if tag == YES_NO:
			if not bool(result.get("accepted", false)):
				_queue_text(TEXT_NO, ["Oh...", "What am I to do now?"])
				return
			waiting_tag = GIFT
			outbox.append({"kind": &"pokemon_gift", "species": SQUIRTLE, "level": 10, "tag": GIFT})
			return

		if tag == GIFT:
			waiting_tag = &""
			if bool(result.get("ok", result.get("success", false))):
				received = true
				state.set_flag(&"squirtle_received")
				var lines: Array = ["OK!", "Please treat SQUIRTLE right!"]
				if bool(result.get("newly_caught", false)):
					lines.append("SQUIRTLE's data was added to the POKéDEX!")
				if result.get("destination", &"") == &"box":
					lines.append("Your party is full.\nSQUIRTLE was sent to your BOX.")
				else:
					lines.append("SQUIRTLE was added to your party!")
				_queue_text(TEXT_YES, lines)
				return
			talking = false
			return

		if tag == TEXT_YES:
			waiting_tag = &""
			talking = false
			return

		waiting_tag = &""
		talking = false

class CeruleanRoamingTestActor extends RefCounted:
	var state: StarterPackState
	var host: Gen2ModHost
	var world: Gen2WorldAPI = null
	var actor_cell := Vector2i(-1, -1)
	var home_cell := Vector2i(-1, -1)
	var facing := Gen2WorldSprite.FACING_DOWN
	var frame_counter := 0
	var step_pending := false
	var talking := false
	var waiting_tag: StringName = &""
	var outbox: Array = []
	var rng := RandomNumberGenerator.new()

	const ACTOR_ID := &"cerulean_npc"
	const STEP_TAG := &"cerulean_walk"
	const TEST_SPRITE := 0x28
	const STEP_EVERY_FRAMES := 180
	const ROAM_X := 4
	const ROAM_Y := 3
	const DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	const BULBASAUR := 1
	const GIFT := &"bulbasaur_gift"
	const YES_NO := &"bulbasaur_yes_no"
	const TEXT_LOW_FIRST := &"bulbasaur_low_first"
	const TEXT_LOW_REPEAT := &"bulbasaur_low_repeat"
	const TEXT_READY_FIRST := &"bulbasaur_ready_first"
	const TEXT_READY_REPEAT := &"bulbasaur_ready_repeat"
	const TEXT_NO := &"bulbasaur_no"
	const TEXT_GIFT := &"bulbasaur_gift_text"
	const TEXT_POST := &"bulbasaur_post"

	func _init(p_host: Gen2ModHost, p_state: StarterPackState) -> void:
		host = p_host
		state = p_state
		rng.randomize()

	func set_world(next_world: Gen2WorldAPI) -> void:
		world = next_world
		actor_cell = Vector2i(-1, -1)
		home_cell = Vector2i(-1, -1)
		frame_counter = 0
		step_pending = false
		talking = false
		waiting_tag = &""
		outbox.clear()
		if world == null or world.current_map == null:
			return
		if int(world.current_map.group) != 7 or int(world.current_map.number) != 17:
			return
		home_cell = world.player_cell + Vector2i(-11, 0)
		actor_cell = home_cell

	func advance_frame() -> void:
		if world == null or actor_cell.x < 0 or step_pending or talking or waiting_tag != &"":
			return
		frame_counter += 1
		if frame_counter < STEP_EVERY_FRAMES:
			return
		frame_counter = 0
		if rng.randi_range(0, 2) == 0:
			return
		var direction: Vector2i = DIRECTIONS[rng.randi_range(0, DIRECTIONS.size() - 1)]
		var candidate := actor_cell + direction
		if abs(candidate.x - home_cell.x) > ROAM_X or abs(candidate.y - home_cell.y) > ROAM_Y:
			return
		outbox.append({"kind": &"step", "id": ACTOR_ID, "direction": direction, "tag": STEP_TAG})
		step_pending = true

	func _talk_facing() -> int:
		if not talking or world == null:
			return facing
		var delta := world.player_cell - actor_cell
		if abs(delta.x) > abs(delta.y):
			return Gen2WorldSprite.FACING_RIGHT if delta.x > 0 else Gen2WorldSprite.FACING_LEFT
		return Gen2WorldSprite.FACING_DOWN if delta.y > 0 else Gen2WorldSprite.FACING_UP

	func sprites() -> Array:
		if world == null or actor_cell.x < 0:
			return []
		return [{"id": ACTOR_ID, "sprite": TEST_SPRITE, "facing": _talk_facing(), "position_cells": Vector2(actor_cell), "solid": true}]

	func _queue_text(tag: StringName, text) -> void:
		waiting_tag = tag
		outbox.append({"kind": &"text", "text": text, "tag": tag})

	func _happiness_ready() -> bool:
		# API 59: judge the whole active, non-egg party.  Requirement is 90%
		# of the theoretical maximum: ceil(255 * active_count * 0.90).
		var party: Array = host.party()
		var active_count := 0
		var total_happiness := 0
		for pokemon in party:
			if not (pokemon is Dictionary):
				continue
			if bool(pokemon.get(&"is_egg", false)):
				continue
			if not pokemon.has(&"happiness"):
				continue
			active_count += 1
			total_happiness += int(pokemon.get(&"happiness", 0))
		if active_count == 0:
			return false
		var required := ceili(float(255 * active_count) * 0.90)
		return total_happiness >= required

	func interact(cell: Vector2i, _facing: int) -> bool:
		if cell != actor_cell or waiting_tag != &"" or step_pending:
			return cell == actor_cell
		talking = true
		if state.flag(&"bulbasaur_received"):
			_queue_text(TEXT_POST, "Is BULBASAUR doing well?")
			return true

		var met := state.flag(&"bulbasaur_met")
		var ready := _happiness_ready()
		if not met:
			state.set_flag(&"bulbasaur_met")
			if ready:
				_queue_text(TEXT_READY_FIRST, [
					"I used to take care of injured POKéMON.",
					"But around three years ago, TEAM ROCKET vandalized a house here in CERULEAN CITY.",
					"It frightened me, so I decided to move far away.",
					"Sometimes I still come back here to relive some of those good old memories.",
					"Back then, I nursed a BULBASAUR back to health.",
					"I never forgot that little POKéMON...",
					"Secretly, I always hoped I'd get the chance to care for another BULBASAUR someday.",
					"And then I found this little one.",
					"I nursed it back to health, just like the one all those years ago.",
					"Your POKéMON look very happy with you.",
					"I know! Would you take care of this BULBASAUR?"
				])
			else:
				_queue_text(TEXT_LOW_FIRST, [
					"I used to take care of injured POKéMON.",
					"But around three years ago, TEAM ROCKET vandalized a house here in CERULEAN CITY.",
					"It frightened me, so I decided to move far away.",
					"Sometimes I still come back here to relive some of those good old memories.",
					"Back then, I nursed a BULBASAUR back to health.",
					"I never forgot that little POKéMON...",
					"Secretly, I always hoped I'd get the chance to care for another BULBASAUR someday.",
					"And then I found this little one.",
					"I nursed it back to health, just like the one all those years ago.",
					"It needs a good TRAINER to take care of it now."
				])
			return true

		if ready:
			_queue_text(TEXT_READY_REPEAT, [
				"Your POKéMON look very happy with you.",
				"I know! Would you take care of this BULBASAUR?"
			])
		else:
			_queue_text(TEXT_LOW_REPEAT, [
				"This BULBASAUR needs a good TRAINER to take care of it.",
				"I want to be sure it goes to someone who really cares for their POKéMON."
			])
		return true

	func take_requests() -> Array:
		var result := outbox.duplicate()
		outbox.clear()
		return result

	func request_completed(result: Dictionary) -> void:
		var tag: StringName = result.get("tag", &"")
		if tag == &"":
			return
		if tag == STEP_TAG:
			step_pending = false
			if result.has("cell"):
				var c = result["cell"]
				actor_cell = Vector2i(int(c.x), int(c.y))
			if result.has("facing"):
				facing = int(result["facing"])
			return

		if tag == TEXT_READY_FIRST or tag == TEXT_READY_REPEAT:
			waiting_tag = YES_NO
			outbox.append({"kind": &"yes_no", "text": "Will you take good care of BULBASAUR?", "tag": YES_NO})
			return

		if tag == YES_NO:
			if not bool(result.get("accepted", false)):
				_queue_text(TEXT_NO, "Oh... That's too bad...")
				return
			waiting_tag = GIFT
			outbox.append({"kind": &"pokemon_gift", "species": BULBASAUR, "level": 10, "tag": GIFT})
			return

		if tag == GIFT:
			waiting_tag = &""
			if bool(result.get("ok", result.get("success", false))):
				state.set_flag(&"bulbasaur_received")
				var lines: Array = ["Please take care of BULBASAUR!"]
				if bool(result.get("newly_caught", false)):
					lines.append("BULBASAUR's data was added to the POKéDEX!")
				if result.get("destination", &"") == &"box":
					lines.append("Your party is full.\nBULBASAUR was sent to your BOX.")
				else:
					lines.append("BULBASAUR was added to your party!")
				_queue_text(TEXT_GIFT, lines)
				return
			talking = false
			return

		waiting_tag = &""
		talking = false


class Route25TestActor extends RefCounted:
	var state: StarterPackState
	var host: Gen2ModHost
	var world: Gen2WorldAPI = null
	var actor_cell := Vector2i(-1, -1)
	var talking := false
	var spoken_before_blue := false
	var received := false
	var waiting_tag: StringName = &""
	var outbox: Array = []

	const TEST_SPRITE := 0x23
	const CHARMANDER := 4
	const TEXT_FIRST := &"charmander_first"
	const TEXT_REPEAT := &"charmander_repeat"
	const TEXT_BLUE := &"charmander_blue"
	const TEXT_BLUE_FIRST := &"charmander_blue_first"
	const TEXT_GIFT := &"charmander_gift_text"
	const TEXT_POST := &"charmander_post"
	const GIFT := &"charmander_gift"
	const YES_NO := &"charmander_yes_no"
	const TEXT_NO := &"charmander_no"

	func _init(next_host: Gen2ModHost, p_state: StarterPackState) -> void:
		host = next_host
		state = p_state

	func set_world(next_world: Gen2WorldAPI) -> void:
		world = next_world
		actor_cell = Vector2i(-1, -1)
		talking = false
		waiting_tag = &""
		outbox.clear()
		if world == null or world.current_map == null:
			return
		if int(world.current_map.group) != 7 or int(world.current_map.number) != 16:
			return
		# Keep the confirmed Route 25 placement unchanged.
		actor_cell = world.player_cell + Vector2i(-2, -12)

	func advance_frame() -> void:
		pass

	func _blue_defeated() -> bool:
		var progress: Dictionary = host.progress()
		var badges: int = int(progress.get(&"badges", 0))
		# Earth Badge = eighth Kanto badge; Kanto badges follow the eight Johto bits.
		return (badges & (1 << 15)) != 0

	func _talk_facing() -> int:
		if not talking or world == null:
			return Gen2WorldSprite.FACING_DOWN
		var delta := world.player_cell - actor_cell
		if abs(delta.x) > abs(delta.y):
			return Gen2WorldSprite.FACING_RIGHT if delta.x > 0 else Gen2WorldSprite.FACING_LEFT
		return Gen2WorldSprite.FACING_DOWN if delta.y > 0 else Gen2WorldSprite.FACING_UP

	func sprites() -> Array:
		if world == null or actor_cell.x < 0:
			return []
		return [{"sprite": TEST_SPRITE, "facing": _talk_facing(),
			"position_cells": Vector2(actor_cell), "solid": true}]

	func _queue_text(tag: StringName, text) -> void:
		waiting_tag = tag
		outbox.append({"kind": &"text", "text": text, "tag": tag})

	func interact(cell: Vector2i, _facing: int) -> bool:
		if cell != actor_cell or waiting_tag != &"":
			return cell == actor_cell
		talking = true
		spoken_before_blue = state.flag(&"charmander_spoken_before_blue")
		received = state.flag(&"charmander_received")

		if received:
			_queue_text(TEXT_POST, "How's CHARMANDER doing?")
			return true

		if _blue_defeated():
			if spoken_before_blue:
				_queue_text(TEXT_BLUE, [
					"I heard you're the TRAINER who defeated GYM LEADER BLUE?",
					"I can tell you've raised your POKéMON well.",
					"Maybe this CHARMANDER has finally found the TRAINER it needs."
				])
			else:
				_queue_text(TEXT_BLUE_FIRST, [
					"Did you know that news travels fast around these parts?",
					"I heard you defeated VIRIDIAN CITY GYM LEADER BLUE...",
					"I was training to be the first to beat him.",
					"But I think you're a better TRAINER than I am.",
					"I can't help but ask...",
					"Around three years ago, I gave a CHARMANDER to a TRAINER.",
					"Back then, I wasn't very good at raising POKéMON.",
					"That TRAINER promised to take good care of it.",
					"I've learned a lot since then..."
				])
			return true

		if not spoken_before_blue:
			spoken_before_blue = true
			state.set_flag(&"charmander_spoken_before_blue")
			_queue_text(TEXT_FIRST, [
				"Around three years ago, I gave a CHARMANDER to a TRAINER.",
				"Back then, I wasn't very good at raising POKéMON.",
				"That TRAINER promised to take good care of it.",
				"I've learned a lot since then...",
				"Recently, I started looking after another CHARMANDER.",
				"It's strong-willed, and I think it needs a TRAINER who can bring out its potential."
			])
			return true

		_queue_text(TEXT_REPEAT, [
			"I'm training for my upcoming battle at the VIRIDIAN CITY GYM.",
			"I hear the GYM LEADER there is incredibly strong."
		])
		return true

	func take_requests() -> Array:
		var result := outbox.duplicate()
		outbox.clear()
		return result

	func request_completed(result: Dictionary) -> void:
		var tag: StringName = result.get("tag", &"")
		if tag == &"":
			return

		if tag == TEXT_BLUE or tag == TEXT_BLUE_FIRST:
			waiting_tag = YES_NO
			var question := "Will you take good care of it?" if tag == TEXT_BLUE else "Would you be willing to take care of my CHARMANDER?"
			outbox.append({"kind": &"yes_no", "text": question, "tag": YES_NO})
			return

		if tag == YES_NO:
			if not bool(result.get("accepted", false)):
				_queue_text(TEXT_NO, ["Oh...", "I'd better keep looking for the right TRAINER then."])
				return
			waiting_tag = GIFT
			outbox.append({"kind": &"pokemon_gift", "species": CHARMANDER, "level": 10, "tag": GIFT})
			return

		if tag == GIFT:
			waiting_tag = &""
			if bool(result.get("ok", result.get("success", false))):
				received = true
				state.set_flag(&"charmander_received")
				var lines: Array = ["Take good care of my CHARMANDER!"]
				if bool(result.get("newly_caught", false)):
					lines.append("CHARMANDER's data was added to the POKéDEX!")
				if result.get("destination", &"") == &"box":
					lines.append("Your party is full.\nCHARMANDER was sent to your BOX.")
				else:
					lines.append("CHARMANDER was added to your party!")
				_queue_text(TEXT_GIFT, lines)
				return
			talking = false
			return

		waiting_tag = &""
		talking = false

class StarterPackActors extends RefCounted:
	var chikorita_actor
	var cyndaquil_actor
	var totodile_actor
	var vermilion_actor
	var cerulean_actor
	var route25_actor

	func _init(p_chikorita_actor, p_cyndaquil_actor, p_totodile_actor, p_vermilion_actor, p_cerulean_actor, p_route25_actor) -> void:
		chikorita_actor = p_chikorita_actor
		cyndaquil_actor = p_cyndaquil_actor
		totodile_actor = p_totodile_actor
		vermilion_actor = p_vermilion_actor
		cerulean_actor = p_cerulean_actor
		route25_actor = p_route25_actor

	func set_world(next_world: Gen2WorldAPI) -> void:
		chikorita_actor.set_world(next_world)
		cyndaquil_actor.set_world(next_world)
		totodile_actor.set_world(next_world)
		vermilion_actor.set_world(next_world)
		cerulean_actor.set_world(next_world)
		route25_actor.set_world(next_world)

	func advance_frame() -> void:
		chikorita_actor.advance_frame()
		cyndaquil_actor.advance_frame()
		totodile_actor.advance_frame()
		vermilion_actor.advance_frame()
		cerulean_actor.advance_frame()
		route25_actor.advance_frame()

	func sprites() -> Array:
		var result: Array = []
		result.append_array(chikorita_actor.sprites())
		result.append_array(cyndaquil_actor.sprites())
		result.append_array(totodile_actor.sprites())
		result.append_array(vermilion_actor.sprites())
		result.append_array(cerulean_actor.sprites())
		result.append_array(route25_actor.sprites())
		return result

	func interact(cell: Vector2i, facing: int) -> bool:
		if chikorita_actor.interact(cell, facing):
			return true
		if cyndaquil_actor.interact(cell, facing):
			return true
		if totodile_actor.interact(cell, facing):
			return true
		if vermilion_actor.interact(cell, facing):
			return true
		if cerulean_actor.interact(cell, facing):
			return true
		return route25_actor.interact(cell, facing)

	func take_requests() -> Array:
		var result: Array = []
		result.append_array(chikorita_actor.take_requests())
		result.append_array(cyndaquil_actor.take_requests())
		result.append_array(totodile_actor.take_requests())
		result.append_array(vermilion_actor.take_requests())
		result.append_array(cerulean_actor.take_requests())
		result.append_array(route25_actor.take_requests())
		return result

	func request_completed(result: Dictionary) -> void:
		for actor in [chikorita_actor, cyndaquil_actor, totodile_actor, vermilion_actor, cerulean_actor, route25_actor]:
			if actor.has_method("request_completed"):
				actor.request_completed(result)

func register(host: Gen2ModHost, manifest: PokeModManifest) -> void:
	if host.target_game() != &"crystal":
		return
	var data: GameData = GameData.open(host.target_game())
	if data == null:
		return
	var state := StarterPackState.new(host, manifest)
	host.register_save_lifecycle(manifest, state)
	var chikorita_actor := ChikoritaActor.new(host, state)
	var cyndaquil_actor := CyndaquilNpcActor.new(host, state)
	var totodile_actor := TotodileNpcActor.new(host, state)
	var vermilion_actor := VermilionTestActor.new(host, state)
	var cerulean_actor := CeruleanRoamingTestActor.new(host, state)
	var route25_actor := Route25TestActor.new(host, state)
	host.register_world_actor(manifest.id, StarterPackActors.new(
		chikorita_actor, cyndaquil_actor, totodile_actor,
		vermilion_actor, cerulean_actor, route25_actor
	))
