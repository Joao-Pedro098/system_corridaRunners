import { Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { getJwtSecret } from '../config/jwt';
import { User } from '../models/User';
import { AuthenticatedRequest, UserRole } from '../types';

interface DecodedToken {
  id: string;
  iat: number;
  exp: number;
}

export const protect = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  let token: string | undefined;

  if (
    req.headers.authorization &&
    req.headers.authorization.startsWith('Bearer')
  ) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    res.status(401).json({
      sucesso: false,
      mensagem: 'Acesso não autorizado. Por favor, forneça um token de autenticação.',
    });
    return;
  }

  try {
    const decoded = jwt.verify(token, getJwtSecret()) as DecodedToken;

    const user = await User.findById(decoded.id).select('-senha');
    if (!user) {
      res.status(401).json({
        sucesso: false,
        mensagem: 'Usuário pertencente a este token não foi encontrado.',
      });
      return;
    }

    // Trocar a senha encerra as sessões abertas em outros aparelhos.
    const alteradaEm = user.senhaAlteradaEm?.getTime();
    if (alteradaEm && decoded.iat < Math.floor(alteradaEm / 1000)) {
      res.status(401).json({
        sucesso: false,
        mensagem: 'Sua senha foi alterada. Entre novamente.',
      });
      return;
    }

    req.user = user;
    next();
  } catch (error) {
    res.status(401).json({
      sucesso: false,
      mensagem: 'Token inválido ou expirado.',
    });
  }
};

export const authorize = (...roles: UserRole[]) => {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction): void => {
    if (!req.user || !roles.includes(req.user.tipo)) {
      res.status(403).json({
        sucesso: false,
        mensagem: `O perfil '${req.user?.tipo || 'desconhecido'}' não tem permissão para realizar esta ação.`,
      });
      return;
    }
    next();
  };
};
