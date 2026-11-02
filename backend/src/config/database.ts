import mongoose from 'mongoose';

export const connectDatabase = async (): Promise<void> => {
  try {
    const mongoUri = process.env.MONGODB_URI;
    if (!mongoUri) {
      throw new Error('A variável MONGODB_URI não foi definida no arquivo .env');
    }

    const conn = await mongoose.connect(mongoUri);
    console.log(`✅ MongoDB Conectado com sucesso: ${conn.connection.host} (${conn.connection.name})`);
  } catch (error) {
    console.error('❌ Erro ao conectar ao MongoDB:', error);
    process.exit(1);
  }
};
