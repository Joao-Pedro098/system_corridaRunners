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
    // Quem publicou: só essa pessoa ou um admin pode alterar. Vazio em notícias antigas e externas.
    criadoPor: {
      type: Schema.Types.ObjectId,
      ref: 'User',
    },
    destaque: {
      type: Boolean,
      default: false,
    },
    // Só em matérias vindas de fontes externas; `conteudo` guarda apenas o resumo do feed.
    linkOriginal: {
      type: String,
      trim: true,
      unique: true,
      sparse: true,
    },
    fonteId: {
      type: String,
    },
    fonteNome: {
      type: String,
    },
    publicadoEm: {
      type: Date,
    },
    oculta: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

export const News = mongoose.model<INews>('News', newsSchema);
