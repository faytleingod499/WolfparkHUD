extends Node

# Wolfpark HUD
# A small panel with your coin balance, a Feed Wolves button, a Buy menu and a gamble box.
# It only appears on servers that announce it (the server's "Feed" plugin does this through the
# lobby data), on every other server this mod does nothing at all.
# On such a server, anything you type that starts with ! goes only to the server and is not shown in chat.

const CONFIG_PATH = "user://wolfparkhud.json"
# the titles this mod adds: file name (also the id part), text shown under the name
const TITLES = [["lonely", "Lonely"], ["battery_charger", "Battery Charger"]]
const DEFAULT_POS = Vector2(16, 52)
const FEED_DEBOUNCE_MS = 1500
const BUY_DEBOUNCE_MS = 1500
const GAMBLE_DEBOUNCE_MS = 1500
const POPUP_ID = "WOLFPARK"
const CHALK_CANVASES = 4
const CHALK_NAME_MAX = 32
const CHALK_DEBOUNCE_MS = 1500
const ARM_MS = 3000

var steam = null
var layer
var panel
var grip
var coin_label
var feeds_label
var feed_button
var feed_bar
var buy_button
var board_button
var board_ready_at = 0
var title_label
var bet_field
var gamble_button
var shop_panel
var shop_box

var active = false
var coins = 0
var feeds = 0
var shop_items = []
var shop_signature = ""
var gamble_min = 0
var gamble_max = 0
var feed_ready_at = 0
var feed_cooldown_ms = 0
var feed_bar_start = 0
var feed_bar_end = 0
var last_feeds = -1
var feed_pressed_at = -100000
var buy_ready_at = 0
var gamble_ready_at = 0
var title_text = ""
var title_color = Color(0.0, 1.0, 1.0)
var chat_color = ""
var chat_expanded_for = 0
var title_ids = {} # file name -> the id the game knows it by
var lure_tries = 0
var prev_title = ""
var chat_connected = false

# the admin panel: only for admins of this server (the Feed plugin lists them in "wp_admins")
var is_admin = false
var admin_open = false
var admin_button
var admin_box
var admin_signature = ""
var ban_armed = {} # steam id -> until when its Ban button is waiting for the second click

# the Chalk menu: your chalk saves, from the server's "Chalk Saves" plugin (it lists them in "wp_cs<SteamID>")
var chalk_on = false
var chalk_open = false
var chalk_save_all = true
var chalk_load_all = true
var chalk_max = 20
var chalk_cooldown = 30
var chalk_names = []
var chalk_offer = "" # "from~name" while somebody is sharing a save with you
var chalk_offer_answered = ""
var chalk_signature = ""
var chalk_canvas = -1
var chalk_nearest = -1
var chalk_picked = false # a canvas was clicked, so stop following the nearest one
var chalk_share_for = "" # the save whose player list is open
var chalk_armed = {} # "load:name", "delete:name" or "save" -> until when it waits for the second click
var chalk_load_ready_at = 0
var chalk_ready_at = 0
var canvas_nodes = []
var chalk_button
var chalk_box
var chalk_canvas_buttons = []
var chalk_near_label
var chalk_name_field
var chalk_save_button
var chalk_save_row
var chalk_offer_row
var chalk_offer_label
var chalk_count_label
var chalk_list
# admins: every player's saves ("wp_ca<SteamID>"), one player opened at a time ("wp_cb<SteamID>")
var chalk_all_open = false
var chalk_owners = [] # [steam id, name, count]
var chalk_browse_id = ""
var chalk_browse_names = []
var chalk_all_signature = ""
var chalk_all_opened_at = 0
var chalk_all_button
var chalk_all_list


var poll_timer = 0.0
var dragging = false
var drag_offset = Vector2()
var theme_applied = false
var locked_hud = null
var pending_unlock = false


func _ready():
	if Engine.has_singleton("Steam"):
		steam = Engine.get_singleton("Steam")
	_build_ui()
	_load_config()
	_connect_chat()
	_register_title()
	_revoke_title() # in case the game was closed while the title was still handed out


func _exit_tree():
	_unlock_hud()
	_revoke_title()


func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		_revoke_title()


func _build_ui():
	layer = CanvasLayer.new()
	layer.layer = 3
	add_child(layer)

	panel = PanelContainer.new()
	panel.visible = false
	panel.rect_position = DEFAULT_POS
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_stylebox_override("panel", _glass(Color(0.06, 0.12, 0.18, 0.55), Color(0.55, 1.0, 1.0, 0.45), 10, 6))
	layer.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_constant_override("margin_left", 10)
	margin.add_constant_override("margin_right", 10)
	margin.add_constant_override("margin_top", 6)
	margin.add_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var column = VBoxContainer.new()
	column.add_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	# top: the drag grip, the title on the left, the coins and the times fed on the right
	var row = HBoxContainer.new()
	row.add_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)

	grip = Label.new()
	grip.text = "::"
	grip.mouse_filter = Control.MOUSE_FILTER_STOP
	grip.mouse_default_cursor_shape = Control.CURSOR_MOVE
	grip.connect("gui_input", self, "_on_grip_input")
	row.add_child(grip)
	_add_tooltip(grip, "Move", "Drag to move this window")

	# the title, coins and fed count sit centred in the rest of the row
	var info = HBoxContainer.new()
	info.alignment = BoxContainer.ALIGN_CENTER
	info.add_constant_override("separation", 10)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	# admins get a button left of the title that opens the player list under the panel
	admin_button = Button.new()
	admin_button.visible = false
	admin_button.focus_mode = Control.FOCUS_NONE
	admin_button.rect_min_size = Vector2(24, 20)
	admin_button.connect("pressed", self, "_on_admin_toggle")
	admin_button.connect("draw", self, "_draw_admin_icon")
	_glass_button(admin_button)
	info.add_child(admin_button)
	_add_tooltip(admin_button, "Admin", "Players on the server, with kick and ban")

	title_label = Label.new()
	title_label.visible = false
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(title_label)

	coin_label = Label.new()
	coin_label.text = "Coins: 0"
	coin_label.add_color_override("font_color", Color(1.0, 0.85, 0.4))
	coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(coin_label)

	feeds_label = Label.new()
	feeds_label.text = "Fed: 0"
	feeds_label.add_color_override("font_color", Color(0.75, 0.95, 1.0))
	feeds_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(feeds_label)

	# middle: leaderboard, feed and buy
	var button_row = HBoxContainer.new()
	button_row.add_constant_override("separation", 8)
	button_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(button_row)

	# the leaderboard icon: a little clipboard that runs !wolves
	board_button = Button.new()
	board_button.focus_mode = Control.FOCUS_NONE
	board_button.rect_min_size = Vector2(26, 22)
	board_button.connect("pressed", self, "_on_board")
	board_button.connect("draw", self, "_draw_clipboard")
	_glass_button(board_button)
	button_row.add_child(board_button)
	_add_tooltip(board_button, "Leaderboard", "Who has fed the wolves the most")


	feed_button = Button.new()
	feed_button.text = "Feed Wolves"
	feed_button.focus_mode = Control.FOCUS_NONE
	feed_button.connect("pressed", self, "_on_feed")
	_glass_button(feed_button)
	# while the wolves are full the button is clearly grey, the colour then comes back from left to right
	feed_button.add_stylebox_override("disabled", _glass(Color(0.45, 0.45, 0.45, 0.30), Color(0.7, 0.7, 0.7, 0.3), 8, 0))
	button_row.add_child(feed_button)

	# the cooldown bar: the button's colour, sliding back in behind the text as the cooldown runs down
	feed_bar = ColorRect.new()
	feed_bar.color = Color(0.3, 1.0, 1.0, 0.38)
	feed_bar.show_behind_parent = true
	feed_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed_bar.visible = false
	feed_button.add_child(feed_bar)

	buy_button = Button.new()
	buy_button.text = "Buy"
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.connect("pressed", self, "_on_buy_toggle")
	_glass_button(buy_button)
	button_row.add_child(buy_button)

	chalk_button = Button.new()
	chalk_button.text = "Chalk"
	chalk_button.visible = false
	chalk_button.focus_mode = Control.FOCUS_NONE
	chalk_button.connect("pressed", self, "_on_chalk_toggle")
	_glass_button(chalk_button)
	button_row.add_child(chalk_button)
	_add_tooltip(chalk_button, "Chalk saves", "Save the chalk canvases and put them back later")

	bet_field = LineEdit.new()
	bet_field.placeholder_text = "coins"
	bet_field.max_length = 6
	bet_field.rect_min_size = Vector2(70, 0)
	bet_field.caret_blink = true
	bet_field.add_stylebox_override("normal", _glass(Color(0, 0, 0, 0.30), Color(0.55, 1.0, 1.0, 0.35), 8, 0))
	bet_field.add_stylebox_override("focus", _glass(Color(0, 0, 0, 0.40), Color(0.8, 1.0, 1.0, 0.9), 8, 0))
	bet_field.add_color_override("font_color", Color(1, 1, 1))
	bet_field.connect("text_changed", self, "_on_bet_changed")
	bet_field.connect("focus_entered", self, "_on_bet_focus")
	bet_field.connect("focus_exited", self, "_on_bet_unfocus")
	bet_field.connect("text_entered", self, "_on_bet_entered")
	gamble_button = Button.new()
	gamble_button.text = "Gamble"
	gamble_button.focus_mode = Control.FOCUS_NONE
	gamble_button.connect("pressed", self, "_on_gamble")
	_glass_button(gamble_button)
	button_row.add_child(gamble_button)
	button_row.add_child(bet_field)

	# the admin player list, opening the panel downwards
	admin_box = VBoxContainer.new()
	admin_box.visible = false
	admin_box.add_constant_override("separation", 3)
	admin_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(admin_box)

	_build_chalk(column)

	# the list that opens under the panel with the Buy button
	shop_panel = PanelContainer.new()
	shop_panel.visible = false
	shop_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_panel.add_stylebox_override("panel", _glass(Color(0.06, 0.12, 0.18, 0.7), Color(0.55, 1.0, 1.0, 0.45), 10, 6))
	layer.add_child(shop_panel)

	var shop_margin = MarginContainer.new()
	shop_margin.add_constant_override("margin_left", 8)
	shop_margin.add_constant_override("margin_right", 8)
	shop_margin.add_constant_override("margin_top", 6)
	shop_margin.add_constant_override("margin_bottom", 6)
	shop_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_panel.add_child(shop_margin)

	shop_box = VBoxContainer.new()
	shop_box.add_constant_override("separation", 4)
	shop_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_margin.add_child(shop_box)


# a see-through, softly outlined box
func _glass(fill, edge, radius, shadow):
	var box = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0, 0, 0, 0.3)
	box.shadow_size = shadow
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


func _glass_button(button):
	var edge = Color(0.55, 1.0, 1.0, 0.5)
	button.add_stylebox_override("normal", _glass(Color(0.2, 0.9, 0.95, 0.16), edge, 8, 0))
	button.add_stylebox_override("hover", _glass(Color(0.3, 1.0, 1.0, 0.30), Color(0.8, 1.0, 1.0, 0.8), 8, 0))
	button.add_stylebox_override("pressed", _glass(Color(0.3, 1.0, 1.0, 0.45), Color(0.8, 1.0, 1.0, 0.9), 8, 0))
	button.add_stylebox_override("disabled", _glass(Color(0.5, 0.5, 0.5, 0.12), Color(0.7, 0.7, 0.7, 0.25), 8, 0))
	button.add_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_color_override("font_color", Color(1, 1, 1))
	button.add_color_override("font_color_hover", Color(1, 1, 1))
	button.add_color_override("font_color_pressed", Color(1, 1, 1))
	button.add_color_override("font_color_disabled", Color(1, 1, 1, 0.4))


func _process(delta):
	poll_timer += delta
	if poll_timer >= 0.5:
		poll_timer = 0.0
		_poll()
		_sync_title()
		if active:
			_expand_chat()
	_refresh()
	# the game reads its keys before this node runs, so let go of its controls only after that
	if pending_unlock:
		pending_unlock = false
		if _typing_field() == null:
			_unlock_hud()


# --- reading what the server tells us ---

func _poll():
	var was_active = active
	active = false
	if steam == null:
		return
	var net = get_node_or_null("/root/Network")
	if net == null:
		return
	if net.PLAYING_OFFLINE or net.STEAM_LOBBY_ID <= 0:
		return

	var lobby = net.STEAM_LOBBY_ID
	if str(steam.getLobbyData(lobby, "wp_hud")) != "1":
		return
	active = true
	if not was_active:
		# just arrived on the server (or came back to it): forget the old feed count and cooldown
		last_feeds = -1
		feed_bar_end = 0
		feed_bar_start = 0
		feed_ready_at = 0

	title_text = str(steam.getLobbyData(lobby, "wp_title"))
	var color_text = str(steam.getLobbyData(lobby, "wp_title_color")).replace("#", "")
	title_color = Color(color_text) if color_text.length() == 6 else Color(0.0, 1.0, 1.0)

	chat_color = str(steam.getLobbyData(lobby, "wp_chat_color")).replace("#", "")
	if chat_color.length() != 6:
		chat_color = ""

	# what the Buy button lists, "id~Label~price;id~Label~price"
	var shop_text = str(steam.getLobbyData(lobby, "wp_shop"))
	if shop_text != shop_signature:
		shop_signature = shop_text
		shop_items = []
		for entry in shop_text.split(";", false):
			var bits = entry.split("~")
			if bits.size() >= 3:
				shop_items.append({"id": bits[0], "label": bits[1], "price": int(bits[2])})
		_rebuild_shop()

	feed_cooldown_ms = int(str(steam.getLobbyData(lobby, "wp_feed_cd"))) * 1000

	is_admin = str(steam.getLobbyData(lobby, "wp_admins")).split(",", false).has(str(net.STEAM_ID))
	if not is_admin:
		admin_open = false
	if admin_open:
		_rebuild_admin(net, lobby)

	_poll_chalk(net, lobby)

	# the bet limits "min,max", empty when the server has no gambling
	var gamble_text = str(steam.getLobbyData(lobby, "wp_gamble")).split(",")
	if gamble_text.size() >= 2:
		gamble_min = int(gamble_text[0])
		gamble_max = int(gamble_text[1])
	else:
		gamble_min = 0
		gamble_max = 0

	# mine: "coins,feeds" (the server may add more after that, the mod ignores it)
	var mine = str(steam.getLobbyData(lobby, "wp_p" + str(net.STEAM_ID)))
	var parts = mine.split(",")
	if parts.size() >= 2:
		coins = int(parts[0])
		feeds = int(parts[1])
	else:
		coins = 0
		feeds = 0
	# a feed just counted (from the button or typed), so the wolves are full for the cooldown.
	# The first number we see for this player is only where they stood when they joined, never a feed,
	# except when this player pressed feed a moment ago (a brand new player's very first feed).
	var now = OS.get_ticks_msec()
	if parts.size() < 2:
		pass
	elif last_feeds == -1:
		last_feeds = feeds
		if feeds > 0 and now - feed_pressed_at < 6000:
			_start_feed_bar(now)
	elif feeds > last_feeds:
		last_feeds = feeds
		_start_feed_bar(now)
	elif feeds < last_feeds:
		last_feeds = feeds


func _start_feed_bar(now):
	if feed_cooldown_ms > 0:
		feed_bar_start = now
		feed_bar_end = now + feed_cooldown_ms


func _rebuild_shop():
	for child in shop_box.get_children():
		shop_box.remove_child(child)
		child.queue_free()
	for item in shop_items:
		var button = Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.align = Button.ALIGN_LEFT
		button.connect("pressed", self, "_on_buy_item", [item["id"]])
		_glass_button(button)
		button.set_meta("price", item["price"])
		button.set_meta("label", item["label"])
		shop_box.add_child(button)
	shop_panel.rect_size = Vector2(0, 0)


# --- the Lonely title ---
# A real title in the game's own list (Cosmetics > Misc). It is registered all the time, so the game can
# show it on other players, but only handed out to the player while they are on the server.
# Someone wearing it looks like a default character to players without this mod, so it is taken off
# again when they leave the server or close the game.

func _lure_id(key):
	return "WolfparkHUD." + key


func _plain_id(key):
	return "title_" + key


func _all_ids():
	var ids = []
	for entry in TITLES:
		ids.append(_lure_id(entry[0]))
		ids.append(_plain_id(entry[0]))
	return ids


func _register_title():
	var globals = get_node_or_null("/root/Globals")
	if globals == null:
		return
	# With Lure (LureRefreshed) installed the titles go through Lure: it changes how name tags are drawn and
	# swaps out any title it did not register itself for a blank one, which is what an unregistered title got.
	var lure = get_node_or_null("/root/SulayreLure")
	var use_lure = lure != null and lure.has_method("add_content")
	for entry in TITLES:
		var key = entry[0]
		if use_lure:
			if not globals.cosmetic_data.has(_lure_id(key)) and lure_tries < 5:
				lure.add_content("WolfparkHUD", key, "mod://titles/" + key + ".tres")
			if globals.cosmetic_data.has(_lure_id(key)):
				title_ids[key] = _lure_id(key)
				continue
			if lure_tries < 5:
				continue # try again at the next poll, Lure may not be ready yet
		_register_plain_title(globals, key, entry[1])
	if use_lure and not (title_ids.size() == TITLES.size()):
		lure_tries += 1


func _register_plain_title(globals, key, text):
	var id = _plain_id(key)
	title_ids[key] = id
	if globals.cosmetic_data.has(id):
		return
	# copy a title the game already has, so every field is exactly what the game (and other mods) expect
	var res = null
	for base in ["title_cozy", "title_rank_1"]:
		if globals.cosmetic_data.has(base):
			res = globals.cosmetic_data[base]["file"].duplicate()
			break
	if res == null:
		var script = load("res://Resources/Scripts/cosmetic_resource.gd")
		if script == null:
			return
		res = script.new()
	res.name = text
	res.desc = "Only for Wolf Park."
	res.title = text
	res.category = "title"
	res.cos_internal_id = 0
	res.in_rotation = false
	res.chest_reward = false
	print("[WolfparkHUD] title registered: ", id, " text='", res.title, "'")
	globals.cosmetic_data[id] = {"file": res}


func _sync_title():
	if active:
		_grant_title()
	else:
		_revoke_title()


func _grant_title():
	var data = get_node_or_null("/root/PlayerData")
	if data == null:
		return
	_register_title()
	var globals = get_node_or_null("/root/Globals")
	if globals != null:
		for key in title_ids.keys():
			var id = title_ids[key]
			if globals.cosmetic_data.has(id) and not data.cosmetics_unlocked.has(id):
				data.cosmetics_unlocked.append(id)
	var worn = data.cosmetics_equipped.get("title", "")
	if not _all_ids().has(worn) and worn != prev_title:
		prev_title = worn
		_save_config()


func _revoke_title():
	var data = get_node_or_null("/root/PlayerData")
	if data == null:
		return
	var ids = _all_ids()
	for id in ids:
		if data.cosmetics_unlocked.has(id):
			data.cosmetics_unlocked.erase(id)
	if ids.has(data.cosmetics_equipped.get("title", "")):
		var globals = get_node_or_null("/root/Globals")
		var back = prev_title
		if back == "" or ids.has(back) or globals == null or not globals.cosmetic_data.has(back):
			back = "title_rank_1"
		data.cosmetics_equipped["title"] = back


# --- server messages in colour ---

func _connect_chat():
	var net = get_node_or_null("/root/Network")
	if net == null or chat_connected:
		return
	if net.has_signal("_chat_update"):
		net.connect("_chat_update", self, "_on_chat_update")
		chat_connected = true


# Every chat line a player writes carries their coloured name, so a global line without any colour tag
# comes from the server (or the game itself). Those get wrapped in the server colour.
func _on_chat_update():
	if not active or chat_color == "":
		return
	var net = get_node_or_null("/root/Network")
	if net == null:
		return
	var lines = net.GAMECHAT_COLLECTIONS
	var changed = false
	for i in range(lines.size()):
		var line = str(lines[i])
		if line.find("[color=") == -1 and line.strip_edges() != "":
			var body = line.substr(1) if line.begins_with("\n") else line
			lines[i] = "\n[color=#" + chat_color + "]" + body + "[/color]"
			changed = true
	if not changed:
		return
	var all = ""
	for line in lines:
		all += str(line)
	net.GAMECHAT = all
	var hud = _get_hud()
	if hud != null and hud.has_method("_chat_update"):
		hud._chat_update()


# --- showing it ---

func _get_hud():
	var players = get_tree().get_nodes_in_group("controlled_player")
	if players.empty():
		return null
	var hud = players[0].get("hud")
	if hud == null or not is_instance_valid(hud):
		return null
	return hud


# the chat window starts big on the server: once per game session, so it can still be made small again
func _expand_chat():
	var hud = _get_hud()
	if hud == null or chat_expanded_for == hud.get_instance_id():
		return
	chat_expanded_for = hud.get_instance_id()
	if hud.get("chat_expand") == false and hud.has_method("_on_expand_pressed"):
		hud._on_expand_pressed()


func _refresh():
	if not active:
		panel.visible = false
		shop_panel.visible = false
		dragging = false
		_unlock_hud()
		return

	var hud = _get_hud()
	if hud == null:
		panel.visible = false
		shop_panel.visible = false
		return

	# only while nothing else is open, like the game's own hotbar. Our own lock on the game
	# (while typing a bet) counts as a popup, so it has to be looked past.
	var show = true
	if hud.get("menu") != 0:
		show = false
	if hud.get("hud_hidden") == true:
		show = false
	var popups = hud.get("popups")
	if typeof(popups) == TYPE_ARRAY:
		for entry in popups:
			if entry != POPUP_ID:
				show = false
	var options = get_node_or_null("/root/OptionsMenu")
	if options != null and options.get("open") == true:
		show = false
	panel.visible = show
	if not show:
		shop_panel.visible = false
		_unlock_hud()
		return

	if not theme_applied:
		theme_applied = true
		var main = hud.get_node_or_null("main")
		if main != null and main.theme != null:
			panel.theme = main.theme
			shop_panel.theme = main.theme

	var now = OS.get_ticks_msec()
	title_label.visible = title_text != ""
	title_label.text = title_text
	title_label.add_color_override("font_color", title_color)
	admin_button.visible = is_admin
	if admin_box.visible != (is_admin and admin_open):
		admin_box.visible = is_admin and admin_open
		panel.rect_size = Vector2() # shrink back to fit when it closes
	if admin_box.visible:
		for row in admin_box.get_children():
			for button in row.get_children():
				if button.has_meta("ban_id"):
					var armed = ban_armed.get(button.get_meta("ban_id"), 0) > now
					button.text = "Sure?" if armed else "Ban"
	_refresh_chalk(now)
	coin_label.text = "Coins: " + str(coins)
	feeds_label.text = "Fed: " + str(feeds)
	feed_button.disabled = now < feed_ready_at or now < feed_bar_end
	if now < feed_bar_end and feed_bar_end > feed_bar_start:
		var progress = clamp(float(now - feed_bar_start) / float(feed_bar_end - feed_bar_start), 0.0, 1.0)
		feed_bar.visible = true
		feed_button.add_color_override("font_color_disabled", Color(1, 1, 1, 0.35 + 0.65 * progress))
		feed_bar.rect_position = Vector2(1, 1)
		feed_bar.rect_size = Vector2(max(0.0, (feed_button.rect_size.x - 2) * progress), max(0.0, feed_button.rect_size.y - 2))
	else:
		feed_bar.visible = false

	# the gamble row only exists when the server has gambling
	var gamble_on = gamble_max > 0
	bet_field.visible = gamble_on
	gamble_button.visible = gamble_on
	bet_field.placeholder_text = str(gamble_min) + "-" + str(gamble_max)
	gamble_button.disabled = now < gamble_ready_at or coins < max(gamble_min, 1)

	buy_button.visible = shop_items.size() > 0
	buy_button.disabled = now < buy_ready_at
	shop_panel.visible = shop_open and shop_items.size() > 0
	if shop_panel.visible:
		shop_panel.rect_position = panel.rect_position + Vector2(0, panel.rect_size.y + 4)
		for button in shop_box.get_children():
			var price = button.get_meta("price")
			button.text = str(button.get_meta("label")) + "  -  " + str(price)
			button.disabled = coins < price or now < buy_ready_at


# --- the buttons ---

var shop_open = false


# Sends a message that only the server gets, in the same shape as a normal chat message so the server reads it
# as the command it is. Nothing is shown in your chat and nobody else receives it.
func _say(text):
	if text.strip_edges().to_lower() == "!feed":
		feed_pressed_at = OS.get_ticks_msec()
	if _send_hidden(text):
		return
	# could not do it quietly, so say it in chat like normal
	var hud = _get_hud()
	if hud != null and hud.has_method("_send_message"):
		hud._send_message(text)


func _send_hidden(text):
	if text.strip_edges().to_lower() == "!feed":
		feed_pressed_at = OS.get_ticks_msec()
	if steam == null:
		return false
	var net = get_node_or_null("/root/Network")
	var data = get_node_or_null("/root/PlayerData")
	var globals = get_node_or_null("/root/Globals")
	if net == null or data == null or globals == null:
		return false
	if net.STEAM_LOBBY_ID <= 0 or net.PLAYING_OFFLINE:
		return false

	var host = int(steam.getLobbyOwner(net.STEAM_LOBBY_ID))
	if host <= 0 or host == net.STEAM_ID:
		return false

	var color = "ffffff"
	var equipped = data.cosmetics_equipped
	if typeof(equipped) == TYPE_DICTIONARY and equipped.has("primary_color") and globals.cosmetic_data.has(equipped["primary_color"]):
		var base = globals.cosmetic_data[equipped["primary_color"]]["file"].main_color
		color = str((base * Color(0.95, 0.9, 0.9)).to_html())

	net._send_P2P_Packet({
		"type": "message",
		"message": "%u: " + text,
		"color": color,
		"local": false,
		"position": net.MESSAGE_ORIGIN,
		"zone": net.MESSAGE_ZONE,
		"zone_owner": data.player_saved_zone_owner
	}, str(host), 2, net.CHANNELS.GAME_STATE)
	return true


func _on_feed():
	feed_pressed_at = OS.get_ticks_msec()
	feed_ready_at = OS.get_ticks_msec() + FEED_DEBOUNCE_MS
	_say("!feed")


# the game's own hover box (the one the backpack uses), so it looks and behaves like the rest of the game
func _add_tooltip(control, header, body):
	var scene = load("res://Scenes/Singletons/Tooltips/tooltip_node.tscn")
	if scene == null or get_node_or_null("/root/Tooltip") == null:
		control.hint_tooltip = header # no game tooltips here, the plain one will do
		return
	var tip = scene.instance()
	tip.header = "[color=#6a4420]" + header + "[/color]"
	tip.body = body
	tip.mouse_filter = Control.MOUSE_FILTER_PASS
	control.add_child(tip)


func _on_board():
	var now = OS.get_ticks_msec()
	if now < board_ready_at:
		return
	board_ready_at = now + 1500
	_say("!wolves")


# --- the admin panel ---

func _on_admin_toggle():
	admin_open = not admin_open
	admin_signature = ""
	admin_button.update()
	if admin_open:
		var net = get_node_or_null("/root/Network")
		if net != null:
			_rebuild_admin(net, net.STEAM_LOBBY_ID)


# everyone in the lobby except the host (the server) and yourself, each with Kick and Ban
func _rebuild_admin(net, lobby):
	var host = str(steam.getLobbyOwner(lobby)) if steam != null else ""
	var people = []
	for member in net.LOBBY_MEMBERS:
		var id = str(member.get("steam_id", ""))
		if id == "" or id == host or id == str(net.STEAM_ID):
			continue
		people.append([str(member.get("steam_name", id)), id])
	people.sort_custom(self, "_by_name")
	var signature = str(people)
	if signature == admin_signature:
		return
	admin_signature = signature
	for child in admin_box.get_children():
		admin_box.remove_child(child)
		child.queue_free()
	if people.empty():
		var none = Label.new()
		none.text = "No other players"
		none.add_color_override("font_color", Color(1, 1, 1, 0.55))
		admin_box.add_child(none)
	for person in people:
		var row = HBoxContainer.new()
		row.add_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		admin_box.add_child(row)
		var name = Label.new()
		name.text = person[0]
		name.clip_text = true
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.rect_min_size = Vector2(120, 0)
		name.add_color_override("font_color", Color(1, 1, 1))
		row.add_child(name)
		var kick = Button.new()
		kick.text = "Kick"
		kick.focus_mode = Control.FOCUS_NONE
		kick.connect("pressed", self, "_on_kick", [person[1]])
		_glass_button(kick)
		row.add_child(kick)
		var ban = Button.new()
		ban.text = "Ban"
		ban.focus_mode = Control.FOCUS_NONE
		ban.rect_min_size = Vector2(52, 0)
		ban.set_meta("ban_id", person[1])
		ban.connect("pressed", self, "_on_ban", [person[1]])
		_glass_button(ban)
		ban.add_stylebox_override("normal", _glass(Color(0.45, 0.08, 0.08, 0.45), Color(1.0, 0.5, 0.5, 0.55), 8, 0))
		row.add_child(ban)
	panel.rect_size = Vector2()


func _by_name(a, b):
	return a[0].to_lower() < b[0].to_lower()


# the server's own kick and ban commands, by Steam ID so names with spaces or twins can't go wrong
func _on_kick(id):
	_say("!kick " + str(id))


# a ban needs a second click within a few seconds
func _on_ban(id):
	var now = OS.get_ticks_msec()
	if ban_armed.get(id, 0) > now:
		ban_armed.erase(id)
		_say("!ban " + str(id))
	else:
		ban_armed[id] = now + 3000


# a small shield, drawn so it does not depend on any font having an icon for it
func _draw_admin_icon():
	var b = admin_button
	var c = Color(1, 1, 1, 0.95) if not admin_open else Color(0.55, 1.0, 1.0, 1.0)
	var o = b.rect_size / 2.0
	var pts = PoolVector2Array([o + Vector2(-6, -7), o + Vector2(6, -7), o + Vector2(6, 0), o + Vector2(0, 7), o + Vector2(-6, 0)])
	b.draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.25))
	pts.append(pts[0])
	b.draw_polyline(pts, c, 1.5, true)
	b.draw_line(o + Vector2(0, -4), o + Vector2(0, 4), c, 1.5)


# the clipboard is drawn, so it does not depend on any font having an icon for it
func _draw_clipboard():
	var b = board_button
	var c = Color(1, 1, 1, 0.95) if not b.disabled else Color(1, 1, 1, 0.4)
	var o = (b.rect_size - Vector2(12, 14)) / 2.0
	o = Vector2(floor(o.x), floor(o.y))
	b.draw_rect(Rect2(o + Vector2(0, 2), Vector2(12, 12)), c, false)
	b.draw_rect(Rect2(o + Vector2(3, 0), Vector2(6, 3)), c, true)
	b.draw_rect(Rect2(o + Vector2(3, 6), Vector2(6, 1)), c, true)
	b.draw_rect(Rect2(o + Vector2(3, 9), Vector2(6, 1)), c, true)


func _on_buy_toggle():
	shop_open = not shop_open


func _on_buy_item(id):
	buy_ready_at = OS.get_ticks_msec() + BUY_DEBOUNCE_MS
	shop_open = false
	_say("!buy " + str(id))


func _on_gamble():
	_do_gamble()


func _on_bet_entered(text):
	_do_gamble()
	bet_field.release_focus()


func _do_gamble():
	# the server explains the limits or missing coins in chat
	var amount = int(bet_field.text)
	if amount <= 0:
		return
	gamble_ready_at = OS.get_ticks_msec() + GAMBLE_DEBOUNCE_MS
	_say("!gamble " + str(amount))


# only digits in the bet box
func _on_bet_changed(text):
	var clean = ""
	for i in range(text.length()):
		var c = text[i]
		if c >= "0" and c <= "9":
			clean += c
	if clean != text:
		var caret = bet_field.caret_position
		bet_field.text = clean
		bet_field.caret_position = min(caret, clean.length())


# While the box has the keyboard the game must not react to the keys: the game counts a "popup" as
# something that takes over the controls, which is what stops digits from changing the hotbar
func _on_bet_focus():
	var hud = _get_hud()
	if hud == null:
		return
	var popups = hud.get("popups")
	if typeof(popups) == TYPE_ARRAY and not popups.has(POPUP_ID):
		popups.append(POPUP_ID)
	locked_hud = hud


func _on_bet_unfocus():
	pending_unlock = true


func _typing_field():
	if bet_field != null and bet_field.has_focus():
		return bet_field
	if chalk_name_field != null and chalk_name_field.has_focus():
		return chalk_name_field
	return null


func _unlock_hud():
	if locked_hud != null and is_instance_valid(locked_hud):
		var popups = locked_hud.get("popups")
		if typeof(popups) == TYPE_ARRAY:
			popups.erase(POPUP_ID)
	locked_hud = null


# --- the Chalk menu ---
# Opens under the panel with the Chalk button. Pick a canvas (it follows the nearest one until you click one),
# type a name and Save, or Load, Share or Delete one of your saves. Everything goes through the server's own
# !chalk commands, so the server still decides and answers in chat.

func _build_chalk(column):
	chalk_box = VBoxContainer.new()
	chalk_box.visible = false
	chalk_box.add_constant_override("separation", 4)
	chalk_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(chalk_box)

	var canvas_row = HBoxContainer.new()
	canvas_row.add_constant_override("separation", 4)
	canvas_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chalk_box.add_child(canvas_row)
	var label = Label.new()
	label.text = "Canvas"
	label.add_color_override("font_color", Color(0.75, 0.95, 1.0))
	canvas_row.add_child(label)
	chalk_canvas_buttons = []
	for i in range(CHALK_CANVASES):
		var b = Button.new()
		b.text = str(i)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.rect_min_size = Vector2(28, 0)
		b.connect("pressed", self, "_on_chalk_canvas", [i])
		_glass_button(b)
		canvas_row.add_child(b)
		chalk_canvas_buttons.append(b)
	chalk_near_label = Label.new()
	chalk_near_label.add_color_override("font_color", Color(1, 1, 1, 0.55))
	canvas_row.add_child(chalk_near_label)

	chalk_save_row = HBoxContainer.new()
	chalk_save_row.add_constant_override("separation", 6)
	chalk_save_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chalk_box.add_child(chalk_save_row)
	chalk_name_field = LineEdit.new()
	chalk_name_field.placeholder_text = "save name"
	chalk_name_field.max_length = CHALK_NAME_MAX
	chalk_name_field.rect_min_size = Vector2(130, 0)
	chalk_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chalk_name_field.caret_blink = true
	chalk_name_field.add_stylebox_override("normal", _glass(Color(0, 0, 0, 0.30), Color(0.55, 1.0, 1.0, 0.35), 8, 0))
	chalk_name_field.add_stylebox_override("focus", _glass(Color(0, 0, 0, 0.40), Color(0.8, 1.0, 1.0, 0.9), 8, 0))
	chalk_name_field.add_color_override("font_color", Color(1, 1, 1))
	chalk_name_field.connect("text_changed", self, "_on_chalk_name_changed")
	chalk_name_field.connect("focus_entered", self, "_on_bet_focus")
	chalk_name_field.connect("focus_exited", self, "_on_bet_unfocus")
	chalk_name_field.connect("text_entered", self, "_on_chalk_name_entered")
	chalk_save_row.add_child(chalk_name_field)
	chalk_save_button = Button.new()
	chalk_save_button.text = "Save"
	chalk_save_button.focus_mode = Control.FOCUS_NONE
	chalk_save_button.rect_min_size = Vector2(64, 0)
	chalk_save_button.connect("pressed", self, "_on_chalk_save")
	_glass_button(chalk_save_button)
	chalk_save_row.add_child(chalk_save_button)

	# somebody is sharing a save with you
	chalk_offer_row = HBoxContainer.new()
	chalk_offer_row.visible = false
	chalk_offer_row.add_constant_override("separation", 6)
	chalk_offer_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chalk_box.add_child(chalk_offer_row)
	chalk_offer_label = Label.new()
	chalk_offer_label.clip_text = true
	chalk_offer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chalk_offer_label.rect_min_size = Vector2(120, 0)
	chalk_offer_label.add_color_override("font_color", Color(1.0, 0.85, 0.4))
	chalk_offer_row.add_child(chalk_offer_label)
	var accept = Button.new()
	accept.text = "Accept"
	accept.focus_mode = Control.FOCUS_NONE
	accept.connect("pressed", self, "_on_chalk_offer", [true])
	_glass_button(accept)
	chalk_offer_row.add_child(accept)
	var decline = Button.new()
	decline.text = "Decline"
	decline.focus_mode = Control.FOCUS_NONE
	decline.connect("pressed", self, "_on_chalk_offer", [false])
	_glass_button(decline)
	chalk_offer_row.add_child(decline)

	chalk_count_label = Label.new()
	chalk_count_label.add_color_override("font_color", Color(1, 1, 1, 0.55))
	chalk_box.add_child(chalk_count_label)

	chalk_list = VBoxContainer.new()
	chalk_list.add_constant_override("separation", 3)
	chalk_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chalk_box.add_child(chalk_list)

	# admins only: everybody's saves, each player opens to show their drawings
	chalk_all_button = Button.new()
	chalk_all_button.visible = false
	chalk_all_button.focus_mode = Control.FOCUS_NONE
	chalk_all_button.align = Button.ALIGN_LEFT
	chalk_all_button.connect("pressed", self, "_on_chalk_all_toggle")
	_glass_button(chalk_all_button)
	chalk_box.add_child(chalk_all_button)
	_add_tooltip(chalk_all_button, "All players", "Every player's chalk saves, to look at and load")

	chalk_all_list = VBoxContainer.new()
	chalk_all_list.visible = false
	chalk_all_list.add_constant_override("separation", 3)
	chalk_all_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chalk_box.add_child(chalk_all_list)


func _poll_chalk(net, lobby):
	var info = str(steam.getLobbyData(lobby, "wp_chalk")).split(",")
	chalk_on = info.size() >= 4
	if not chalk_on:
		chalk_open = false
		return
	chalk_save_all = info[0] == "1"
	chalk_load_all = info[1] == "1"
	chalk_max = int(info[2])
	chalk_cooldown = int(info[3])

	var me = str(net.STEAM_ID)
	chalk_names = Array(str(steam.getLobbyData(lobby, "wp_cs" + me)).split(",", false))
	chalk_offer = str(steam.getLobbyData(lobby, "wp_co" + me))
	if chalk_offer != chalk_offer_answered:
		chalk_offer_answered = ""

	if not chalk_names.has(chalk_share_for):
		chalk_share_for = ""
	_find_nearest_canvas()

	if chalk_all_open and not (is_admin and chalk_open):
		_close_chalk_all()
	if chalk_all_open:
		chalk_owners = []
		for entry in str(steam.getLobbyData(lobby, "wp_ca" + me)).split(";", false):
			var bits = entry.split("~")
			if bits.size() >= 3:
				chalk_owners.append([bits[0], bits[1], int(bits[2])])
		chalk_browse_names = []
		var browse = str(steam.getLobbyData(lobby, "wp_cb" + me)).split("~")
		if browse.size() >= 2 and browse[0] == chalk_browse_id:
			chalk_browse_names = Array(browse[1].split(",", false))

	if chalk_open:
		_rebuild_chalk(net, lobby)
		_rebuild_chalk_all()


# every chalk canvas in the world, found once (and again after the map changes)
func _find_canvases():
	for node in canvas_nodes:
		if not is_instance_valid(node):
			canvas_nodes = []
			break
	if not canvas_nodes.empty():
		return
	var scene = get_tree().current_scene
	if scene == null:
		return
	var zones = scene.find_node("chalk_zones", true, false)
	if zones == null:
		return
	for child in zones.get_children():
		if child is Spatial and child.get("canvas_id") != null:
			canvas_nodes.append(child)


func _find_nearest_canvas():
	chalk_nearest = -1
	var players = get_tree().get_nodes_in_group("controlled_player")
	if players.empty():
		return
	_find_canvases()
	var me = players[0].global_transform.origin
	var best = INF
	for node in canvas_nodes:
		var there = node.global_transform.origin
		var d = Vector2(there.x - me.x, there.z - me.z).length()
		if d < best:
			best = d
			chalk_nearest = int(node.get("canvas_id"))
	if not chalk_picked and chalk_nearest >= 0:
		chalk_canvas = chalk_nearest


# the list of saves, only rebuilt when something in it changed
func _rebuild_chalk(net, lobby):
	var people = []
	if chalk_share_for != "":
		var host = str(steam.getLobbyOwner(lobby))
		for member in net.LOBBY_MEMBERS:
			var id = str(member.get("steam_id", ""))
			if id == "" or id == host or id == str(net.STEAM_ID):
				continue
			people.append([str(member.get("steam_name", id)), id])
		people.sort_custom(self, "_by_name")
	var signature = str([chalk_names, chalk_share_for, people, _may_load()])
	if signature == chalk_signature:
		return
	chalk_signature = signature

	for child in chalk_list.get_children():
		chalk_list.remove_child(child)
		child.queue_free()

	if chalk_names.empty():
		var none = Label.new()
		none.text = "No saves yet"
		none.add_color_override("font_color", Color(1, 1, 1, 0.55))
		chalk_list.add_child(none)

	for save in chalk_names:
		var row = HBoxContainer.new()
		row.add_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chalk_list.add_child(row)

		# clicking the name puts it in the name box, to save over it
		var name = Button.new()
		name.text = save
		name.flat = true
		name.clip_text = true
		name.align = Button.ALIGN_LEFT
		name.focus_mode = Control.FOCUS_NONE
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.rect_min_size = Vector2(110, 0)
		name.add_color_override("font_color", Color(1, 1, 1))
		name.add_color_override("font_color_hover", Color(0.55, 1.0, 1.0))
		name.connect("pressed", self, "_on_chalk_pick_name", [save])
		row.add_child(name)

		if _may_load():
			var load_btn = Button.new()
			load_btn.focus_mode = Control.FOCUS_NONE
			load_btn.rect_min_size = Vector2(52, 0)
			load_btn.set_meta("chalk_load", save)
			load_btn.set_meta("chalk_owner", "")
			load_btn.connect("pressed", self, "_on_chalk_load", [save, ""])
			_glass_button(load_btn)
			row.add_child(load_btn)

		var share = Button.new()
		share.text = "Share"
		share.focus_mode = Control.FOCUS_NONE
		share.connect("pressed", self, "_on_chalk_share", [save])
		_glass_button(share)
		if chalk_share_for == save:
			share.add_stylebox_override("normal", _glass(Color(0.3, 1.0, 1.0, 0.40), Color(0.8, 1.0, 1.0, 0.9), 8, 0))
		row.add_child(share)

		var delete = Button.new()
		delete.focus_mode = Control.FOCUS_NONE
		delete.rect_min_size = Vector2(56, 0)
		delete.set_meta("chalk_delete", save)
		delete.set_meta("chalk_owner", "")
		delete.connect("pressed", self, "_on_chalk_delete", [save, ""])
		_glass_button(delete)
		delete.add_stylebox_override("normal", _glass(Color(0.45, 0.08, 0.08, 0.45), Color(1.0, 0.5, 0.5, 0.55), 8, 0))
		row.add_child(delete)

		# who to share it with
		if chalk_share_for == save:
			var grid = GridContainer.new()
			grid.columns = 2
			grid.add_constant_override("hseparation", 4)
			grid.add_constant_override("vseparation", 3)
			grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chalk_list.add_child(grid)
			if people.empty():
				var nobody = Label.new()
				nobody.text = "Nobody else is here"
				nobody.add_color_override("font_color", Color(1, 1, 1, 0.55))
				grid.add_child(nobody)
			for person in people:
				var give = Button.new()
				give.text = person[0]
				give.clip_text = true
				give.rect_min_size = Vector2(110, 0)
				give.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				give.focus_mode = Control.FOCUS_NONE
				give.connect("pressed", self, "_on_chalk_share_to", [save, person[1]])
				_glass_button(give)
				grid.add_child(give)

	panel.rect_size = Vector2()


func _may_save():
	return chalk_save_all or is_admin


func _may_load():
	return chalk_load_all or is_admin


func _armed(key, now):
	return chalk_armed.get(key, 0) > now


# a click that needs a second one within a few seconds; true when this was the second one
func _arm(key):
	var now = OS.get_ticks_msec()
	if _armed(key, now):
		chalk_armed.erase(key)
		return true
	chalk_armed.clear()
	chalk_armed[key] = now + ARM_MS
	return false


func _refresh_chalk(now):
	chalk_button.visible = chalk_on
	var show = chalk_on and chalk_open
	if chalk_box.visible != show:
		chalk_box.visible = show
		if not show and chalk_name_field.has_focus():
			chalk_name_field.release_focus()
		panel.rect_size = Vector2()
	chalk_button.add_color_override("font_color", Color(0.55, 1.0, 1.0) if chalk_open else Color(1, 1, 1))
	if not show:
		return

	for i in range(chalk_canvas_buttons.size()):
		chalk_canvas_buttons[i].pressed = i == chalk_canvas
	chalk_near_label.text = "nearest" if chalk_canvas >= 0 and chalk_canvas == chalk_nearest else ""

	var typed = chalk_name_field.text
	var exists = chalk_names.has(typed)
	chalk_save_row.visible = _may_save()
	if _armed("save", now):
		chalk_save_button.text = "Sure?"
	else:
		chalk_save_button.text = "Replace" if exists else "Save"
	chalk_save_button.disabled = typed == "" or chalk_canvas < 0 or now < chalk_ready_at \
		or (not exists and chalk_names.size() >= chalk_max)

	var offer = chalk_offer.split("~")
	chalk_offer_row.visible = offer.size() >= 2 and chalk_offer != chalk_offer_answered
	if chalk_offer_row.visible:
		chalk_offer_label.text = offer[0] + " shares \"" + offer[1] + "\""

	chalk_count_label.text = str(chalk_names.size()) + " of " + str(chalk_max) + " saves"

	chalk_all_button.visible = is_admin
	chalk_all_button.text = ("-  " if chalk_all_open else "+  ") + "All players"
	chalk_all_list.visible = is_admin and chalk_all_open

	var wait = int(ceil((chalk_load_ready_at - now) / 1000.0))
	for row in chalk_list.get_children() + chalk_all_list.get_children():
		for b in row.get_children():
			if b.has_meta("chalk_load"):
				var save = b.get_meta("chalk_load")
				if _armed("load:" + b.get_meta("chalk_owner") + ":" + save, now):
					b.text = "Sure?"
				elif wait > 0:
					b.text = str(wait) + "s"
				else:
					b.text = "Load"
				b.disabled = chalk_canvas < 0 or now < chalk_load_ready_at or now < chalk_ready_at
			elif b.has_meta("chalk_delete"):
				b.text = "Sure?" if _armed("delete:" + b.get_meta("chalk_owner") + ":" + b.get_meta("chalk_delete"), now) else "Delete"
				b.disabled = now < chalk_ready_at


func _on_chalk_toggle():
	chalk_open = not chalk_open
	if not chalk_open and chalk_all_open:
		_close_chalk_all()
	chalk_signature = ""
	chalk_share_for = ""
	chalk_armed.clear()
	chalk_picked = false # opening again follows the nearest canvas
	if chalk_open:
		var net = get_node_or_null("/root/Network")
		if net != null and steam != null:
			_poll_chalk(net, net.STEAM_LOBBY_ID)


func _on_chalk_canvas(i):
	chalk_canvas = i
	chalk_picked = true
	chalk_armed.clear()


# names become file names on the server: letters, numbers, - and _ only
func _on_chalk_name_changed(text):
	var clean = ""
	for c in text.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "-" or c == "_":
			if clean == "" and (c == "-" or c == "_"):
				continue
			clean += c
	if clean != text:
		var caret = chalk_name_field.caret_position
		chalk_name_field.text = clean
		chalk_name_field.caret_position = min(caret, clean.length())
	chalk_armed.erase("save")


func _on_chalk_name_entered(_text):
	_on_chalk_save()
	chalk_name_field.release_focus()


func _on_chalk_pick_name(save):
	chalk_name_field.text = save
	chalk_armed.clear()


func _on_chalk_save():
	var name = chalk_name_field.text
	if name == "" or chalk_canvas < 0 or OS.get_ticks_msec() < chalk_ready_at:
		return
	# saving over one of your saves needs a second click
	if chalk_names.has(name) and not _arm("save"):
		return
	chalk_armed.clear()
	chalk_ready_at = OS.get_ticks_msec() + CHALK_DEBOUNCE_MS
	_say("!chalksave " + name + " " + str(chalk_canvas))


# loading wipes what is drawn on that canvas now, so it needs a second click
# owner is a Steam ID for an admin loading somebody else's save, empty for your own
func _on_chalk_load(save, owner):
	if chalk_canvas < 0 or not _arm("load:" + owner + ":" + save):
		return
	var now = OS.get_ticks_msec()
	chalk_ready_at = now + CHALK_DEBOUNCE_MS
	chalk_load_ready_at = now + (CHALK_DEBOUNCE_MS if is_admin else max(chalk_cooldown * 1000, CHALK_DEBOUNCE_MS))
	_say("!chalkload " + save + " " + str(chalk_canvas) + ("" if owner == "" else " " + owner))


func _on_chalk_delete(save, owner):
	if not _arm("delete:" + owner + ":" + save):
		return
	chalk_ready_at = OS.get_ticks_msec() + CHALK_DEBOUNCE_MS
	_say("!chalkdelete " + save + ("" if owner == "" else " " + owner))


func _on_chalk_share(save):
	chalk_armed.clear()
	chalk_share_for = "" if chalk_share_for == save else save
	chalk_signature = ""
	var net = get_node_or_null("/root/Network")
	if net != null and steam != null:
		_rebuild_chalk(net, net.STEAM_LOBBY_ID)


func _on_chalk_share_to(save, id):
	chalk_share_for = ""
	chalk_signature = ""
	_say("!chalkshare " + save + " " + str(id))
	var net = get_node_or_null("/root/Network")
	if net != null and steam != null:
		_rebuild_chalk(net, net.STEAM_LOBBY_ID)


func _on_chalk_all_toggle():
	if chalk_all_open:
		_close_chalk_all()
	else:
		chalk_all_open = true
		chalk_all_signature = ""
		chalk_all_opened_at = OS.get_ticks_msec()
		_say("!chalkowners")


func _close_chalk_all():
	chalk_all_open = false
	chalk_browse_id = ""
	chalk_owners = []
	chalk_browse_names = []
	chalk_all_signature = ""
	for child in chalk_all_list.get_children():
		chalk_all_list.remove_child(child)
		child.queue_free()
	panel.rect_size = Vector2()
	if is_admin:
		_say("!chalkowners off")


func _on_chalk_owner(id):
	chalk_armed.clear()
	if chalk_browse_id == id:
		chalk_browse_id = ""
		_say("!chalkbrowse")
	else:
		chalk_browse_id = id
		_say("!chalkbrowse " + id)
	chalk_browse_names = []
	_rebuild_chalk_all()


func _rebuild_chalk_all():
	if not chalk_all_open:
		return
	var waiting = chalk_owners.empty() and OS.get_ticks_msec() - chalk_all_opened_at < 4000
	var signature = str([chalk_owners, chalk_browse_id, chalk_browse_names, _may_load(), waiting])
	if signature == chalk_all_signature:
		return
	chalk_all_signature = signature

	for child in chalk_all_list.get_children():
		chalk_all_list.remove_child(child)
		child.queue_free()

	if chalk_owners.empty():
		var none = Label.new()
		none.text = "Loading..." if waiting else "Nobody has saves yet"
		none.add_color_override("font_color", Color(1, 1, 1, 0.55))
		chalk_all_list.add_child(none)

	for entry in chalk_owners:
		var row = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chalk_all_list.add_child(row)
		var open = entry[0] == chalk_browse_id
		var who = Button.new()
		who.text = ("-  " if open else "+  ") + entry[1] + "  (" + str(entry[2]) + ")"
		who.flat = true
		who.clip_text = true
		who.align = Button.ALIGN_LEFT
		who.focus_mode = Control.FOCUS_NONE
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.rect_min_size = Vector2(200, 0)
		who.add_color_override("font_color", Color(0.55, 1.0, 1.0) if open else Color(0.75, 0.95, 1.0))
		who.add_color_override("font_color_hover", Color(1, 1, 1))
		who.connect("pressed", self, "_on_chalk_owner", [entry[0]])
		row.add_child(who)
		if not open:
			continue

		if chalk_browse_names.empty():
			var wait = Label.new()
			wait.text = "      ..."
			wait.add_color_override("font_color", Color(1, 1, 1, 0.55))
			chalk_all_list.add_child(wait)
		for save in chalk_browse_names:
			var line = HBoxContainer.new()
			line.add_constant_override("separation", 6)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chalk_all_list.add_child(line)
			var name = Label.new()
			name.text = "      " + save
			name.clip_text = true
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name.rect_min_size = Vector2(110, 0)
			name.add_color_override("font_color", Color(1, 1, 1))
			line.add_child(name)
			var load_btn = Button.new()
			load_btn.focus_mode = Control.FOCUS_NONE
			load_btn.rect_min_size = Vector2(52, 0)
			load_btn.set_meta("chalk_load", save)
			load_btn.set_meta("chalk_owner", entry[0])
			load_btn.connect("pressed", self, "_on_chalk_load", [save, entry[0]])
			_glass_button(load_btn)
			line.add_child(load_btn)
			var delete = Button.new()
			delete.focus_mode = Control.FOCUS_NONE
			delete.rect_min_size = Vector2(56, 0)
			delete.set_meta("chalk_delete", save)
			delete.set_meta("chalk_owner", entry[0])
			delete.connect("pressed", self, "_on_chalk_delete", [save, entry[0]])
			_glass_button(delete)
			delete.add_stylebox_override("normal", _glass(Color(0.45, 0.08, 0.08, 0.45), Color(1.0, 0.5, 0.5, 0.55), 8, 0))
			line.add_child(delete)

	panel.rect_size = Vector2()


func _on_chalk_offer(take):
	chalk_offer_answered = chalk_offer # hidden until the server says something new
	_say("!chalkaccept" if take else "!chalkdecline")


# --- typed commands and moving the panel ---

# typed commands: when Enter is pressed with a ! message in the chat box, take it before the game
# sends it, send it to the server only and empty the box so the game has nothing left to say
func _input(event):
	if dragging:
		_drag(event)
		return

	# Escape or a click somewhere else lets go of the bet box (or the chalk name box)
	var field = _typing_field()
	if field != null:
		if event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
			field.release_focus()
			get_tree().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed:
			if not field.get_global_rect().has_point(event.position):
				field.release_focus()
		return

	if not active or not event.is_action_pressed("chat_enter"):
		return
	var hud = _get_hud()
	if hud == null or hud.get("using_chat") != true:
		return
	var box = hud.get("chat")
	if box == null:
		return
	var typed = str(box.text).strip_edges()
	if typed.begins_with("!"):
		if _send_hidden(typed):
			box.text = ""


func _on_grip_input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			drag_offset = panel.rect_position - panel.get_global_mouse_position()
		else:
			_save_config()


func _drag(event):
	if event is InputEventMouseMotion:
		var pos = panel.get_global_mouse_position() + drag_offset
		var area = get_viewport().get_visible_rect().size
		pos.x = clamp(pos.x, 0, max(0, area.x - panel.rect_size.x))
		pos.y = clamp(pos.y, 0, max(0, area.y - panel.rect_size.y))
		panel.rect_position = pos
	elif event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
		dragging = false
		_save_config()


func _load_config():
	var file = File.new()
	if not file.file_exists(CONFIG_PATH):
		return
	if file.open(CONFIG_PATH, File.READ) != OK:
		return
	var data = parse_json(file.get_as_text())
	file.close()
	if typeof(data) == TYPE_DICTIONARY and data.has("x") and data.has("y"):
		panel.rect_position = Vector2(float(data["x"]), float(data["y"]))
	if typeof(data) == TYPE_DICTIONARY and data.has("prev_title"):
		prev_title = str(data["prev_title"])


func _save_config():
	var file = File.new()
	if file.open(CONFIG_PATH, File.WRITE) != OK:
		return
	file.store_string(to_json({"x": panel.rect_position.x, "y": panel.rect_position.y, "prev_title": prev_title}))
	file.close()
