import { NextFunction, Request, Response } from 'express';
import mongoose from 'mongoose';

// Id malformado na URL responde 404, em vez de virar erro 500 no banco.
export const validateObjectId =
  (...params: string[]) =>
  (req: Request, res: Response, next: NextFunction): void => {
    const invalid = params.some((param) => !mongoose.isValidObjectId(req.params[param]));
    if (invalid) {
      res.status(404).json({ sucesso: false, mensagem: 'Registro não encontrado.' });
      return;
    }
    next();
  };
