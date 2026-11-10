# EXPLICACAO.md — Blue/Green Deployment na AWS

## 1. O Requisito do CTO

> *"Zero downtime em qualquer deploy e capacidade de reverter para a versão anterior em segundos."*

Essa frase tem dois critérios técnicos precisos:

| Critério | O que significa na prática |
|----------|---------------------------|
| **Zero downtime** | Nenhuma requisição deve receber erro ou timeout durante a troca de versão |
| **Reversão em segundos** | O RTO (Recovery Time Objective) do rollback deve ser menor que um intervalo de health check do ALB — idealmente abaixo de 10 segundos |

Blue/Green atende os dois de forma direta, sem workarounds. Os demais modelos de deploy precisam de compensações para atingir o mesmo resultado.

---

## 2. Comparação com Outras Estratégias

### 2.1 Deploy In-Place (Rolling Update simples)

A abordagem mais comum em ambientes sem orquestração: parar o container/processo antigo, subir o novo na mesma instância.

```
Instância A:  [v1 rodando] → [parado] → [v2 iniciando] → [v2 rodando]
                                 ↑
                           downtime aqui
                     (segundos a minutos, dependendo do boot time)
```

**Problema direto com o requisito:**
- Entre parar v1 e v2 responder ao primeiro health check, há uma janela de indisponibilidade.
- Se v2 falhar na inicialização, o rollback exige reinstalar v1 — processo lento e manual.
- **Não atende zero downtime.**

---

### 2.2 Rolling Deploy (múltiplas instâncias, substituição gradual)

Cada instância é atualizada uma a uma. O load balancer remove a instância do pool antes de atualizar.

```
t=0   [v1] [v1] [v1] [v1]   → 100% tráfego em v1
t=1   [v2] [v1] [v1] [v1]   → v1 e v2 coexistem, 25% em v2
t=2   [v2] [v2] [v1] [v1]   → 50% em v2
t=3   [v2] [v2] [v2] [v1]   → 75% em v2
t=4   [v2] [v2] [v2] [v2]   → 100% em v2
```

**Problema direto com o requisito:**
- Zero downtime: quase atendido, mas usuários em mid-session podem alternar entre v1 e v2 na mesma sessão se não houver stickiness, causando comportamento imprevisível.
- Rollback: exige reverter instância por instância novamente — pode levar vários minutos dependendo do número de instâncias e do boot time.
- Durante o rollback, v1 e v2 coexistem com tráfego ativo. Se a migração de banco de dados não for retrocompatível, isso cria inconsistência de dados.
- **Atende parcialmente, mas o rollback não é "em segundos".**

---

### 2.3 Canary Deploy

Uma fração pequena do tráfego (ex: 5%) vai para a nova versão. O percentual sobe gradualmente conforme as métricas se mantêm saudáveis.

```
t=0   Blue: 100%  |  Green:  0%
t=1   Blue:  95%  |  Green:  5%   ← monitorar
t=2   Blue:  80%  |  Green: 20%   ← monitorar
t=3   Blue:  50%  |  Green: 50%   ← monitorar
t=4   Blue:   0%  |  Green: 100%
```

**Problema direto com o requisito:**
- Zero downtime: sim, atende.
- Rollback: sim, pode ser feito devolvendo 100% ao Blue — rápido se a infraestrutura já suportar weighted routing (ex: ALB weighted target groups ou AWS Global Accelerator).
- Complexidade operacional: exige instrumentação de métricas fina para definir os thresholds de promoção, análise automatizada ou humana a cada step.
- **Atende os critérios do CTO, mas acrescenta complexidade que não é necessária para o contexto atual.** É a evolução natural de Blue/Green quando o volume de tráfego justificar a granularidade.

---

### 2.4 Blue/Green — Por que é a escolha certa aqui

```
t=0   [Blue v1 rodando]  [Green v2 sendo preparado — sem tráfego]
t=1   [Blue v1 rodando]  [Green v2 healthy, testado, pronto]
t=2   ALB Listener aponta para Green  ← switch atômico
t=3   [Blue v1 standby] [Green v2 recebe 100% do tráfego]
```

O switch ocorre em uma única operação de API (`modify-listener`). Do ponto de vista do usuário final, a requisição que estava em andamento termina no Blue; a próxima já cai no Green. Não há janela onde nenhum servidor responde.

| Critério do CTO | Blue/Green | In-Place | Rolling | Canary |
|----------------|:----------:|:--------:|:-------:|:------:|
| Zero downtime durante deploy | ✅ | ❌ | ⚠️ | ✅ |
| Rollback em segundos | ✅ | ❌ | ❌ | ✅ |
| Simplicidade operacional | ✅ | ✅ | ⚠️ | ❌ |
| Versões v1/v2 isoladas | ✅ | ❌ | ❌ | ⚠️ |
| Custo de infraestrutura | ⚠️ 2× | ✅ 1× | ✅ 1× | ⚠️ 2× |

> ⚠️ = atende parcialmente ou com ressalvas. ✅ = atende. ❌ = não atende.

O único trade-off real é o custo duplo de infraestrutura: Blue e Green precisam rodar simultaneamente. No contexto do AWS Learner Lab com instâncias `t2.micro` (dentro do free tier), esse custo é zero. Em produção, o custo é justificado pela eliminação de qualquer risco de downtime.

---

## 3. Fluxo de Tráfego no ALB Configurado

### Visão geral

```
Internet (0.0.0.0/0)
        │
        │ HTTP :80
        ▼
┌─────────────────────────────────────────────┐
│          blue-green-app-alb                  │
│          (aws_lb.main)                       │
│                                             │
│  Security Group: alb-sg                     │
│    inbound  → 80  de 0.0.0.0/0              │
│    inbound  → 443 de 0.0.0.0/0              │
│    outbound → all                            │
└──────────────────┬──────────────────────────┘
                   │
                   │ aws_lb_listener.main
                   │ port=80, protocol=HTTP
                   │ default_action: forward → [TG ativo]
                   │
        ┌──────────┴──────────┐
        │                     │
        ▼                     ▼
┌──────────────────┐  ┌──────────────────┐
│  blue-green-app  │  │  blue-green-app  │
│    -blue-tg      │  │    -green-tg     │
│                  │  │                  │
│  port: 3000      │  │  port: 3000      │
│  protocol: HTTP  │  │  protocol: HTTP  │
│  target: instance│  │  target: instance│
│                  │  │                  │
│  health_check:   │  │  health_check:   │
│   path=/         │  │   path=/         │
│   interval=30s   │  │   interval=30s   │
│   timeout=5s     │  │   timeout=5s     │
│   healthy=2 OK   │  │   healthy=2 OK   │
│   unhealthy=3 ✗  │  │   unhealthy=3 ✗  │
│   matcher=200    │  │   matcher=200    │
│                  │  │                  │
│  stickiness:     │  │  stickiness:     │
│   lb_cookie 24h  │  │   lb_cookie 24h  │
└────────┬─────────┘  └────────┬─────────┘
         │                     │
         ▼                     ▼
  ┌─────────────┐       ┌─────────────┐
  │  EC2 Blue   │       │  EC2 Green  │
  │  :3000      │       │  :3000      │
  │             │       │             │
  │  SG: instance-sg    │  SG: instance-sg
  │  inbound: 3000      │  inbound: 3000
  │  only from alb-sg   │  only from alb-sg
  └─────────────┘       └─────────────┘
```

### Passo a passo de uma requisição

**1. Requisição chega no ALB**

O cliente faz `GET http://blue-green-app-alb-xxxx.us-east-1.elb.amazonaws.com/`. O Security Group `alb-sg` permite a entrada na porta 80 de qualquer origem (`0.0.0.0/0`). O ALB recebe a conexão e consulta o Listener.

**2. O Listener decide o destino**

O recurso `aws_lb_listener.main` tem uma única regra: `default_action = forward → TG ativo`. O TG ativo é definido pela `TargetGroupArn` configurada no momento. Por padrão no Terraform, aponta para o Blue TG. Após um deploy bem-sucedido, aponta para o Green TG.

```hcl
# alb.tf — a única linha que muda durante o Blue/Green switch
default_action {
  type             = "forward"
  target_group_arn = aws_lb_target_group.blue.arn  # ← ou green após deploy
}
```

**3. O Target Group seleciona a instância**

O TG ativo mantém uma lista de targets registrados e seus estados de health. Apenas instâncias com estado `healthy` recebem tráfego. Com `stickiness` habilitado, o ALB injeta um cookie `AWSALB` na resposta; requisições subsequentes do mesmo cliente são roteadas para a mesma instância.

**4. A instância EC2 responde**

O Security Group `instance-sg` só permite tráfego TCP na porta 3000 vindo do `alb-sg`. Isso significa que nenhum IP externo consegue alcançar a instância diretamente — toda requisição obrigatoriamente passa pelo ALB. A instância processa e devolve a resposta, que o ALB repassa ao cliente.

**5. Health checks em paralelo**

Independente do tráfego de usuários, o ALB envia requisições `GET /` a cada 30 segundos para cada instância registrada nos dois TGs. Se uma instância falhar 3 vezes seguidas (timeout de 5s cada), é marcada como `unhealthy` e removida do pool de roteamento — sem intervenção manual.

### O switch Blue → Green em detalhe

```
ANTES do deploy
  Listener.DefaultAction.TargetGroupArn = arn:.../blue-tg

DURANTE o deploy (Green sendo preparado)
  Listener.DefaultAction.TargetGroupArn = arn:.../blue-tg  ← inalterado
  Green TG: health checks rodando, instância ainda sem tráfego real

APÓS health checks passarem
  aws elbv2 modify-listener \
    --listener-arn $LISTENER_ARN \
    --default-actions Type=forward,TargetGroupArn=$GREEN_TG_ARN

  Listener.DefaultAction.TargetGroupArn = arn:.../green-tg  ← atualizado
  Propagação pelo fleet de nós do ALB: < 5 segundos

ROLLBACK (se necessário)
  aws elbv2 modify-listener \
    --listener-arn $LISTENER_ARN \
    --default-actions Type=forward,TargetGroupArn=$BLUE_TG_ARN

  Listener.DefaultAction.TargetGroupArn = arn:.../blue-tg  ← revertido
```

A operação `modify-listener` é uma chamada de API síncrona à AWS. O próprio ALB propaga a mudança internamente para todos os seus nós em milissegundos. Do ponto de vista de quem mede, o switch é atômico.

---

## 4. Por que cada decisão de configuração existe

### `enable_cross_zone_load_balancing = true`

Sem isso, o ALB distribui tráfego apenas entre instâncias na mesma Zona de Disponibilidade do nó ALB que recebeu a requisição. Com isso habilitado, todas as instâncias saudáveis em qualquer AZ são candidatas, independente de onde a requisição entrou. Garante distribuição uniforme mesmo com instâncias em AZs diferentes.

### `enable_http2 = true`

Permite que clientes modernos usem HTTP/2, reduzindo latência por multiplexação de requisições em uma única conexão TCP. Sem impacto no comportamento do Blue/Green.

### `lifecycle { create_before_destroy = true }` nos Target Groups

Se o Terraform precisar recriar um TG (ex: mudança de nome), ele cria o novo antes de destruir o antigo. Sem isso, o destroy do TG antigo com instâncias registradas tiraria o tráfego do ar antes do novo estar pronto.

### `stickiness` com `lb_cookie` de 24 horas

O ALB injeta o cookie `AWSALB` com TTL de 24h. Enquanto o cookie for válido, o mesmo cliente sempre cai na mesma instância dentro do TG ativo. Isso importa se a aplicação armazena estado local (sessão em memória, upload parcial, etc.). Pode ser desabilitado com `stickiness_enabled = false` se a aplicação for completamente stateless.

### Security Group da EC2 referenciando o SG do ALB

```hcl
ingress {
  from_port       = var.instance_port       # 3000
  security_groups = [aws_security_group.alb.id]  # não um CIDR
}
```

Referenciar o SG do ALB em vez de um CIDR tem uma vantagem importante: se o ALB for recriado com um novo IP, a regra continua válida porque está atrelada à identidade do SG, não ao endereço. Além disso, qualquer recurso que ganhar o `alb-sg` automaticamente tem acesso às instâncias — útil se futuramente houver um segundo ALB ou um bastion que precise chamar a aplicação.

---

## 5. Resumo da Decisão

Blue/Green é escolhido porque:

1. O switch de tráfego é uma operação de API única e atômica no ALB — não há estado intermediário onde nenhum servidor responde.
2. Blue permanece ativo e saudável durante todo o processo, pronto para receber tráfego de volta em qualquer momento.
3. O rollback usa o mesmo mecanismo do deploy — um `modify-listener` — então o RTO é o mesmo do FTO (Forward Time Objective): abaixo de 10 segundos.
4. A complexidade operacional é baixa o suficiente para ser mantida por um time pequeno sem ferramentas adicionais além da AWS CLI e do Terraform.
5. A infraestrutura declarada em Terraform torna o ambiente reproduzível: Blue e Green são definidos identicamente, eliminando drift de configuração entre os dois ambientes.
