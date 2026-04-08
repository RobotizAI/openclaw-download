// Interface do Star Office - Lógica Principal do Jogo

// Dependência: layout.js (deve ser carregado antes)

// Verifica se o navegador suporta WebP

let supportsWebP = false;

// Método 1: Usar canvas para verificar

function checkWebPSupport() {

return new Promise((resolve) => {

const canvas = document.createElement('canvas');

if (canvas.getContext && canvas.getContext('2d')) {

resolve(canvas.toDataURL('image/webp').indexOf('data:image/webp') === 0);

} else {

resolve(false);

}
});

// Método 2: Usar imagem para verificar (alternativo)

function checkWebPSupportFallback() {

return new Promise((resolve) => {

const img = new Image();

img.onload = () => resolve(true);

img.onerror = () => resolve(false);
img.src = 'data:image/webp;base64,UklGRkoAAABXRUJQVlA4WAoAAAAQAAAAAAAAAAAAQUxQSAwAAAABBxAR/Q9ERP8DAABWUDggGAAAADABAJ0BKgEAAQADADQlpAADcAD++/1QAA==';

});

}
// Obter a extensão do arquivo (com base no suporte a WebP + configuração forcePng do layout)

function getExt(pngFile) {

// star-working-spritesheet.png é muito largo, o WebP não o suporta, use sempre PNG

if (pngFile === 'star-working-spritesheet.png') {

return '.png';

}

// Se a configuração do layout forçar PNG, use .png

if (LAYOUT.forcePng && LAYOUT.forcePng[pngFile.replace(/\.(png|webp)$/, '')]) {
return '.png';

}

return supportsWebP ? '.webp' : '.png';

}

const config = {

type: Phaser.AUTO,

width: LAYOUT.game.width,

height: LAYOUT.game.height,

parent: 'game-container',

pixelArt: true,

physics: { default: 'arcade', arcade: { gravity: { y: 0 }, debug: false } },

scene: { preload: preload, create: create, update: update }
};

let totalAssets = 0;

let loadedAssets = 0;

let loadingProgressBar, loadingProgressContainer, loadingOverlay, loadingText;

// Funções relacionadas ao Memo
async function loadMemo() {

const memoDate = document.getElementById('memo-date');

const memoContent = document.getElementById('memo-content');

try { const response = await fetch('/yesterday-memo?t=' + Date.now(), { cache: 'no-store' });

const data = await response.json();

if (data.success && data.memo) {
memoDate.textContent = data.date || '';

memoContent.innerHTML = data.memo.replace(/\n/g, '<br>');

} else {
memoContent.innerHTML = '<div id="memo-placeholder">Diário de ontem não encontrado</div>';

}

} catch (e) {
console.error('Falha ao carregar o memo:', e);

memoContent.innerHTML = '<div id="memo-placeholder">Falha ao carregar</div>';

}

// Atualizar progresso de carregamento

function updateLoadingProgress() {

loadedAssets++;

const percent = Math.min(100, Math.round((loadedAssets / totalAssets) * 100));

if (loadingProgressBar) {

loadingProgressBar.style.width = percent + '%';

}

if (loadingText) {

loadingText.textContent = `${t('loadingOffice')} ${percent}%`;

}

}

// Ocultar tela de carregamento

function hideLoadingOverlay() {

setTimeout(() => {

if (loadingOverlay) {

loadingOverlay.style.transition = 'opacity 0.5s ease';

loadingOverlay.style.opacity = '0';

setTimeout(() => {

loadingOverlay.style.display = 'none';

}, 500);

}
}, 300);

}
const STATES = {
idle: { name: t('stateLabelIdle'), area: 'breakroom' },
writing: { name: t('stateLabelWriting'), area: 'writing' },
researching: { name: t('stateLabelResearching'), area: 'researching' },
executing: { name: t('stateLabelExecuting'), area: 'writing' },
syncing: { name: t('stateLabelSyncing'), area: 'syncing' },
error: { name: t('stateLabelError'), area: 'error' }
};

const BUBBLE_TEXTS = {
    zh: {
        idle: ['Aguardando comando: Ouvidos atentos', '我在这儿，随时可以开工', '先把桌面收拾干净再说', '呼——给大脑放个风', '今天也要优雅地高效', '等待，是为了更准确的一击', '咖啡还热，灵感也还在', '我在后台给你加 Buff', '状态：静心 / 充电', '小猫说：慢一点也没关系'],
        writing: ['进入专注模式：勿扰', '先把关键路径跑通', '我来把复杂变简单', '把 bug 关进笼子里', '写到一半，先保存', '把每一步都做成可回滚', '今天的进度，明天的底气', '先收敛，再发散', '让系统变得更可解释', '稳住，我们能赢'],
        researching: ['我在挖证据链', '让我把信息熬成结论', '找到了：关键在这里', '先把变量控制住', '我在查：它为什么会这样', '把直觉写成验证', '先定位，再优化', '别急，先画因果图'],
        executing: ['执行中：不要眨眼', '把任务切成小块逐个击破', '开始跑 pipeline', '一键推进：走你', '让结果自己说话', '先做最小可行，再做最美版本'],
        syncing: ['同步中：把今天锁进云里', '备份不是仪式，是安全感', '写入中…别断电', '把变更交给时间戳', '云端对齐：咔哒', '同步完成前先别乱动', '把未来的自己从灾难里救出来', '多一份备份，少一份后悔'],
        error: ['警报响了：先别慌', '我闻到 bug 的味道了', '先复现，再谈修复', '把日志给我，我会说人话', '错误不是敌人，是线索', '把影响面圈起来', '先止血，再手术', '我在：马上定位根因', '别怕，这种我见多了', '报警中：让问题自己现形'],
        cat: ['喵~', '咕噜咕噜…', '尾巴摇一摇', '晒太阳最开心', '有人来看我啦', '我是这个办公室的吉祥物', '伸个懒腰', '今日の缶詰、準備できた？', '呼噜呼噜', '这个位置视野最好']
    },
    pt_BR: {
        idle: [
            'Em espera: Orelhas atentas.',
            'Estou aqui, pronta para começar a qualquer momento.',
            'Primeiro, vamos arrumar a mesa.',
            'Ufa—dando uma pausa para o cérebro.',
            'Eficiente e elegante, como sempre.',
            'Esperando por um movimento mais preciso.',
            'O café está quente, as ideias também.',
            'Dando um buff discreto nos bastidores.',
            'Status: Calma / Carregando.',
            'O gatinho diz: sem pressa, tudo bem.'
        ],
        writing: [
            'Modo foco ativado: não perturbe.',
            'Primeiro, vamos resolver o caminho crítico.',
            'Vou simplificar o complexo.',
            'Colocando os bugs na jaula.',
            'Salvando no meio da escrita.',
            'Cada passo deve ser reversível.',
            'O progresso de hoje é a confiança de amanhã.',
            'Primeiro convergir, depois divergir.',
            'Tornando o sistema mais explicável.',
            'Mantenha a calma, podemos vencer.'
        ],
        researching: [
            'Estou cavando a cadeia de evidências.',
            'Deixe-me transformar informações em conclusões.',
            'Encontrei: a chave está aqui.',
            'Primeiro, controle as variáveis.',
            'Estou investigando: por que isso acontece?',
            'Transforme a intuição em verificação.',
            'Primeiro localizar, depois otimizar.',
            'Sem pressa — primeiro, desenhe o mapa de causalidade.'
        ],
        executing: [
            'Executando — não pisque.',
            'Divida as tarefas, vença uma por uma.',
            'O pipeline está rodando.',
            'Um clique para avançar: vamos lá!',
            'Deixe os resultados falarem por si.',
            'Construa o MVP primeiro, depois a beleza.'
        ],
        syncing: [
            'Sincronizando: salvando o dia na nuvem.',
            'Backup é segurança, não cerimônia.',
            'Gravando... não corte a energia.',
            'Entregando as alterações aos timestamps.',
            'Alinhamento na nuvem: clique.',
            'Não mexa antes que a sincronização termine.',
            'Salvando o futuro de desastres.',
            'Mais um backup, menos um arrependimento.'
        ],
        error: [
            'Alarme ativado — mantenha a calma.',
            'Estou sentindo um cheiro de bug.',
            'Primeiro reproduzir, depois corrigir.',
            'Me dê os logs; eu traduzo.',
            'Erros são pistas, não inimigos.',
            'Circule a área de impacto primeiro.',
            'Estancar o sangramento, depois a cirurgia.',
            'Estou nisso: rastreando a causa raiz agora.',
            'Não se preocupe, já vi isso muitas vezes.',
            'Modo de alerta: deixe o problema se revelar.'
        ],
        cat: [
            'Miau~',
            'Ronrom…',
            'Abanando o rabo.',
            'Tomar sol é o melhor.',
            'Alguém veio me ver!',
            'Sou o mascote do escritório.',
            'Grande espreguiçada~',
            'O lanche de hoje está pronto?',
            'Ronrom ronrom…',
            'O melhor lugar para a vista.'
        ]
    },
    en: {
        idle: ['On standby: ears up.', 'I’m here, ready to roll.', 'Let’s tidy the desk first.', 'Taking a quick brain breeze.', 'Efficient and elegant, as always.', 'Waiting for a more precise strike.', 'Coffee is warm, ideas too.', 'Giving you a quiet backstage buff.', 'Status: calm / charging.', 'Cat says: no rush, we’re good.'],
        writing: ['Focus mode on: do not disturb.', 'Let’s clear the critical path first.', 'I’ll make the complex simple.', 'Putting bugs in a cage.', 'Save first, then continue.', 'Every step should be rollback-safe.', 'Today’s progress is tomorrow’s confidence.', 'Converge first, then diverge.', 'Making the system more explainable.', 'Steady—this is winnable.'],
        researching: ['Digging the evidence chain.', 'Let me boil info into conclusions.', 'Found it: key clue here.', 'Control variables first.', 'Checking why this happens.', 'Turn intuition into verification.', 'Locate first, optimize next.', 'No rush—draw the causality map first.'],
        executing: ['Executing—don’t blink.', 'Split tasks, conquer one by one.', 'Pipeline is running.', 'One-click push: go go.', 'Let the results speak.', 'Build MVP first, then craft beauty.'],
        syncing: ['Syncing: lock today into the cloud.', 'Backup is safety, not ceremony.', 'Writing… don’t cut power.', 'Handing changes to timestamps.', 'Cloud alignment: click.', 'Don’t shake it before sync finishes.', 'Saving future-us from disasters.', 'One more backup, one less regret.'],
        error: ['Alarm on—stay calm.', 'I can smell a bug.', 'Reproduce first, then fix.', 'Give me logs; I’ll translate.', 'Errors are clues, not enemies.', 'Circle the impact area first.', 'Stop the bleeding, then surgery.', 'On it: tracing root cause now.', 'Don’t worry, seen this many times.', 'Alert mode: make the issue reveal itself.'],
        cat: ['Meow~', 'Purr purr…', 'Tail wiggle activated.', 'Sunbathing is the best.', 'Someone came to see me!', 'I’m the office mascot.', 'Big stretch~', 'Is today’s snack ready yet?', 'Rrrrr purr…', 'Best view spot secured.']
    },
    ja: {
        idle: ['待機中：耳はピン。', 'ここにいるよ、いつでも開始OK。', 'まず机を整えよう。', 'ふー、頭に風を通す。', '今日も上品に高効率で。', '待つのは、より正確な一撃のため。', 'コーヒーも発想もまだ温かい。', '裏側でそっとバフ中。', '状態：静心 / 充電。', '猫より：ゆっくりでも大丈夫。'],
        writing: ['集中モード：お静かに。', 'まずはクリティカルパスを通す。', '複雑をシンプルにする。', 'バグはケージへ。', '途中でもまず保存。', 'すべてをロールバック可能に。', '今日の進捗は明日の自信。', 'まず収束、次に発散。', 'システムをより説明可能に。', '落ち着いて、勝てる。'],
        researching: ['証拠チェーンを掘っています。', '情報を結論まで煮詰めます。', '見つけた：鍵はここ。', 'まず変数を制御。', 'なぜこうなるか調査中。', '直感を検証へ。', '先に特定、次に最適化。', '急がず因果マップから。'],
        executing: ['実行中：まばたき厳禁。', 'タスクを分割して各個撃破。', 'パイプライン起動。', 'ワンクリック前進：いくぞ。', '結果に語らせる。', 'まず最小実用、次に美しさ。'],
        syncing: ['同期中：今日をクラウドに封印。', 'バックアップは儀式じゃなく安心。', '書き込み中…電源オフ厳禁。', '変更はタイムスタンプへ。', 'クラウド整列：カチッ。', '同期完了まで触らないで。', '未来の自分を災害から救う。', 'バックアップ一つ、後悔一つ減る。'],
        error: ['警報：まず落ち着いて。', 'バグの気配を感じる。', '再現してから修正へ。', 'ログをください、人語にします。', 'エラーは敵ではなく手がかり。', 'まず影響範囲を囲う。', '止血してから手術。', '今すぐ根因を追跡中。', '大丈夫、よくある案件。', '警戒モード：問題を可視化する。'],
        cat: ['ニャー', 'ゴロゴロ…', 'しっぽフリフリ。', 'ひなたぼっこ最高。', '見に来てくれた！', 'このオフィスのマスコットです。', 'ぐーっと伸び。', '今日のおやつ、準備できた？', 'ゴロゴロ。', 'ここ、いちばん見晴らしがいい。']
    }
}

let game, star, sofa, serverroom, areas = {}, currentState = 'idle', pendingDesiredState = null, statusText, lastFetch = 0, lastBlink = 0, lastBubble = 0, targetX = 660, targetY = 170, bubble = null, typewriterText = '', typewriterTarget = '', typewriterIndex = 0, lastTypewriter = 0, syncAnimSprite = null, catBubble = null;

let isMoving = false;

let waypoints = [];

let lastWanderAt = 0;

let coordsOverlay, coordsDisplay, coordsToggle;

let showCoords = false;

const FETCH_INTERVAL = 2000;

const BLINK_INTERVAL = 2500;

const BUBBLE_INTERVAL = 8000;
const CAT_BUBBLE_INTERVAL = 18000;
let lastCatBubble = 0;

const TYPEWRITER_DELAY = 50;

let agents
