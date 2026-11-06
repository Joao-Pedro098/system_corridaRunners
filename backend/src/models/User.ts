import mongoose, { Schema } from 'mongoose';
import bcrypt from 'bcryptjs';
import { IUser } from '../types';

const userSchema = new Schema<IUser>(
  {
    nome: {
      type: String,
      required: [true, 'O nome é obrigatório'],
      trim: true,
    },
    email: {
      type: String,
      required: [true, 'O e-mail é obrigatório'],
      unique: true,
      lowercase: true,
      trim: true,
      match: [/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/, 'Por favor, informe um e-mail válido'],
    },
    senha: {
      type: String,
      required: [true, 'A senha é obrigatória'],
      minlength: [6, 'A senha deve ter pelo menos 6 caracteres'],
      select: false,
    },
    // Tokens emitidos antes desta data deixam de valer.
    senhaAlteradaEm: {
      type: Date,
    },
    tipo: {
      type: String,
      enum: ['atleta', 'organizador', 'admin'],
      default: 'atleta',
    },
    telefone: {
      type: String,
      trim: true,
    },
    cidade: {
      type: String,
      trim: true,
    },
    estado: {
      type: String,
      trim: true,
    },
    avatarUrl: {
      type: String,
      trim: true,
      default: '',
    },
    bio: {
      type: String,
      trim: true,
      default: '',
    },
    recordesPessoais: {
      rp5k: { type: String, default: '' },
      rp10k: { type: String, default: '' },
      rp21k: { type: String, default: '' },
      rp42k: { type: String, default: '' },
    },
    estatisticas: {
      totalKm: { type: Number, default: 0 },
      totalTreinos: { type: Number, default: 0 },
      tempoTotalSegundos: { type: Number, default: 0 },
    },
    corridasSalvas: [
      {
        type: Schema.Types.ObjectId,
        ref: 'Race',
      },
    ],
    seguindo: [
      {
        type: Schema.Types.ObjectId,
        ref: 'User',
      },
    ],
    seguidores: [
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

// Hash de senha antes de salvar
userSchema.pre('save', async function (next) {
  if (!this.isModified('senha')) {
    return next();
  }
  const salt = await bcrypt.genSalt(10);
  this.senha = await bcrypt.hash(this.senha, salt);
  next();
});

// Método para verificar senha no login
userSchema.methods.compararSenha = async function (senhaDigitada: string): Promise<boolean> {
  return await bcrypt.compare(senhaDigitada, this.senha);
};

export const User = mongoose.model<IUser>('User', userSchema);
