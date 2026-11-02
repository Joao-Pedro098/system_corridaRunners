import mongoose, { Schema } from 'mongoose';
import { IRace } from '../types';

const raceSchema = new Schema<IRace>(
  {
    nome: {
      type: String,
      required: [true, 'O nome da corrida é obrigatório'],
      trim: true,
    },
    descricao: {
      type: String,
      trim: true,
    },
    data: {
      type: Date,
      required: [true, 'A data da corrida é obrigatória'],
      index: true,
    },
    horarioLargada: {
      type: String,
      trim: true,
    },
    local: {
      cidade: { type: String, required: true, trim: true, index: true },
      estado: { type: String, required: true, trim: true },
      endereco: { type: String, trim: true },
      coordenadas: {
        latitude: { type: Number },
        longitude: { type: Number },
      },
    },
    distancias: [
      {
        distanciaKm: { type: Number, required: true }, // Ex: 5, 10, 21, 42
        categoria: { type: String, trim: true },       // Ex: "5km Geral", "Caminhada 3km"
        altimetria: { type: Number, default: 0 },      // Ganho de elevação em metros
        rotaGeoJSON: {
          type: {
            type: String,
            enum: ['LineString'],
          },
          coordinates: [[Number]],
        },
        arquivoPercursoUrl: { type: String, trim: true },
      },
    ],
    linkInscricao: {
      type: String,
      trim: true,
    },
    preco: {
      type: String,
      trim: true,
    },
    retiradaKit: {
      local: { type: String, trim: true },
      data: { type: String, trim: true },
      horario: { type: String, trim: true },
      observacoes: { type: String, trim: true },
    },
    regulamentoUrl: {
      type: String,
      trim: true,
    },
    bannerUrl: {
      type: String,
      trim: true,
    },
    posCorrida: {
      linkResultadosChip: { type: String, trim: true },
      linkGaleriaFotos: { type: String, trim: true },
      linkCertificado: { type: String, trim: true },
    },
    organizador: {
      nome: { type: String, trim: true },
      contato: { type: String, trim: true },
      site: { type: String, trim: true },
    },
    status: {
      type: String,
      enum: ['agendada', 'inscricoes_abertas', 'inscricoes_encerradas', 'em_andamento', 'concluida', 'cancelada'],
      default: 'inscricoes_abertas',
      index: true,
    },
    participantesConfirmados: [
      {
        type: Schema.Types.ObjectId,
        ref: 'User',
      },
    ],
  },
  {
    timestamps: true,
  }
);

// Índice de texto para busca rápida por nome, cidade ou descrição
raceSchema.index({ nome: 'text', descricao: 'text', 'local.cidade': 'text' });

export const Race = mongoose.model<IRace>('Race', raceSchema);
