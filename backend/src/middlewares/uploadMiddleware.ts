import { randomUUID } from 'crypto';
import { promises as fs } from 'fs';
import path from 'path';
import { NextFunction, Request, Response } from 'express';
import multer from 'multer';

export const MAX_WORKOUT_PHOTOS = 4;
const MAX_PHOTO_BYTES = 5 * 1024 * 1024;

// Por enquanto as fotos ficam em disco. Para usar um serviço como o Cloudinary,
// basta trocar savePhoto, removePhotos e o formato validado em isOwnPhotoPath.
export const UPLOAD_ROOT = path.resolve(__dirname, '../../uploads');
const PUBLIC_PREFIX = '/uploads/workouts/';
const WORKOUTS_DIR = path.join(UPLOAD_ROOT, 'workouts');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_PHOTO_BYTES, files: MAX_WORKOUT_PHOTOS },
}).array('fotos', MAX_WORKOUT_PHOTOS);

// Recebe as fotos e transforma erros do multer em mensagens para o app.
export const receiveWorkoutPhotos = (req: Request, res: Response, next: NextFunction): void => {
  upload(req, res, (error: unknown) => {
    if (!error) {
      next();
      return;
    }
    const code = error instanceof multer.MulterError ? error.code : '';
    const mensagem =
      code === 'LIMIT_FILE_SIZE'
        ? 'Cada foto pode ter no máximo 5 MB.'
        : code === 'LIMIT_FILE_COUNT' || code === 'LIMIT_UNEXPECTED_FILE'
          ? `Envie no máximo ${MAX_WORKOUT_PHOTOS} fotos por treino.`
          : 'Não foi possível receber as fotos.';
    res.status(400).json({ sucesso: false, mensagem });
  });
};

// Identifica o formato pelo conteúdo do arquivo: o nome e o tipo informados
// pelo cliente não são confiáveis.
export const detectImageExtension = (data: Buffer): 'jpg' | 'png' | 'webp' | null => {
  if (data.length >= 3 && data[0] === 0xff && data[1] === 0xd8 && data[2] === 0xff) return 'jpg';
  if (data.length >= 8 && data.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return 'png';
  }
  if (
    data.length >= 12 &&
    data.subarray(0, 4).toString('latin1') === 'RIFF' &&
    data.subarray(8, 12).toString('latin1') === 'WEBP'
  ) {
    return 'webp';
  }
  return null;
};

// O nome leva o id do atleta para que ninguém publique a foto de outra pessoa.
export const savePhoto = async (data: Buffer, extension: string, userId: string): Promise<string> => {
  await fs.mkdir(WORKOUTS_DIR, { recursive: true });
  const name = `${userId}-${randomUUID()}.${extension}`;
  await fs.writeFile(path.join(WORKOUTS_DIR, name), data);
  return `${PUBLIC_PREFIX}${name}`;
};

export const isOwnPhotoPath = (value: unknown, userId: string): boolean =>
  typeof value === 'string' &&
  new RegExp(`^${PUBLIC_PREFIX}${userId}-[0-9a-f-]{36}\\.(jpg|png|webp)$`).test(value);

// Só apaga caminhos no formato gerado por savePhoto. Falha ao apagar não deve
// impedir a exclusão do treino.
export const removePhotos = async (paths: string[]): Promise<void> => {
  await Promise.all(
    paths
      .filter((p) => /^\/uploads\/workouts\/[0-9a-f]+-[0-9a-f-]{36}\.(jpg|png|webp)$/.test(p))
      .map((p) => fs.unlink(path.join(WORKOUTS_DIR, path.basename(p))).catch(() => undefined))
  );
};
