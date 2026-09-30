# Processo Spec-Driven — Reserva de Salas | SEU NOME (RA)

## 1. Como eu dividi o problema

O problema foi quebrado em partes funcionais independentes, cada uma com responsabilidade clara:

1. **Cadastrar sala** — receber nome e capacidade, validar e armazenar em memória
2. **Listar salas disponíveis** — retornar todas as salas com status de disponibilidade calculado em tempo real
3. **Fazer reserva** — validar campos, checar conflito de horário (double booking) e persistir
4. **Cancelar reserva** — localizar pelo ID e remover do array em memória
5. **Listar reservas de um funcionário** — filtrar o array global pelo `employeeId`
6. **Bloqueio de concorrência** — regra transversal aplicada na criação de reserva, usando lógica de intervalo semi-aberto `[start, end)` para detectar sobreposição

---

## 2. Requisitos (o quê)

### Requisitos gerados

- `POST /rooms` — cadastrar sala com `name` (string) e `capacity` (inteiro positivo)
- `GET /rooms` — listar salas com campo `available` calculado dinamicamente
- `POST /reservations` — criar reserva com `roomId`, `employeeId`, `startTime`, `endTime` (ISO 8601)
- `DELETE /reservations/:id` — cancelar reserva por ID
- `GET /reservations/employee/:employeeId` — histórico de reservas de um funcionário
- Bloqueio de double booking com `409 Conflict`
- Validação de todos os campos obrigatórios com `400 Bad Request`
- Dados armazenados apenas em memória (arrays)

### O que foi corrigido ou adicionado

- **Nomes de sala duplicados**: o enunciado não mencionava, mas foi adicionado um bloqueio de nome duplicado com `409 Conflict` — sem isso, seria possível criar duas salas com o mesmo nome, gerando confusão
- **Reservas no passado**: o enunciado não proibia, mas foi adicionada validação para impedir `startTime` anterior ao momento atual
- **`endTime` anterior a `startTime`**: validação óbvia mas não descrita explicitamente no enunciado; adicionada com `400 Bad Request`
- **Status `available` em tempo real**: o enunciado pedia "status de disponibilidade" mas não especificava como calcular — foi decidido comparar o horário atual com as reservas existentes, tornando o campo dinâmico

---

## 3. Design (como)

### Estrutura de arquivos

```
aula-07/
├── server.js                         # Entry point (porta e listen)
├── package.json
├── README.md
├── processo-spec.md
└── src/
    ├── app.js                        # Configuração do Express e rotas
    ├── data/
    │   └── store.js                  # Arrays em memória (rooms, reservations)
    ├── controllers/
    │   ├── roomsController.js        # Lógica de salas
    │   └── reservationsController.js # Lógica de reservas
    └── routes/
        ├── rooms.js                  # Mapeamento de verbos HTTP → controllers
        └── reservations.js
```

### Decisões de design

- **Separação em camadas** (routes → controllers → data): facilita leitura e manutenção. Cada arquivo tem uma única responsabilidade
- **IDs com `uuid`**: evita colisões e é mais realista do que auto-increment em array
- **Intervalo semi-aberto `[start, end)`** para checar conflito: uma reunião que termina às 10h e outra que começa às 10h não conflitam — comportamento esperado em sistemas de agendamento
- **Simplificação mantida**: sem autenticação, sem persistência em disco, sem paginação — o escopo pedido não exigia

---

## 4. Tarefas (os passos pequenos)

1. Verificar `package.json` existente e configurar o projeto
2. Criar estrutura de pastas (`src/routes`, `src/controllers`, `src/data`)
3. Criar camada de dados em memória (`rooms` e `reservations` como arrays exportados)
4. Criar controller de salas (`roomsController`) — `createRoom` e `listRooms`
5. Criar controller de reservas (`reservationsController`) — `createReservation`, `cancelReservation`, `listByEmployee`
6. Criar arquivos de rotas (`rooms.js` e `reservations.js`)
7. Criar `src/app.js` (Express + middlewares + montagem das rotas) e `server.js` (entry point)
8. Instalar dependências (`npm install` para baixar `uuid`)
9. Testar que o servidor sobe sem erros e validar todos os endpoints

---

## 5. Implementação e validação

### Tarefa 3 — Armazenamento em memória

**O quê**: criar o arquivo `src/data/store.js` exportando dois arrays vazios que funcionam como banco de dados em memória.

**Como testei**: verificando que os controllers conseguem importar e modificar os mesmos arrays por referência — ao adicionar uma sala em `roomsController`, ela aparece imediatamente ao chamar `GET /rooms`.

**Confirmação**:
```bash
# Cadastrar sala
curl -X POST http://localhost:3000/rooms \
  -H "Content-Type: application/json" \
  -d '{"name": "Sala Apollo", "capacity": 10}'
# → 201 com o objeto criado

# Listar — a sala aparece
curl http://localhost:3000/rooms
# → 200 com a sala e "available": true
```

---

### Tarefa 5 — Bloqueio de double booking

**O quê**: implementar a função `hasOverlap(startA, endA, startB, endB)` e aplicá-la antes de confirmar qualquer reserva.

**Como testei**: criando duas reservas para o mesmo horário na mesma sala.

**Confirmação**:
```bash
# Primeira reserva — sucesso
curl -X POST http://localhost:3000/reservations \
  -H "Content-Type: application/json" \
  -d '{
    "roomId": "<id>",
    "employeeId": "emp-001",
    "startTime": "2027-01-10T09:00:00",
    "endTime": "2027-01-10T11:00:00"
  }'
# → 201 Created

# Segunda reserva no mesmo horário — conflito
curl -X POST http://localhost:3000/reservations \
  -H "Content-Type: application/json" \
  -d '{
    "roomId": "<id>",
    "employeeId": "emp-002",
    "startTime": "2027-01-10T10:00:00",
    "endTime": "2027-01-10T12:00:00"
  }'
# → 409 Conflict
# {"error":"Conflito de horário: a sala já está reservada nesse período.","conflict":{...}}
```

---

### Tarefa 9 — Validação completa dos endpoints

**O quê**: smoke test sequencial cobrindo todos os 5 endpoints, incluindo casos de erro.

**Como testei**: script PowerShell executado no terminal do projeto chamando cada endpoint em ordem.

**Confirmação** (saída real obtida durante o desenvolvimento):

```
POST /rooms           → 201 Created  ✓
GET /rooms            → 200 OK       ✓  (campo "available": true)
POST /reservations    → 201 Created  ✓
POST /reservations    → 409 Conflict ✓  (double booking detectado)
GET /reservations/employee/emp-001 → 200 OK, total: 1  ✓
DELETE /reservations/:id → 200 OK, mensagem de cancelamento  ✓
```

---

## 6. A IA errou em algum momento?

A IA não cometeu erros funcionais durante este projeto. O método Spec contribuiu para isso de algumas formas:

- **Problema dividido antes de codificar**: ao listar as partes do problema primeiro, a IA recebeu contexto claro sobre o escopo — o que evita que ela "invente" funcionalidades não pedidas ou pule validações importantes
- **Tarefas pequenas e verificáveis**: cada passo tinha um critério de sucesso claro (ex: "o servidor deve responder 409 para double booking"), o que forçou a implementação a ser testável
- **Sem ambiguidade no contrato**: definir os campos de entrada e os status codes antes de implementar eliminou a principal fonte de erros de IA — a interpretação livre de requisitos vagos

Um ponto que exigiu atenção: a IA adicionou validações extras não pedidas no enunciado (nomes duplicados, reservas no passado). Isso foi avaliado e mantido por ser comportamento correto — mas em um projeto real seria uma decisão a confirmar com o time.

---

## 7. Reflexão

### O que teria acontecido com "jeito errado" (pedir tudo de uma vez)

Se o prompt fosse simplesmente *"crie uma API de reserva de salas com Node.js"*, o resultado provavelmente seria:
- Um único arquivo `app.js` com tudo misturado (rotas, lógica, dados)
- Validações incompletas ou ausentes
- Sem tratamento de double booking (a regra mais crítica)
- Sem status codes corretos (tudo retornando 200)
- Código difícil de entender e manter

### O que aprendi

**Dividir o problema é a parte mais importante.** Quando você quebra um sistema em partes menores antes de implementar, cada parte fica pequena o suficiente para ser verificada isoladamente. Isso vale tanto para humanos quanto para IA.

**A IA é um ótimo copiloto, não um piloto.** Ela executa bem quando o problema está bem definido. A responsabilidade de definir *o quê* construir e *por quê* continua sendo humana — e é exatamente isso que o método Spec-Driven formaliza.

**Testar cada passo evita acumulação de bugs.** No desenvolvimento tradicional sem Spec, os bugs aparecem todos de uma vez no final. Com tarefas pequenas e validação imediata, cada problema é resolvido enquanto o contexto ainda está fresco.
