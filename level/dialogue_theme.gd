class_name DialogueTheme extends RefCounted
## Paletas y fuentes compartidas; cada cuadro recibe su propia configuración.

const BODY_FONT: Font = preload("res://gui/fonts/DejaVuSans.ttf")
const BOLD_FONT: Font = preload("res://gui/fonts/DejaVuSans-Bold.ttf")
const RUSTIC_FONT: Font = preload("res://gui/fonts/DejaVuSerif-Bold.ttf")
const CITY_FONT: Font = preload("res://gui/fonts/DejaVuSansMono-Bold.ttf")

static func palette(level: int) -> Dictionary:
	match level:
		2:
			return {"background": Color("172632"), "border": Color("080f18"), "accent": Color("61d7e8"), "text": Color("edf5f6"), "muted": Color("acd0d7"), "detail": Color("7895a6"), "font": CITY_FONT}
		3:
			return {"background": Color("392b21"), "border": Color("1e1712"), "accent": Color("e6bd78"), "text": Color("fff0d8"), "muted": Color("d5c1a1"), "detail": Color("b68b54"), "font": RUSTIC_FONT}
		4:
			return {"background": Color("103c4c"), "border": Color("082632"), "accent": Color("79e3dc"), "text": Color("f0fcf5"), "muted": Color("bdded9"), "detail": Color("51b6c6"), "font": BOLD_FONT}
		5:
			return {"background": Color("19392a"), "border": Color("0b2019"), "accent": Color("b9db76"), "text": Color("f3f6da"), "muted": Color("c4d5a8"), "detail": Color("78a95a"), "font": BOLD_FONT}
		_:
			return {"background": Color("e8bd79"), "border": Color("713b21"), "accent": Color("8a391d"), "text": Color("382315"), "muted": Color("694329"), "detail": Color("a96b37"), "font": RUSTIC_FONT}
