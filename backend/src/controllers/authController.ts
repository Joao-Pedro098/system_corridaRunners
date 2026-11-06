import { Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { User } from '../models/User';
import { Race } from '../models/Race';
import { getJwtSecret } from '../config/jwt';
import { detectImageExtension, removePhotos, savePhoto } from '../middlewares/uploadMiddleware';
import { removeNotifications, notify } from '../services/notificationService';
import { AuthenticatedRequest } from '../types';

// Função auxiliar para gerar JWT
const generateToken = (id: string): string => {
  return jwt.sign({ id }, getJwtSecret(), {
    expiresIn: '30d',
  });
};

// @desc    Registrar novo usuário (Atleta ou Organizador)
// @route   POST /api/auth/register
// @access  Público
export const register = async (req: Request, res: Response): Promise<void> => {
  try {
    const { nome, senha, tipo, telefone, cidade, estado, bio } = req.body;

    if (typeof req.body.email !== 'string' || typeof senha !== 'string' || typeof nome !== 'string') {
      res.status(400).json({ sucesso: false, mensagem: 'Informe nome, e-mail e senha.' });
      return;
    }
    const email = req.body.email.trim().toLowerCase();

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
      // Conta de admin nunca nasce pelo cadastro público.
      tipo: tipo === 'organizador' ? 'organizador' : 'atleta',
      telefone,
      cidade,
      estado,
      bio,
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
    if (error.name === 'ValidationError') {
      const primeira: any = Object.values(error.errors)[0];
      res.status(400).json({ sucesso: false, mensagem: primeira?.message || 'Dados inválidos.' });
      return;
    }
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

    if (typeof email !== 'string' || typeof senha !== 'string' || !email || !senha) {
      res.status(400).json({
        sucesso: false,
        mensagem: 'Por favor, informe e-mail e senha.',
      });
      return;
    }

    const user = await User.findOne({ email: email.trim().toLowerCase() }).select('+senha');
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

    const user = await User.findById(req.user._id).populate({ path: 'corridasSalvas', select: '-distancias.percurso' });

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
      'nome avatarUrl bio cidade estado recordesPessoais estatisticas tipo createdAt seguidores seguindo'
    );

    if (!user) {
      res.status(404).json({ sucesso: false, mensagem: 'Corredor não encontrado.' });
      return;
    }

    // O perfil público mostra só as contagens, não a lista de pessoas.
    res.status(200).json({
      sucesso: true,
      dados: { ...user.toObject(), seguidores: user.seguidores.length, seguindo: user.seguindo.length },
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

    const { nome, telefone, cidade, estado, bio, recordesPessoais } = req.body;

    const user = await User.findById(req.user._id);
    if (!user) {
      res.status(404).json({ sucesso: false, mensagem: 'Usuário não encontrado' });
      return;
    }

    if (nome) user.nome = nome;
    if (telefone !== undefined) user.telefone = telefone;
    if (cidade !== undefined) user.cidade = cidade;
    if (estado !== undefined) user.estado = estado;
    if (bio !== undefined) user.bio = bio;
    if (recordesPessoais && typeof recordesPessoais === 'object') {
      for (const chave of ['rp5k', 'rp10k', 'rp21k', 'rp42k'] as const) {
        if (typeof recordesPessoais[chave] === 'string') {
          user.recordesPessoais[chave] = recordesPessoais[chave];
        }
      }
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

// @desc    Trocar a senha e encerrar as demais sessões
// @route   PUT /api/auth/password
// @access  Privado
export const changePassword = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { senhaAtual, novaSenha } = req.body ?? {};
    if (typeof senhaAtual !== 'string' || typeof novaSenha !== 'string' || !senhaAtual || !novaSenha) {
      res.status(400).json({ sucesso: false, mensagem: 'Informe a senha atual e a nova senha.' });
      return;
    }

    const user = await User.findById(req.user?._id).select('+senha');
    if (!user) {
      res.status(404).json({ sucesso: false, mensagem: 'Usuário não encontrado.' });
      return;
    }

    // É 400, não 401: para o app, 401 significa sessão encerrada.
    if (!(await user.compararSenha(senhaAtual))) {
      res.status(400).json({ sucesso: false, mensagem: 'A senha atual está incorreta.' });
      return;
    }
    if (novaSenha === senhaAtual) {
      res.status(400).json({ sucesso: false, mensagem: 'A nova senha precisa ser diferente da atual.' });
      return;
    }

    user.senha = novaSenha;
    user.senhaAlteradaEm = new Date();
    await user.save();

    res.status(200).json({
      sucesso: true,
      mensagem: 'Senha alterada!',
      token: generateToken(user._id.toString()),
    });
  } catch (error: any) {
    if (error.name === 'ValidationError') {
      const primeira: any = Object.values(error.errors)[0];
      res.status(400).json({ sucesso: false, mensagem: primeira?.message || 'Dados inválidos.' });
      return;
    }
    res.status(500).json({ sucesso: false, mensagem: error.message || 'Erro ao alterar a senha.' });
  }
};

// @desc    Enviar a foto de perfil, substituindo a anterior
// @route   POST /api/auth/avatar
// @access  Privado
export const uploadAvatar = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const file = req.file;
    if (!file) {
      res.status(400).json({ sucesso: false, mensagem: 'Nenhuma imagem enviada.' });
      return;
    }
    const extension = detectImageExtension(file.buffer);
    if (!extension) {
      res.status(400).json({ sucesso: false, mensagem: 'Envie a foto em JPG, PNG ou WebP.' });
      return;
    }

    const user = await User.findById(req.user?._id);
    if (!user) {
      res.status(404).json({ sucesso: false, mensagem: 'Usuário não encontrado.' });
      return;
    }

    const anterior = user.avatarUrl;
    user.avatarUrl = await savePhoto(file.buffer, extension, user._id.toString(), 'avatars');
    await user.save();
    if (anterior) await removePhotos([anterior]);

    res.status(200).json({ sucesso: true, mensagem: 'Foto atualizada!', dados: user });
  } catch (error: any) {
    res.status(500).json({ sucesso: false, mensagem: error.message || 'Erro ao enviar a foto.' });
  }
};

// @desc    Remover a foto de perfil
// @route   DELETE /api/auth/avatar
// @access  Privado
export const removeAvatar = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const user = await User.findById(req.user?._id);
    if (!user) {
      res.status(404).json({ sucesso: false, mensagem: 'Usuário não encontrado.' });
      return;
    }

    const anterior = user.avatarUrl;
    user.avatarUrl = '';
    await user.save();
    if (anterior) await removePhotos([anterior]);

    res.status(200).json({ sucesso: true, mensagem: 'Foto removida.', dados: user });
  } catch (error: any) {
    res.status(500).json({ sucesso: false, mensagem: error.message || 'Erro ao remover a foto.' });
  }
};

// @desc    Seguir ou deixar de seguir um atleta
// @route   POST /api/auth/users/:id/toggle-follow
// @access  Privado
export const toggleFollow = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({ sucesso: false, mensagem: 'Não autorizado' });
      return;
    }

    const { id } = req.params;
    const meId = req.user._id;

    if (id === meId.toString()) {
      res.status(400).json({ sucesso: false, mensagem: 'Você não pode seguir a si mesmo.' });
      return;
    }

    const alvo = await User.findById(id).select('_id');
    if (!alvo) {
      res.status(404).json({ sucesso: false, mensagem: 'Atleta não encontrado.' });
      return;
    }

    const jaSegue = (await User.exists({ _id: meId, seguindo: alvo._id })) !== null;
    const aviso = { destinatario: alvo._id, autor: meId, tipo: 'seguidor' as const };

    if (jaSegue) {
      await Promise.all([
        User.updateOne({ _id: meId }, { $pull: { seguindo: alvo._id } }),
        User.updateOne({ _id: alvo._id }, { $pull: { seguidores: meId } }),
      ]);
      await removeNotifications(aviso);
    } else {
      await Promise.all([
        User.updateOne({ _id: meId }, { $addToSet: { seguindo: alvo._id } }),
        User.updateOne({ _id: alvo._id }, { $addToSet: { seguidores: meId } }),
      ]);
      await notify(aviso);
    }

    const atualizado = await User.findById(alvo._id).select('seguidores');

    res.status(200).json({
      sucesso: true,
      seguindo: !jaSegue,
      totalSeguidores: atualizado?.seguidores.length ?? 0,
    });
  } catch (error: any) {
    res.status(500).json({
      sucesso: false,
      mensagem: error.message || 'Erro ao atualizar seguidores.',
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
