import mongoose, { Schema } from 'mongoose';
import { IWorkoutPost } from '../types';
import { routeShapeFields } from './SavedRoute';

const commentSchema = new Schema(
  {
    autor: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    texto: {
      type: String,
      required: [true, 'O texto do comentário é obrigatório'],
      trim: true,
      maxlength: [500, 'O comentário deve ter no máximo 500 caracteres'],
    },
  },
  {
    timestamps: true,
  }
);

// Cópia de uma rota salva, feita quando o atleta escolhe publicá-la. A rota original
// continua privada, e editá-la ou excluí-la não muda os treinos já publicados.
const workoutRouteSchema = new Schema(
  {
    ...routeShapeFields,
    nome: { type: String, required: true, trim: true },
    // Traçado reduzido para os cartões; as listagens não trazem o restante.
    resumo: { type: [[Number]], default: [] },
  },
  { _id: false }
);

const workoutPostSchema = new Schema<IWorkoutPost>(
  {
    atleta: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'O atleta é obrigatório'],
      index: true,
    },
    titulo: {
      type: String,
      required: [true, 'O título do treino é obrigatório'],
      trim: true,
      maxlength: [100, 'O título não pode exceder 100 caracteres'],
    },
    descricao: {
      type: String,
      trim: true,
      maxlength: [2000, 'A descrição não pode exceder 2000 caracteres'],
    },
    tipoTreino: {
      type: String,
      enum: ['rodagem', 'longao', 'tiro_intervalado', 'tempo_run', 'recuperacao', 'prova'],
      default: 'rodagem',
      index: true,
    },
    distanciaKm: {
      type: Number,
      required: [true, 'A distância em km é obrigatória'],
      min: [0.1, 'A distância mínima é 0.1 km'],
    },
    duracaoSegundos: {
      type: Number,
      required: [true, 'A duração do treino em segundos é obrigatória'],
      min: [1, 'A duração mínima é de 1 segundo'],
    },
    tempoFormatado: {
      type: String,
      required: true,
      trim: true, // Ex: "00:52:30"
    },
    paceMedio: {
      type: String,
      required: true,
      trim: true, // Ex: "05:15 min/km"
    },
    altimetria: {
      type: Number,
      default: 0,
    },
    sensacaoEsforco: {
      type: String,
      enum: ['muito_facil', 'facil', 'moderado', 'dificil', 'exaustivo'],
      default: 'moderado',
    },
    fotos: [
      {
        type: String,
        trim: true,
      },
    ],
    rota: { type: workoutRouteSchema, default: undefined },
    curtidas: [
      {
        type: Schema.Types.ObjectId,
        ref: 'User',
      },
    ],
    comentarios: [commentSchema],
    dataTreino: {
      type: Date,
      default: Date.now,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

// Índice composto para buscar feed recente
workoutPostSchema.index({ createdAt: -1 });

export const WorkoutPost = mongoose.model<IWorkoutPost>('WorkoutPost', workoutPostSchema);
