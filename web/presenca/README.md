# Presença do PC na hospedagem

Página PHP que guarda onde o PC está. O host do Gabs Remote atualiza enquanto o PC está ligado; o app lê, inclusive com o PC desligado, para mandar o pacote mágico ao IPv4 público de casa (decisão 0005, `docs/rede-fora.md`).

## Contrato
- `POST https://gabtavares.com/gabs-remote/presenca.php`, cabeçalho `Authorization: Bearer <token>`, corpo JSON `{"uuid": "<uniqueid do host>", "porta": 47989, "ipv6": [...], "tailscale": [...], "versao": "<versão>"}` (até 4096 bytes). O servidor acrescenta `ipv4` (o `REMOTE_ADDR`, se for IPv4) e `atualizado` (Unix, segundos), grava e responde `200` com o registro.
- `GET https://gabtavares.com/gabs-remote/presenca.php?uuid=<uuid>`, mesmo cabeçalho: `200` com o registro, `404` se não houver.
- Erros: `401` token errado ou ausente; `413` corpo grande; `400` JSON ou campo inválido (uuid fora de `^[0-9A-Fa-f-]{36}$`, mais de 8 IPv6, IPv6 inválido, tailscale fora de `100.64.0.0/10`, porta fora de 1–65535, chave desconhecida); `503` sem `~/gabs-remote/token.sha256`.

## Arquivos no servidor
- Na pasta do subdomínio: só `presenca.php` e `presenca_lib.php`.
- Fora do `public_html`: `~/gabs-remote/token.sha256` (só o SHA-256 do token, em hexadecimal) e `~/gabs-remote/presenca/<uuid>.json`. O `presenca.php` acha a pasta subindo a partir de onde está.

## Testes
Sem gravar nada no servidor:

```bash
(cat presenca_lib.php; tail -n +2 testes.php) | ssh hostinger "php -d display_errors=stderr"
```

## Publicar (com o ok do Gab)
1. No hPanel, criar o subdomínio `remote.gabtavares.com` **sem CDN** (o `REMOTE_ADDR` tem de ser o IP real) e com SSL.
2. Copiar `presenca.php` e `presenca_lib.php` para a pasta do subdomínio (`scp`).
3. Gerar o token no PC, guardar no gerenciador de senhas ("Gabs Remote — presença") e gravar só o SHA-256 em `~/gabs-remote/token.sha256` (permissão 600).
