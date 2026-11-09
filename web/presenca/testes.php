<?php
// Testes da presença (Task 4 da fase 3). Script puro, sai com código 1 na primeira falha.
// Rodar sem gravar nada no servidor:
//   (cat presenca_lib.php; tail -n +2 testes.php) | ssh hostinger "php -d zend.assertions=1 -d assert.exception=1"
// Ou com a lib ao lado: php -d zend.assertions=1 -d assert.exception=1 testes.php
if (!function_exists('presenca_token_ok')) {
    require __DIR__ . '/presenca_lib.php';
}

$falhas = 0;
function confere(bool $ok, string $nome): void {
    global $falhas;
    if (!$ok) {
        fwrite(STDERR, "FALHOU: $nome\n");
        exit(1);
    }
    echo "ok: $nome\n";
}

$corpo = [
    'uuid' => '0F3A6C2B-1D4E-4F5A-8B9C-0D1E2F3A4B5C',
    'porta' => 47989,
    'ipv6' => ['2804:1b3:a541:2862::5'],
    'tailscale' => ['100.99.120.91'],
    'versao' => '2026.1107',
];

confere(presenca_token_ok('Bearer abc', hash('sha256', 'abc')) === true, 'token certo');
confere(presenca_token_ok('Bearer abd', hash('sha256', 'abc')) === false, 'token errado');
confere(presenca_token_ok(null, hash('sha256', 'abc')) === false, 'sem cabeçalho');
confere(presenca_token_ok('abc', hash('sha256', 'abc')) === false, 'sem Bearer');
confere(presenca_token_ok('Bearer ', hash('sha256', '')) === false, 'token vazio');

confere(presenca_validar($corpo) === null, 'aceita o corpo do contrato');
confere(presenca_validar(array_merge($corpo, ['uuid' => 'x'])) !== null, 'recusa uuid x');
confere(presenca_validar(array_merge($corpo, ['ipv6' => array_fill(0, 9, '2804::1')])) !== null, 'recusa 9 IPv6');
confere(presenca_validar(array_merge($corpo, ['ipv6' => ['1.2.3.4']])) !== null, 'recusa IPv6 1.2.3.4');
confere(presenca_validar(array_merge($corpo, ['tailscale' => ['192.168.0.1']])) !== null, 'recusa tailscale 192.168.0.1');
confere(presenca_validar(array_merge($corpo, ['porta' => 0])) !== null, 'recusa porta 0');
confere(presenca_validar(array_merge($corpo, ['ipv6' => '2804::1'])) !== null, 'recusa ipv6 que não é lista');
confere(presenca_validar(array_merge($corpo, ['extra' => 1])) !== null, 'recusa chave desconhecida');

$r = presenca_registro($corpo, '177.10.20.30', 1700000000);
confere(($r['ipv4'] ?? null) === '177.10.20.30', 'registro com ipv4');
confere($r['atualizado'] === 1700000000, 'registro com atualizado');
confere($r['uuid'] === $corpo['uuid'] && $r['tailscale'] === $corpo['tailscale'], 'registro mantém o corpo');
$r6 = presenca_registro($corpo, '2804:1b3::9', 1700000000);
confere(!array_key_exists('ipv4', $r6), 'remoteAddr IPv6 não vira ipv4');

echo "todos os testes passaram\n";
