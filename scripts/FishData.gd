extends RefCounted

# ============================================================
# DADOS DOS PEIXES
# Aqui ficam as espécies, os valores e o sorteio por velocidade.
# Para criar uma espécie nova, basta adicionar uma entrada em "types".
# ============================================================

const FAST_CATCH_SECONDS = 15.0
const FAST_CATCH_WITH_CLOCK_SECONDS = 20.0
const SLOW_CATCH_SECONDS = 60.0

# Ordem de exibição (usada, por exemplo, no resumo do comerciante)
const ORDER = ["comum", "incomum", "raro"]

# tamanho = quantos slots o peixe ocupa no inventário (largura, altura)
# A cor é temporária: serve só para diferenciar até chegarem as texturas novas.
static var types = {
	"vermelho": {"nome":"Peixe vermelho","valor":80,"tamanho":Vector2i(3,1),"cor":Color.RED},
	"ambar": {"nome":"Peixe Âmbar","valor":110,"tamanho":Vector2i(3,1),"cor":Color("e6a34d")},
	"mistico": {"nome":"Peixe místico","valor":150,"tamanho":Vector2i(3,2),"cor":Color.PURPLE},
	"fantasma": {"nome":"Peixe Fantasma","valor":500,"tamanho":Vector2i(4,2),"cor":Color.GREEN},
	"comum": {
		"nome": "Lambari",
		"valor": 10,
		"tamanho": Vector2i(2, 1),
		"cor": Color(0.85, 0.9, 1.0)
	},
	"incomum": {
		"nome": "Tilapia",
		"valor": 25,
		"tamanho": Vector2i(3, 1),
		"cor": Color(1.0, 0.8, 0.55)
	},
	"bota": {"nome": "Bota do Corinthians", "valor": 1, "tamanho": Vector2i(1, 2), "cor": Color.GRAY},
	"raro": {
		"nome": "Dourado",
		"valor": 60,
		"tamanho": Vector2i(4, 2),
		"cor": Color(1.0, 0.85, 0.25)
	}
}

# Valor total de uma venda. counts = algo como {"comum": 2, "raro": 1}
static func total_value(counts):

	var total = 0

	for kind in counts:
		total += counts[kind] * types[kind]["valor"]

	return total

static func catch_slowness(time_taken: float, clock: bool) -> float:
	var fast = FAST_CATCH_WITH_CLOCK_SECONDS if clock else FAST_CATCH_SECONDS
	return clampf(inverse_lerp(fast, SLOW_CATCH_SECONDS, time_taken), 0.0, 1.0)

static func boot_chance(slowness: float, worm: bool, clock: bool) -> float:
	var chance = lerpf(0.02, 0.06, slowness) if worm else lerpf(0.07, 0.16, slowness)
	return maxf(0.01, chance - (0.02 if clock else 0.0))

static func pick_type(time_taken: float, worm := false, clock := false) -> String:
	var slowness = catch_slowness(time_taken, clock)
	var boot = boot_chance(slowness, worm, clock)
	var rare = lerpf(0.11, 0.05, slowness) + (0.04 if worm else 0.0)
	var uncommon = lerpf(0.24, 0.14, slowness) + (0.08 if worm else 0.0)
	var roll = randf()
	if roll < boot: return "bota"
	if roll < boot + rare: return "raro"
	if roll < boot + rare + uncommon: return "incomum"
	return "comum"

static func pick_cave(time_taken: float, worm: bool, clock: bool, glasses: bool) -> String:
	var slowness = catch_slowness(time_taken, clock)
	var boot = boot_chance(slowness, worm, clock)
	var mystic = lerpf(0.17, 0.07, slowness) + (0.06 if worm else 0.0)
	var ghost = mystic - lerpf(0.04, 0.02, slowness) if glasses else 0.0
	var amber = lerpf(0.26, 0.20, slowness) + (0.02 if worm else 0.0)
	var roll = randf()
	if roll < boot: return "bota"
	if roll < boot + ghost: return "fantasma"
	if roll < boot + ghost + mystic: return "mistico"
	if roll < boot + ghost + mystic + amber: return "ambar"
	return "vermelho"
