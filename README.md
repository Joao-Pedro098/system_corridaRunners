# 🏃 RunnersRun

> Plataforma e comunidade para corredores de rua: feed social de treinos, calendário de eventos esportivos, notícias e painel de desempenho.

Trabalho de Conclusão de Curso (TCC) em Análise e Desenvolvimento de Sistemas — UNIFADESA (Parauapebas - PA).

---

## 📱 Visão Geral

O **RunnersRun** é uma solução completa para aproximar atletas e organizadores de corridas de rua:
- **🏃 Comunidade & Feed:** Publicação de treinos com distância (km), tempo, cálculo automático de ritmo médio (*pace* em min/km), fotos, curtidas e comentários.
- **📅 Calendário de Eventos:** Centralização das provas de corrida de rua da região com filtros por mês e distâncias (5k, 10k, 21k, etc.), mapas, retirada de kits, link de inscrições oficiais e confirmação de presença (*"Eu Vou!"*).
- **📰 Notícias & Dicas:** Artigos informativos sobre dicas de treino, nutrição, prevenção de lesões e comunicados das provas locais.
- **👤 Perfil do Atleta:** Mural de recordes pessoais (RP 5k, 10k, 21k, 42k), estatísticas acumuladas de volume e histórico de atividades.

---

## 🛠️ Tecnologias Utilizadas

### Frontend (Mobile & Web)
* **[Flutter](https://flutter.dev/)** (Dart 3.x)
* **Provider** (Gerenciamento de Estado)
* **Http & SharedPreferences** (Consumo de API REST e persistência de sessão JWT)

### Backend (API REST)
* **[Node.js](https://nodejs.org/)** com **[TypeScript](https://www.typescriptlang.org/)**
* **Express.js** (Roteamento e Middlewares)
* **[MongoDB Atlas](https://www.mongodb.com/atlas)** & **Mongoose** (Modelagem de dados)
* **JWT (JSON Web Token)** & **Bcrypt.js** (Autenticação segura)

---

## 🚀 Como Executar o Projeto

### Pré-requisitos
* Node.js (v18+)
* Flutter SDK (v3.x+)
* Conta no MongoDB Atlas ou instância local

### 1. Backend
```bash
cd backend
npm install
# Crie seu arquivo .env baseado no .env.example
npm run dev
```
A API estará disponível em `http://localhost:3000/api`.

### 2. Frontend
```bash
cd frontend
flutter pub get
flutter run -d chrome
# ou para dispositivo Android:
flutter run
```

---

## 👨‍💻 Autor
* **João Pedro Oliveira Tavares** — UNIFADESA
