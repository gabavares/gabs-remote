<?php
// Gabs Remote: funções da página de presença (fase 3, decisão 0005).
// Sem efeitos colaterais: o presenca.php cuida de ler e gravar arquivos.

const PRESENCA_MAX_CORPO = 4096;
const PRESENCA_MAX_IPV6 = 8;
const PRESENCA_CHAVES = ['uuid', 'porta', 'ipv6', 'tailscale', 'versao'];

function presenca_token_ok(?string $authorization, string $hashSalvo): bool {
    if ($authorization === null || strncmp($authorization, 'Bearer ', 7) !== 0) {
        return false;
    }
    $token = trim(substr($authorization, 7));
    if ($token === '' || $hashSalvo === '') {
        return false;
    }
    return hash_equals(strtolower(trim($hashSalvo)), hash('sha256', $token));
}

// O LiteSpeed da Hostinger pode não repassar o Authorization em $_SERVER; getallheaders() cobre esse caso.
function presenca_authorization(array $server, array $headers): ?string {
    foreach (['HTTP_AUTHORIZATION', 'REDIRECT_HTTP_AUTHORIZATION'] as $chave) {
        if (isset($server[$chave]) && $server[$chave] !== '') {
            return (string) $server[$chave];
        }
    }
    foreach ($headers as $nome => $valor) {
        if (strcasecmp((string) $nome, 'Authorization') === 0 && $valor !== '') {
            return (string) $valor;
        }
    }
    return null;
}

function presenca_uuid_ok($uuid): bool {
    return is_string($uuid) && preg_match('/^[0-9A-Fa-f-]{36}$/', $uuid) === 1;
}

function presenca_tailscale_ok($ip): bool {
    if (!is_string($ip) || filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) === false) {
        return false;
    }
    $n = ip2long($ip);
    return ($n & 0xFFC00000) === (ip2long('100.64.0.0') & 0xFFC00000);
}

// Devolve a mensagem de erro, ou null se o corpo estiver certo.
function presenca_validar(array $corpo): ?string {
    foreach (array_keys($corpo) as $chave) {
        if (!in_array($chave, PRESENCA_CHAVES, true)) {
            return "chave desconhecida: $chave";
        }
    }
    if (!presenca_uuid_ok($corpo['uuid'] ?? null)) {
        return 'uuid inválido';
    }
    $porta = $corpo['porta'] ?? null;
    if (!is_int($porta) || $porta < 1 || $porta > 65535) {
        return 'porta inválida';
    }
    $ipv6 = $corpo['ipv6'] ?? [];
    if (!is_array($ipv6) || !array_is_list_compat($ipv6) || count($ipv6) > PRESENCA_MAX_IPV6) {
        return 'ipv6 inválido';
    }
    foreach ($ipv6 as $ip) {
        if (!is_string($ip) || filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV6) === false) {
            return 'ipv6 inválido';
        }
    }
    $tailscale = $corpo['tailscale'] ?? [];
    if (!is_array($tailscale) || !array_is_list_compat($tailscale) || count($tailscale) > PRESENCA_MAX_IPV6) {
        return 'tailscale inválido';
    }
    foreach ($tailscale as $ip) {
        if (!presenca_tailscale_ok($ip)) {
            return 'tailscale inválido';
        }
    }
    $versao = $corpo['versao'] ?? '';
    if (!is_string($versao) || strlen($versao) > 64) {
        return 'versao inválida';
    }
    return null;
}

function array_is_list_compat(array $a): bool {
    return $a === [] || array_keys($a) === range(0, count($a) - 1);
}

function presenca_registro(array $corpo, string $remoteAddr, int $agora): array {
    $registro = [
        'uuid' => $corpo['uuid'],
        'porta' => $corpo['porta'],
        'ipv6' => array_values($corpo['ipv6'] ?? []),
        'tailscale' => array_values($corpo['tailscale'] ?? []),
        'versao' => $corpo['versao'] ?? '',
    ];
    if (filter_var($remoteAddr, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) !== false) {
        $registro['ipv4'] = $remoteAddr;
    }
    $registro['atualizado'] = $agora;
    return $registro;
}
