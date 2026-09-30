# TechNova — API de Reserva de Salas de Reunião

API RESTful desenvolvida em Node.js com Express para gerenciar salas e reservas de reunião.  
Os dados ficam em memória (sem banco de dados).

## Pré-requisitos

- Node.js v18 ou superior
- npm

## Instalação

```bash
npm install
```

## Rodar o servidor

```bash
# Produção
npm start

# Desenvolvimento (hot-reload nativo do Node)
npm run dev
```

Servidor sobe em: `http://localhost:3000`

---

## Endpoints

| Método   | Rota                                    | Descrição                          |
|----------|-----------------------------------------|------------------------------------|
| `POST`   | `/rooms`                                | Cadastrar sala                     |
| `GET`    | `/rooms`                                | Listar salas e disponibilidade     |
| `POST`   | `/reservations`                         | Fazer reserva                      |
| `DELETE` | `/reservations/:id`                     | Cancelar reserva                   |
| `GET`    | `/reservations/employee/:employeeId`    | Listar reservas de um funcionário  |

---

## Exemplos de uso (cURL)

### Cadastrar sala
```bash
curl -X POST http://localhost:3000/rooms \
  -H "Content-Type: application/json" \
  -d '{"name": "Sala Apollo", "capacity": 10}'
```
Resposta `201 Created`:
```json
{
  "id": "uuid-gerado",
  "name": "Sala Apollo",
  "capacity": 10,
  "createdAt": "2027-01-10T12:00:00.000Z"
}
```

### Listar salas e disponibilidade
```bash
curl http://localhost:3000/rooms
```
Resposta `200 OK`:
```json
[
  {
    "id": "uuid-gerado",
    "name": "Sala Apollo",
    "capacity": 10,
    "available": true,
    "currentReservation": null
  }
]
```

### Fazer reserva
```bash
curl -X POST http://localhost:3000/reservations \
  -H "Content-Type: application/json" \
  -d '{
    "roomId": "<id da sala>",
    "employeeId": "emp-001",
    "startTime": "2027-01-10T09:00:00",
    "endTime": "2027-01-10T11:00:00"
  }'
```
Resposta `201 Created` ou `409 Conflict` se o horário já estiver ocupado.

### Cancelar reserva
```bash
curl -X DELETE http://localhost:3000/reservations/<id da reserva>
```
Resposta `200 OK`.

### Listar reservas de um funcionário
```bash
curl http://localhost:3000/reservations/employee/emp-001
```
Resposta `200 OK`:
```json
{
  "employeeId": "emp-001",
  "total": 1,
  "reservations": [...]
}
```

---

## Status codes utilizados

| Código | Situação                                         |
|--------|--------------------------------------------------|
| 200    | Operação bem-sucedida                            |
| 201    | Recurso criado com sucesso                       |
| 400    | Dados inválidos ou ausentes no body              |
| 404    | Sala ou reserva não encontrada                   |
| 409    | Conflito: sala já reservada ou nome duplicado    |
| 500    | Erro interno do servidor                         |
