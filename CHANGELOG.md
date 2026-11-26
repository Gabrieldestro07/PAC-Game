# Fish Like a Banker - Histórico de alterações

## v9 - Preparação para pixel art
- Janela do jogo em 1280x720 (antes abria em 1152x648 e cortava o cenário).
- Filtro de textura "Nearest" por padrão, para os pixels ficarem nítidos.

## v8 - Vencer o jogo da velha = vender
- Vencer o jogo da velha vende todos os peixes pelo valor normal. Perder ou empatar não vende nada (dá para tentar de novo).
- Removido o antigo sistema de venda (diálogo de digitar o total) e o arquivo scripts/Merchant.gd.
- Clicar no botão ou no painel do inventário não move mais o personagem.

## v7 - Ajuste da barra
- Barra de pesca mais 10 pixels para a esquerda (margem da borda direita: 78).

## v6 - Jogo da velha do comerciante
- Ao falar com o comerciante, abre um jogo da velha em cima da cabeça dele (tabuleiro transparente, linhas pretas).
- Cada casa tem uma conta; o jogador digita o resultado de uma casa livre para marcar X (vermelho). Resultados nunca se repetem no tabuleiro.
- O comerciante marca O (preto) numa casa livre aleatória a cada 10 segundos.
- Ao terminar a partida, abre a venda normal (conta do total), como antes. ESC sai do jogo da velha.
- Barra de pesca 8 pixels mais para a esquerda.

## v5 - Correção da posição da barra
- A barra da v4 ficava fora da janela (a janela padrão do Godot tem 1152 de largura). Agora a posição é calculada a partir do tamanho real da janela.

## v4 - Só digitar na pesca
- O campo de resposta continua selecionado depois de cada resposta (acerto ou erro): não precisa mais clicar com o mouse.
- Barra de pesca movida para o canto direito da tela.

## v3 - Barra de pesca vertical e discreta
- Barra vertical, menor, no canto esquerdo da tela, sem painel em volta.
- A conta aparece em cima da barra; a resposta aparece embaixo, sem caixa.
- A barra desce 50% mais devagar (0.05 -> 0.025 por segundo).

## v2 - Pesca em barra, peixes e código organizado
- Pesca em barra: cada acerto de uma conta simples (soma, subtração, multiplicação) sobe a barra; ela desce com o tempo; errar tira um pouco.
- Barra verde clara e translúcida; fica dourada ao completar e some.
- 3 espécies de peixe (Lambari, Tilapia, Dourado) com tamanhos e valores diferentes. Quanto mais rápido encher a barra, maior a chance de peixe raro.
- Inventário agora respeita o tamanho de cada peixe e avisa quando está cheio.
- Comerciante lista os peixes por espécie e o jogador calcula o total.
- Código dividido: Main.gd + scripts/FishData.gd, Inventory.gd, FishingBar.gd, Merchant.gd.

## v1 - Protótipo base (N2)
- Movimento por clique, pesca com multiplicação, inventário arrastável e venda ao comerciante.

## v10
- Ajuste dos pes ao piso da grama e do pier, acesso suave e limite na ponta.
- Pesca restrita aos ultimos 18 pixels do percurso.

## v12
- Inventário 6x6 translúcido, arrastar, girar com R, validar colisão e limites, contador de espaço.
- Tamanhos azul 2x1, verde 3x1, dourado 4x2. Mantidas as três raridades e o sorteio original; vermelho, místico e bota não entram no inventário nesta versão.

## v16
- Autosave de ações importantes e restauração de posições do inventário.
- Ajustes de escala, piso e interação do trem.
- Ícone de fuga removido; cadeado atualizado. Tutorial preservado.
