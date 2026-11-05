// Cria dados de exemplo para ver o app funcionando: npm run seed
// Só acrescenta em coleções vazias e nunca apaga nada. Atenção: usa o banco
// definido em MONGODB_URI, então confira o .env antes de rodar.
import { randomBytes } from 'crypto';
import dotenv from 'dotenv';
import mongoose from 'mongoose';
import { News } from '../models/News';
import { Race } from '../models/Race';
import { User } from '../models/User';

dotenv.config();

const daysFromNow = (days: number): Date => new Date(Date.now() + days * 24 * 60 * 60 * 1000);

const race = (
  nome: string,
  days: number,
  cidade: string,
  horarioLargada: string,
  status: string,
  kms: number[],
  altimetria: number,
  criadoPor: mongoose.Types.ObjectId
) => ({
  nome,
  data: daysFromNow(days),
  horarioLargada,
  status,
  criadoPor,
  local: { cidade, estado: 'PA', endereco: 'Praça Central' },
  distancias: kms.map((distanciaKm) => ({ distanciaKm, categoria: `${distanciaKm}K`, altimetria })),
  retiradaKit: { data: 'Véspera da prova', horario: '9h às 18h', local: 'Ginásio Municipal' },
  organizador: { nome: 'Corre Carajás' },
  descricao: 'Percurso urbano com subida na serra e chegada na praça central.',
});

const seed = async (): Promise<void> => {
  if (process.env.NODE_ENV === 'production') {
    throw new Error('O seed não roda em produção.');
  }
  const uri = process.env.MONGODB_URI;
  if (!uri) throw new Error('A variável MONGODB_URI não foi definida.');

  await mongoose.connect(uri);
  console.log(`Banco: ${mongoose.connection.name}`);

  const email = 'organizador@exemplo.com';
  let organizer = await User.findOne({ email });
  if (!organizer) {
    const senha = process.env.SEED_PASSWORD || randomBytes(9).toString('base64url');
    organizer = await User.create({
      nome: 'Corre Carajás',
      email,
      senha,
      tipo: 'organizador',
      cidade: 'Parauapebas',
      estado: 'PA',
    });
    console.log(`Organizador criado: ${email} / senha: ${senha}`);
  }

  if ((await Race.countDocuments()) === 0) {
    await Race.insertMany([
      race('Rústica do Rio Verde', -3, 'Parauapebas', '06:00', 'concluida', [5, 10, 21], 120, organizer._id),
      race('Corrida da Serra 2026', 10, 'Parauapebas', '06:00', 'inscricoes_abertas', [5, 10, 21], 184, organizer._id),
      race('Night Run Carajás', 24, 'Canaã dos Carajás', '19:00', 'agendada', [5, 10], 60, organizer._id),
      race('Meia da Integração', 32, 'Marabá', '05:30', 'inscricoes_encerradas', [10, 21], 90, organizer._id),
      race('Desafio do Minério', 38, 'Parauapebas', '06:30', 'inscricoes_abertas', [5, 10, 21, 42], 310, organizer._id),
    ]);
    console.log('Provas de exemplo criadas.');
  } else {
    console.log('Já existem provas: nada foi criado.');
  }

  if ((await News.countDocuments()) === 0) {
    await News.insertMany([
      {
        titulo: 'O que comer antes do longão de domingo',
        subtitulo: 'Carboidrato na medida certa, sem pesar no estômago.',
        conteudo:
          'Comece a pensar no longão ainda no sábado, com uma refeição rica em carboidratos. No dia, prefira algo leve duas horas antes da largada e teste tudo nos treinos, nunca na prova.',
        categoria: 'Nutrição',
        destaque: true,
      },
      {
        titulo: 'Como dosar o ritmo na subida da serra',
        conteudo:
          'Encurte a passada, mantenha o esforço constante em vez do pace e use a descida para recuperar. Quem guarda energia na primeira metade chega melhor ao fim.',
        categoria: 'Dica de Treino',
      },
    ]);
    console.log('Notícias de exemplo criadas.');
  } else {
    console.log('Já existem notícias: nada foi criado.');
  }
};

seed()
  .catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  })
  .finally(() => mongoose.disconnect());
