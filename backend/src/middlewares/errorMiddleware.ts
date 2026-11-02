import { Request, Response, NextFunction } from 'express';

// Rota não encontrada (404)
export const notFound = (req: Request, res: Response, next: NextFunction): void => {
  res.status(404).json({
    sucesso: false,
    mensagem: `Rota não encontrada: ${req.method} ${req.originalUrl}`,
  });
};

// Tratador global de erros (500)
export const errorHandler = (
  err: any,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  console.error('Erro na aplicação:', err);

  const statusCode = res.statusCode === 200 ? 500 : res.statusCode;
  res.status(statusCode).json({
    sucesso: false,
    mensagem: err.message || 'Erro interno do servidor',
    stack: process.env.NODE_ENV === 'production' ? null : err.stack,
  });
};
