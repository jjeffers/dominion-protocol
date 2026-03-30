class_name FactionNameGenerator
extends RefCounted

const ADJECTIVES = [
	"Free", "Central", "Global", "United", "Allied", "Sovereign", "Democratic",
	"Supreme", "Independent", "People's", "Sacred", "Progressive", "Mutual",
	"Federated", "Territorial", "Imperial", "Colonial", "Strategic", "Solar",
	"Stellar", "Galactic", "Outer", "Inner", "Holy", "Prosperous", "Harmonious",
	"Iron", "Golden", "Crimson", "Azure", "Emerald", "Eternal", "New", "Grand",
	"Universal"
]

const NOUNS = [
	"States", "Nations", "Territories", "Colonies", "Systems", "Planets", 
	"Earth", "Sectors", "Zones", "Worlds", "Stars", "Moons", "Realms",
	"Frontier", "Expanse", "Starsystems"
]

const IDEOLOGY_NOUNS = [
	"Security", "Defense", "Commerce", "Trade", "Order", "Liberty", "Justice", 
	"Progress", "Faith", "Unity", "Harmony", "Power", "Strength", "Freedom",
	"Prosperity", "Wealth", "Industry", "Science", "Knowledge", "Truth",
	"Destiny", "Purity", "Reason", "Logic"
]

const GROUPS = [
	"Coalition", "Pact", "Alliance", "Union", "Federation", "Confederation", 
	"Republic", "Empire", "Syndicate", "Directorate", "Authority", "Collective", 
	"Commonwealth", "Concordat", "League", "Bloc", "Ascendancy", "Dominion", 
	"Hegemony", "Network", "Assembly", "Consortium", "Conglomerate", "Trust",
	"Front", "Brotherhood", "Order", "Society", "Council"
]

const FORMATS = [
	"{group} of {adjectives}", # e.g. "Coalition of Free States"
	"{adjective} {ideology_noun} {group}", # e.g. "Central Security Pact"
	"{adjective} {noun} {group}", # e.g. "United Systems Federation"
	"The {ideology_noun} {group}", # e.g. "The Trade Federation"
	"{group} of {noun}", # e.g. "Republic of Earth"
	"{adjective} {group}", # e.g. "Sovereign Collective"
	"{group} of {ideology_noun}" # e.g. "League of Progress"
]

static func generate_faction_name() -> String:
	# Randomize seed is usually called once globally in Godot, 
	# but calling it here just in case, though it's safe to assume global randi() is seeded.
	# Actually, best practice in Godot 4.x is to use randi() or RandomNumberGenerator.
	var format: String = FORMATS[randi() % FORMATS.size()]
	
	var name: String = format
	
	if "{adjectives}" in name:
		var adj = ADJECTIVES[randi() % ADJECTIVES.size()]
		var noun = NOUNS[randi() % NOUNS.size()]
		name = name.replace("{adjectives}", adj + " " + noun)
		
	if "{adjective}" in name:
		name = name.replace("{adjective}", ADJECTIVES[randi() % ADJECTIVES.size()])
		
	if "{noun}" in name:
		name = name.replace("{noun}", NOUNS[randi() % NOUNS.size()])
		
	if "{ideology_noun}" in name:
		name = name.replace("{ideology_noun}", IDEOLOGY_NOUNS[randi() % IDEOLOGY_NOUNS.size()])
		
	if "{group}" in name:
		name = name.replace("{group}", GROUPS[randi() % GROUPS.size()])
		
	return name

static func generate_faction_acronym(faction_name: String) -> String:
	# Ignore small words
	var ignored_words = ["of", "the", "and", "in", "on", "at"]
	var acronym = ""
	var words = faction_name.split(" ", false) # false drops empty strings
	for word in words:
		word = word.to_lower().strip_edges()
		if not word in ignored_words and word.length() > 0:
			acronym += word.substr(0, 1).to_upper()
	return acronym
