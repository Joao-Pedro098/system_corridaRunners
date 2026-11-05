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

  // Erros do cliente, como JSON malformado, trazem o próprio status.
  const clientError = err.status >= 400 && err.status < 500;
  const statusCode = clientError ? err.status : res.statusCode === 200 ? 500 : res.statusCode;
  res.status(statusCode).json({
    sucesso: false,
    mensagem: clientError ? 'Requisição inválida.' : 'Erro interno do servidor',
  });
};
