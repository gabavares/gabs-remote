# Fase 2: checklist (rascunho)

Rascunho das verificações feitas no tablet. A Task 11 transforma este arquivo no checklist final, com os critérios da spec.

## Host como serviço (Task 4, 07/11/2026)

| Verificação | Resultado |
|---|---|
| Sem login, o tablet acha o PC e abre a sessão na tela de login do Windows | ✓ |
| Já logado, o prompt do UAC aparece no tablet e aceita toque | ✓ |
| `sc.exe qc GabsRemote`: `AUTO_START`, conta `LocalSystem` | ✓ |
| `sc.exe qfailure GabsRemote`: reiniciar após 5 s, 5 s e 30 s; zera em 86400 s | ✓ |
| `sunshine.exe` finalizado no Gerenciador de Tarefas volta sozinho em até 5 s | ✓ |

## Marca no app (Task 2, 07/11/2026)

| Verificação | Resultado |
|---|---|
| `aapt2 dump badging` do APK de release: `package: name='com.gabtavares.gabsremote'`, `application-label:'Gabs Remote'` | ✓ |
| Tablet sem o Moonlight (Debug); Gabs Remote com nome e ícone certos | ✓ |

## Sessão (pedidos do Gab, 07/11/2026)

| Verificação | Resultado |
|---|---|
| Alt+Tab ou Home no tablet: o PC continua com a tela virtual e o teclado; voltar reaproveita a tela (log: `reusing the virtual display`) | ✓ |
| Voltar ou Desconectar no menu: o PC volta aos monitores físicos | ✓ |
| Teclado pt-BR na sessão, depois do login e do Win+L; volta ao inglês internacional ao desconectar | ✓ |
