<?php
// Gabs Remote: página de presença (fase 3, decisão 0005).
// POST: o host informa onde está (o servidor acrescenta o IPv4 público e a hora).
// GET ?uuid=...: o app lê o último registro, inclusive com o PC desligado (WoL de fora).
// Dados fora do public_html, em ~/gabs-remote/ (token.sha256 e presenca/<uuid>.json).

require __DIR__ . '/presenca_lib.php';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

function responder(int $codigo, array $dados): void {
    http_response_code($codigo);
    echo json_encode($dados, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

// Sobe a partir desta pasta até achar ~/gabs-remote (sem caminho fixo de usuário).
function pasta_dados(): ?string {
    $dir = __DIR__;
    for ($i = 0; $i < 6; $i++) {
        $dir = dirname($dir);
        if (is_file($dir . '/gabs-remote/token.sha256')) {
            return $dir . '/gabs-remote';
        }
    }
    return null;
}

$dados = pasta_dados();
if ($dados === null) {
    responder(503, ['erro' => 'presença não configurada']);
}

$auth = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? null);
if (!presenca_token_ok($auth, (string) file_get_contents($dados . '/token.sha256'))) {
    responder(401, ['erro' => 'não autorizado']);
}

$pasta = $dados . '/presenca';
$metodo = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($metodo === 'GET') {
    $uuid = $_GET['uuid'] ?? '';
    if (!presenca_uuid_ok($uuid)) {
        responder(400, ['erro' => 'uuid inválido']);
    }
    $arquivo = $pasta . '/' . strtoupper($uuid) . '.json';
    if (!is_file($arquivo)) {
        responder(404, ['erro' => 'sem registro']);
    }
    $registro = json_decode((string) file_get_contents($arquivo), true);
    responder(200, is_array($registro) ? $registro : []);
}

if ($metodo !== 'POST') {
    responder(405, ['erro' => 'método não aceito']);
}

$bruto = file_get_contents('php://input', false, null, 0, PRESENCA_MAX_CORPO + 1);
if ($bruto === false || strlen($bruto) > PRESENCA_MAX_CORPO) {
    responder(413, ['erro' => 'corpo grande demais']);
}
$corpo = json_decode($bruto, true);
if (!is_array($corpo)) {
    responder(400, ['erro' => 'JSON inválido']);
}
$erro = presenca_validar($corpo);
if ($erro !== null) {
    responder(400, ['erro' => $erro]);
}

$registro = presenca_registro($corpo, (string) ($_SERVER['REMOTE_ADDR'] ?? ''), time());
if (!is_dir($pasta) && !mkdir($pasta, 0700, true)) {
    responder(500, ['erro' => 'sem pasta de dados']);
}
$arquivo = $pasta . '/' . strtoupper($registro['uuid']) . '.json';
$tmp = $arquivo . '.tmp';
if (file_put_contents($tmp, json_encode($registro, JSON_UNESCAPED_SLASHES)) === false || !rename($tmp, $arquivo)) {
    responder(500, ['erro' => 'não gravou']);
}
responder(200, $registro);
