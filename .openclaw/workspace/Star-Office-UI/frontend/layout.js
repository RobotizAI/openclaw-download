// Interface do Star Office - Configuração de Layout e Hierarquia

// Todas as coordenadas, profundidade e caminhos de recursos são gerenciados aqui.

// Evite números mágicos e reduza o risco de erros.

// Regras principais:

// - Recursos transparentes (como mesas) devem ser .png, recursos opacos devem ser .webp.

// - Hierarquia: Baixo → sofá(10) → estrelaTrabalhando(900) → mesa(1000) → flor(1100)

const LAYOUT = {

// === Tela do Jogo ===

jogo: {
largura: 1280,

altura: 720

},

// === Coordenadas da Área ===

áreas: {
porta: { x: 640, y: 550 },

escrita: { x: 320, y: 360 },

pesquisando: { x: 320, y: 360 },

erro: { x: 1066, y: 180 },

sala de descanso: { x: 640, y: 360 }

},

// === Decorações e Mobiliário: Coordenadas + Origem + Profundidade ===

mobiliário: {

// Sofá

sofá: {

x: 670,

y: 144,

origem: { x: 0, y: 0 },

profundidade: 10

},

// Nova Mesa (PNG Transparente Forçado)

mesa: {

x: 218,

y: 417,

origem: { x: 0.5, y: 0.5 },

profundidade: 1000

},

// Vaso de Flores na Mesa

flor: {

x: 310,

y: 390,

origem: { x: 0.5, y: 0.5 },

profundidade: 1100,

escala: 0.8

},

// Estrela Trabalhando em uma mesa (sob a mesa)

starWorking: {

x: 217,

y: 333,

origem: {x: 0.5, y: 0.5},

profundidade: 900,

escala: 1.32

},

// Plantas

plantas: [

{x: 565, y: 178, profundidade: 5},

{x: 230, y: 185, profundidade: 5},

{x: 977, y: 496, profundidade: 5}

],

// Pôster

pôster: {

x: 252,

y: 66,

profundidade: 4

},

// Máquina de Café

máquinaDeCafé: {

x: 659,

y: 397,

origem: {x: 0.5, y: 0.5},

profundidade: 99

},

// Área do servidor

sala do servidor: {

x: 1021,

y: 142,

origem: { x: 0.5, y: 0.5 },

profundidade: 2

},

// Bug

erroBug: {

x: 1007,

y: 221,

origem: { x: 0.5, y: 0.5 },

profundidade: 50,

escala: 0.9,

pingPong: { leftX: 1007, rightX: 1111, velocidade: 0.6 }

},

// Animação sincronizada

syncAnim: {

x: 1157,

y: 592,

origem: { x: 0.5, y: 0.5 },

profundidade: 40

},

// Gato

gato: {

x: 94,

y: 557,

origem: { x: 0.5, y: 0.5 },

profundidade: 2000

}
},

// === Placa ===
placa: {
x: 640,

y: 720 - 36,

largura: 420,

altura: 44

},

// === Regras de carregamento de recursos: Quais são forçadas a usar PNG (recursos transparentes) ===

forcePng: {
desk_v2: true // A nova mesa deve ser transparente, PNG forçado

},

// === Número total de recursos (usados ​​para a barra de progresso de carregamento) ===

totalAssets: 15

};
