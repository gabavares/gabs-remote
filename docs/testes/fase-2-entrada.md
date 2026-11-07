# Fase 2: matriz de entrada (S Pen e teclado)

Testado no Galaxy Tab S10+ com o app Gabs Remote (release), perfil **Nativo 100% a 120 fps**, em casa. Marque ✓ (funciona), ✗ (não funciona: descreva o que acontece) ou — (não se aplica). A Task 11 copia o resultado para `fase-2-checklist.md`.

Data do teste: 07/11/2026 (Gab, tablet no Nativo 100% a 120 fps). Teclado Bluetooth não testado.

## S Pen

| Item | Photoshop | Illustrator | Figma (navegador) | Windows Ink (área de esboço) |
|---|---|---|---|---|
| Pressão (traço fino → grosso) | ✓ | ✓ | ✓ | ✓ |
| Inclinação (pincel que responde à inclinação) | ✓ | ✓ | ✓ | ✓ |
| Hover (cursor do pincel acompanha sem encostar) | ✓ | ✓ | ✓ | ✓ |
| Botão lateral (clique direito ou função configurada) | ✓ | ✓ | ✓ | ✓ |
| Rejeição de palma: mão apoiada **antes** da caneta, depois desenhar | ✓ | ✓ | ✓ | ✓ |
| Rejeição de palma: caneta perto, depois apoiar a mão | ✓ | ✓ | ✓ | ✓ |

## Teclado

| Atalho | Book Cover | Teclado Bluetooth | Observação |
|---|---|---|---|
| Ctrl+C / Ctrl+V / Ctrl+Z | ✓ | — | |
| Ctrl+Shift+Esc | ✓ | — | |
| Alt+Tab (segurando Alt e passando com Tab) | ✓ | — | |
| Alt+F4 | ✓ | — | |
| Win | ✓ | — | |
| Win+D | ✓ | — | |
| Win+Shift+S | ✓ | — | |
| F1–F12 | ✓ | — | |
| Esc | ✓ | — | |
| Setas | ✓ | — | |
| Print Screen | ✓ | — | |
| Português (ABNT2, opção "Teclado do Windows durante a sessão"): ç, acentos (´ ` ~ ^ ¨), / ? ; : | ✓ (07/11) | — | O host pede o layout de novo por 10 s, porque a troca de tela tira o foco da janela |
| Ao desconectar, o teclado do PC volta ao inglês | ✓ (07/11) | — | |
| Trackpad do Book Cover: cursor na direção do dedo (opção "Rotação do trackpad do teclado", padrão 90°) | ✓ (07/11) | — | |
| Trackpad do Book Cover: rolagem com dois dedos, toque = clique, toque de dois dedos = clique direito | ✓ (07/11) | — | Gestos feitos pelo app (`TouchpadGestures`), porque o trackpad capturado chega sem eles |
| Trackpad do Book Cover: arrastar janela segurando o botão físico | ✓ (07/11) | — | |
| Teclado em português depois da tela de login e do Win+L | ✓ (07/11) | — | Na própria tela de login fica o layout do Windows (limitação aceita) |

Se o One UI não deixar o app capturar Alt+Tab ou Win, o menu da sessão (toque de três dedos) tem os itens **Alt+Tab** e **Win**.

## Modos de toque (Task 7)

| Item | Resultado |
|---|---|
| Direto: arrastar uma janela com o dedo | ✓ |
| Direto: pinça no navegador (zoom do Windows) | ✓ |
| Direto: puxar a barra de notificações do Android no meio de um arraste (o toque não fica preso no Windows) | ✓ |
| Trackpad: cursor relativo, rolagem com dois dedos, toque de dois dedos = clique direito | ✓ |
| Só caneta: desenhar com a mão apoiada, sem traço de palma | ✓ |
| Só caneta: pinça amplia só no tablet; dois dedos movem a imagem ampliada | ✓ |
| Só caneta: toque de dois dedos = clique direito; toque duplo de dois dedos volta o zoom | ✓ |
| Três dedos abrem o menu da sessão; trocar o modo pelo menu vale na hora | ✓ (07/11) |

## Limitações aceitas pelo Gab

- Na tela de login do Windows o teclado fica no layout do próprio Windows; o português vale a partir da área de trabalho.
- Teclado Bluetooth não testado (o Gab usa o Book Cover).
