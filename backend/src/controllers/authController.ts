import { Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { User } from '../models/User';
import { Race } from '../models/Race';
import { AuthenticatedRequest } from '../types';

// Função auxiliar para gerar JWT
const generateToken = (id: string): string => {
  const jwtSecret = process.env.JWT_SECRET || 'secret';
  return jwt.sign({ id }, jwtSecret, {
    expiresIn: '30d',
  });
};

// @desc    Registrar novo usuário (Atleta ou Organizador)
// @route   POST /api/auth/register
// @access  Público
export const register = async (req: Request, res: Response): Promise<void> => {
  try {
    const { nome, email, senha, tipo, telefone, cidade, estado, bio, avatarUrl } = req.body;

    const userExists = await User.findOne({ email });
    if (userExists) {
      res.status(400).json({
        sucesso: false,
        mensagem: 'Já existe um usuário cadastrado com este e-mail.',
      });
      return;
    }

    const user = await User.create({
      nome,
      email,
      senha,
      tipo: tipo || 'atleta',
      telefone,
      cidade,
      estado,
      bio,
      avatarUrl,
    });

    res.status(201).json({
      sucesso: true,
      mensagem: 'Cadastro realizado com sucesso!',
      dados: {
        _id: user._id,
        nome: user.nome,
        email: user.email,
        tipo: user.tipo,
        cidade: user.cidade,
        estado: user.estado,
        avatarUrl: user.avatarUrl,
        bio: user.bio,
        token: generateToken(user._id.toString()),
      },
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao registrar usuário.',
    });
  }
};

// @desc    Autenticar usuário e obter token
// @route   POST /api/auth/login
// @access  Público
export const login = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, senha } = req.body;

    if (!email || !senha) {
      res.status(400).json({
        sucesso: false,
        mensagem: 'Por favor, informe e-mail e senha.',
      });
      return;
    }

    const user = await User.findOne({ email }).select('+senha');
    if (!user) {
      res.status(401).json({
        sucesso: false,
        mensagem: 'E-mail ou senha inválidos.',
      });
      return;
    }

    const isMatch = await user.compararSenha(senha);
    if (!isMatch) {
      res.status(401).json({
        sucesso: false,
        mensagem: 'E-mail ou senha inválidos.',
      });
      return;
    }

    res.status(200).json({
      sucesso: true,
      mensagem: 'Login realizado com sucesso!',
      dados: {
        _id: user._id,
        nome: user.nome,
        email: user.email,
        tipo: user.tipo,
        cidade: user.cidade,
        estado: user.estado,
        avatarUrl: user.avatarUrl,
        bio: user.bio,
        recordesPessoais: user.recordesPessoais,
        estatisticas: user.estatisticas,
        token: generateToken(user._id.toString()),
      },
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao realizar login.',
    });
  }
};

// @desc    Obter perfil do usuário logado (com corridas salvas)
// @route   GET /api/auth/me
// @access  Privado
export const getMe = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({ sucesso: false, mensagem: 'Não autorizado' });
      return;
    }

    const user = await User.findById(req.user._id).populate('corridasSalvas');

    res.status(200).json({
      sucesso: true,
      dados: user,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao obter perfil.',
    });
  }
};

// @desc    Obter perfil público de um corredor por ID
// @route   GET /api/auth/profile/:id
// @access  Público
export const getProfileById = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const user = await User.findById(id).select(
      'nome avatarUrl bio cidade estado recordesPessoais estatisticas tipo createdAt'
    );

    if (!user) {
      res.status(404).json({ sucesso: false, mensagem: 'Corredor não encontrado.' });
      return;
    }

    res.status(200).json({
      sucesso: true,
      dados: user,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao buscar perfil.',
    });
  }
};

// @desc    Atualizar perfil (dados cadastrais, bio e recordes pessoais)
// @route   PUT /api/auth/profile
// @access  Privado
export const updateProfile = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({ sucesso: false, mensagem: 'Não autorizado' });
      return;
    }

    const { nome, telefone, cidade, estado, avatarUrl, bio, recordesPessoais } = req.body;

    const user = await User.findById(req.user._id);
    if (!user) {
      res.status(404).json({ sucesso: false, mensagem: 'Usuário não encontrado' });
      return;
    }

    if (nome) user.nome = nome;
    if (telefone !== undefined) user.telefone = telefone;
    if (cidade !== undefined) user.cidade = cidade;
    if (estado !== undefined) user.estado = estado;
    if (avatarUrl !== undefined) user.avatarUrl = avatarUrl;
    if (bio !== undefined) user.bio = bio;
    if (recordesPessoais) {
      user.recordesPessoais = {
        ...user.recordesPessoais,
        ...recordesPessoais,
      };
    }

    await user.save();

    res.status(200).json({
      sucesso: true,
      mensagem: 'Perfil atualizado com sucesso!',
      dados: user,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao atualizar perfil.',
    });
  }
};

// @desc    Salvar ou remover corrida da lista de favoritos do atleta
// @route   POST /api/auth/races/:raceId/toggle-save
// @access  Privado
export const toggleSaveRace = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({ sucesso: false, mensagem: 'Não autorizado' });
      return;
    }

    const { raceId } = req.params;
    const race = await Race.findById(raceId);
    if (!race) {
      res.status(404).json({ sucesso: false, mensagem: 'Corrida não encontrada.' });
      return;
    }

    const user = await User.findById(req.user._id);
    if (!user) {
      res.status(404).json({ sucesso: false, mensagem: 'Usuário não encontrado.' });
      return;
    }

    const index = user.corridasSalvas.findIndex(
      (id) => id.toString() === raceId
    );

    let salva = false;
    if (index === -1) {
      user.corridasSalvas.push(race._id);
      salva = true;
    } else {
      user.corridasSalvas.splice(index, 1);
      salva = false;
    }

    await user.save();

    res.status(200).json({
      sucesso: true,
      mensagem: salva ? 'Corrida favoritada com sucesso!' : 'Corrida removida dos favoritos.',
      salva,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao atualizar favoritos.',
    });
  }
};

// @desc    Confirmar presença na corrida ("Eu Vou!")
// @route   POST /api/auth/races/:raceId/toggle-presence
// @access  Privado
export const togglePresence = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({ sucesso: false, mensagem: 'Não autorizado' });
      return;
    }

    const { raceId } = req.params;
    const race = await Race.findById(raceId);
    if (!race) {
      res.status(404).json({ sucesso: false, mensagem: 'Corrida não encontrada.' });
      return;
    }

    const userId = req.user._id;
    const index = race.participantesConfirmados.findIndex(
      (id) => id.toString() === userId.toString()
    );

    let confirmado = false;
    if (index === -1) {
      race.participantesConfirmados.push(userId);
      confirmado = true;
    } else {
      race.participantesConfirmados.splice(index, 1);
      confirmado = false;
    }

    await race.save();

    res.status(200).json({
      sucesso: true,
      mensagem: confirmado
        ? 'Presença confirmada! Seu nome está na lista de confirmados.'
        : 'Presença cancelada no evento.',
      confirmado,
      totalParticipantes: race.participantesConfirmados.length,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao confirmar presença.',
    });
  }
};
