# Screenshots de Evidência

Capturas de tela obrigatórias a adicionar após a execução real dos workflows:

| Arquivo | O que capturar |
|---------|----------------|
| `plan-pr-comment.png` | Comentário do bot no PR com o output do `terraform plan` |
| `apply-success.png` | Log do `terraform-apply.yml` com apply concluído e outputs visíveis |
| `cd-pipeline-green.png` | Visão geral do pipeline CD com os 4 jobs verdes (lint, test, build-push, deploy) |
| `health-check-pass.png` | Trecho do log do job `deploy` mostrando `✅ Health check PASSOU — HTTP 200` |

## Como capturar

1. Execute os workflows conforme o README principal
2. Acesse **GitHub → Actions** para os logs de CD e Apply
3. Acesse o PR aberto para o comentário do Plan
4. Use `Win + Shift + S` (Windows) para recorte de tela
5. Salve as imagens nesta pasta com os nomes exatos acima
