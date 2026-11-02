import mongoose, { Schema } from 'mongoose';
import { INews } from '../types';

const newsSchema = new Schema<INews>(
  {
    titulo: {
      type: String,
      required: [true, 'O título da notícia é obrigatório'],
      trim: true,
    },
    subtitulo: {
      type: String,
      trim: true,
    },
    conteudo: {
      type: String,
      required: [true, 'O conteúdo da notícia é obrigatório'],
    },
    categoria: {
      type: String,
      enum: ['Novidade', 'Dica de Treino', 'Nutrição', 'Aviso', 'Destaque'],
      default: 'Novidade',
    },
    imagemUrl: {
      type: String,
      trim: true,
    },
    autor: {
      type: String,
      default: 'Comunidade de Corridas',
      trim: true,
    },
    destaque: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

export const News = mongoose.model<INews>('News', newsSchema);
