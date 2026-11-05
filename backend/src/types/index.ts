import { Request } from 'express';
import { Document, Types } from 'mongoose';

export type UserRole = 'atleta' | 'organizador' | 'admin';

export interface IPersonalRecords {
  rp5k?: string;  // Formato: "00:22:45"
  rp10k?: string; // Formato: "00:48:10"
  rp21k?: string; // Formato: "01:45:30"
  rp42k?: string; // Formato: "03:40:00"
}

export interface IUserStatistics {
  totalKm: number;
  totalTreinos: number;
  tempoTotalSegundos: number;
}

export interface IUser extends Document {
  _id: Types.ObjectId;
  nome: string;
  email: string;
  senha: string;
  tipo: UserRole;
  telefone?: string;
  cidade?: string;
  estado?: string;
  avatarUrl?: string;
  bio?: string;
  recordesPessoais: IPersonalRecords;
  estatisticas: IUserStatistics;
  corridasSalvas: Types.ObjectId[];
  seguindo: Types.ObjectId[];
  seguidores: Types.ObjectId[];
  createdAt: Date;
  updatedAt: Date;
  compararSenha(senhaDigitada: string): Promise<boolean>;
}

export type WorkoutType =
  | 'rodagem'
  | 'longao'
  | 'tiro_intervalado'
  | 'tempo_run'
  | 'recuperacao'
  | 'prova';

export type EffortLevel =
  | 'muito_facil'
  | 'facil'
  | 'moderado'
  | 'dificil'
  | 'exaustivo';

export interface IWorkoutComment {
  _id?: Types.ObjectId;
  autor: Types.ObjectId;
  texto: string;
  createdAt: Date;
}

export interface IWorkoutPost extends Document {
  _id: Types.ObjectId;
  atleta: Types.ObjectId;
  titulo: string;
  descricao?: string;
  tipoTreino: WorkoutType;
  distanciaKm: number;
  duracaoSegundos: number;
  tempoFormatado: string; // Ex: "00:52:14"
  paceMedio: string;      // Ex: "05:13 min/km"
  altimetria?: number;    // Em metros
  sensacaoEsforco?: EffortLevel;
  fotos: string[];
  curtidas: Types.ObjectId[];
  comentarios: IWorkoutComment[];
  dataTreino: Date;
  createdAt: Date;
  updatedAt: Date;
}

export interface IRaceDistance {
  distanciaKm: number;
  categoria?: string; // Ex: "5km Geral", "Caminhada 3km"
  altimetria?: number; // em metros
  arquivoPercursoUrl?: string;
}

export interface IKitPickup {
  local?: string;
  data?: string;
  horario?: string;
  observacoes?: string;
}

export interface IPostRaceLinks {
  linkResultadosChip?: string;
  linkGaleriaFotos?: string;
  linkCertificado?: string;
}

export interface IOrganizerInfo {
  nome?: string;
  contato?: string;
  site?: string;
}

export type RaceStatus =
  | 'agendada'
  | 'inscricoes_abertas'
  | 'inscricoes_encerradas'
  | 'em_andamento'
  | 'concluida'
  | 'cancelada';

export interface IRace extends Document {
  _id: Types.ObjectId;
  nome: string;
  descricao?: string;
  data: Date;
  horarioLargada?: string;
  local: {
    cidade: string;
    estado: string;
    endereco?: string;
    coordenadas?: {
      latitude: number;
      longitude: number;
    };
  };
  distancias: IRaceDistance[];
  linkInscricao?: string;
  preco?: string;
  retiradaKit?: IKitPickup;
  regulamentoUrl?: string;
  bannerUrl?: string;
  posCorrida?: IPostRaceLinks;
  organizador?: IOrganizerInfo;
  status: RaceStatus;
  criadoPor?: Types.ObjectId;
  participantesConfirmados: Types.ObjectId[];
  createdAt: Date;
  updatedAt: Date;
}

export type NewsCategory =
  | 'Novidade'
  | 'Dica de Treino'
  | 'Nutrição'
  | 'Aviso'
  | 'Destaque';

export interface INews extends Document {
  _id: Types.ObjectId;
  titulo: string;
  subtitulo?: string;
  conteudo: string;
  categoria: NewsCategory;
  imagemUrl?: string;
  autor: string;
  destaque: boolean;
  linkOriginal?: string;
  fonteId?: string;
  fonteNome?: string;
  publicadoEm?: Date;
  oculta: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface ISavedRoute extends Document {
  dono: Types.ObjectId;
  nome: string;
  pontos: { lat: number; lng: number }[];
  trechos: { coordenadas: number[][]; subidaM: number; emLinhaReta: boolean }[];
  distanciaM: number;
  subidaM: number;
  temLinhaReta: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface INewsSource extends Document {
  fonteId: string;
  ativa: boolean;
  ultimaBusca?: Date;
  ultimoErro?: string;
  ultimasNovas: number;
  historicoConcluido: boolean;
}

export type NotificationType = 'curtida' | 'comentario' | 'seguidor';

export interface INotification extends Document {
  _id: Types.ObjectId;
  destinatario: Types.ObjectId;
  autor: Types.ObjectId;
  tipo: NotificationType;
  treino?: Types.ObjectId;
  comentario?: Types.ObjectId;
  lida: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface AuthenticatedRequest extends Request {
  user?: IUser;
}
