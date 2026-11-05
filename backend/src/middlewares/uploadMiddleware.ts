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

type PhotoFolder = 'workouts' | 'races';

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

const coverUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_PHOTO_BYTES, files: 1 },
}).single('capa');

// Recebe a imagem de capa de uma prova.
export const receiveRaceCover = (req: Request, res: Response, next: NextFunction): void => {
  coverUpload(req, res, (error: unknown) => {
    if (!error) {
      next();
      return;
    }
    const tooBig = error instanceof multer.MulterError && error.code === 'LIMIT_FILE_SIZE';
    res.status(400).json({
      sucesso: false,
      mensagem: tooBig ? 'A capa pode ter no máximo 5 MB.' : 'Não foi possível receber a imagem.',
    });
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
export const savePhoto = async (
  data: Buffer,
  extension: string,
  userId: string,
  folder: PhotoFolder = 'workouts'
): Promise<string> => {
  const directory = path.join(UPLOAD_ROOT, folder);
  await fs.mkdir(directory, { recursive: true });
  const name = `${userId}-${randomUUID()}.${extension}`;
  await fs.writeFile(path.join(directory, name), data);
  return `/uploads/${folder}/${name}`;
};

export const isOwnPhotoPath = (value: unknown, userId: string, folder: PhotoFolder = 'workouts'): boolean =>
  typeof value === 'string' &&
  new RegExp(`^/uploads/${folder}/${userId}-[0-9a-f-]{36}\\.(jpg|png|webp)$`).test(value);

// Só apaga caminhos no formato gerado por savePhoto. Falha ao apagar não deve
// impedir a exclusão do treino ou da prova.
export const removePhotos = async (paths: string[]): Promise<void> => {
  await Promise.all(
    paths
      .filter((p) => /^\/uploads\/(workouts|races)\/[0-9a-f]+-[0-9a-f-]{36}\.(jpg|png|webp)$/.test(p))
      .map((p) => fs.unlink(path.join(UPLOAD_ROOT, p.replace('/uploads/', ''))).catch(() => undefined))
  );
};
