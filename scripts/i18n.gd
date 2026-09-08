extends Node
## Tiny translation layer. All UI text is authored in assets/i18n.json and
## mirrored here as a const (scripts/translations.gd) so the font subsetter
## can read the same strings. Language order is ja, en, zh_hans, zh_hant, ko, ru.
const Translations = preload("res://scripts/translations.gd")
const LANG_CODES := ["ja", "en", "zh_hans", "zh_hant", "ko", "ru"]
const LANG_NATIVE := ["日本語", "English", "简体中文", "繁體中文", "한국어", "Русский"]
const FONT_PATHS := {
	"ja": "res://assets/fonts/ui_ja.ttf",
	"en": "res://assets/fonts/ui_en.ttf",
	"zh_hans": "res://assets/fonts/ui_zh_hans.ttf",
	"zh_hant": "res://assets/fonts/ui_zh_hant.ttf",
	"ko": "res://assets/fonts/ui_ko.ttf",
	"ru": "res://assets/fonts/ui_ru.ttf",
}
const DEFAULT_LANG := "ja"
var lang := DEFAULT_LANG
var _fonts := {}

signal language_changed(code: String)

func _ready():
	detect()

func detect():
	# --lang=en forces a language (also used for preview captures).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="):
			var forced := arg.trim_prefix("--lang=").to_lower()
			var alias := {"zh-cn": "zh_hans", "zh_cn": "zh_hans", "zh-tw": "zh_hant", "zh_tw": "zh_hant"}
			set_lang(alias.get(forced, forced))
			return
	# Auto-follow the device language where we ship a translation.
	var locale := OS.get_locale().to_lower()
	var code := "en"
	if locale.begins_with("ja"):
		code = "ja"
	elif locale.begins_with("zh"):
		code = "zh_hant" if (locale.contains("tw") or locale.contains("hk") or locale.contains("mo")) else "zh_hans"
	elif locale.begins_with("ko"):
		code = "ko"
	elif locale.begins_with("ru"):
		code = "ru"
	elif locale.begins_with("en"):
		code = "en"
	set_lang(code)

func set_lang(code: String):
	if code in LANG_CODES:
		lang = code
		_fonts.clear()
		language_changed.emit(lang)

func index() -> int:
	return LANG_CODES.find(lang)

func t(key: String) -> String:
	var table: Dictionary = Translations.KEYS
	if not table.has(key):
		return key
	var row: Array = table[key]
	if lang != "ja" and lang in LANG_CODES:
		var i := LANG_CODES.find(lang)
		if row.size() > i and not (row[i] as String).is_empty():
			return row[i]
	return row[0]

## Translate then apply %-style formatting arguments.
func tf(key: String, args: Array) -> String:
	return t(key) % args

## All language variants of a key, for "is this still the default?" checks.
func variants(key: String) -> Array:
	var table: Dictionary = Translations.KEYS
	if not table.has(key):
		return [key]
	return table[key]

func font() -> Font:
	if lang in _fonts:
		return _fonts[lang]
	var path: String = FONT_PATHS.get(lang, FONT_PATHS[DEFAULT_LANG])
	var f := load(path) as Font
	if f == null:
		f = load(FONT_PATHS[DEFAULT_LANG]) as Font
	_fonts[lang] = f
	return f
