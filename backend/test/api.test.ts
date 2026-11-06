// Testes de integração da API contra um MongoDB real: npm test
// O banco é apagado a cada execução, por isso o nome precisa terminar em _test.
import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import { createServer, Server } from 'node:http';
import { AddressInfo } from 'node:net';
import mongoose from 'mongoose';
import app from '../src/app';
import { removePhotos } from '../src/middlewares/uploadMiddleware';
import { News } from '../src/models/News';
import { NewsSource } from '../src/models/NewsSource';
import { User } from '../src/models/User';
import { backfillNewsSources, Fetcher, syncNewsSources } from '../src/services/newsSyncService';

const MONGO_URI = process.env.TEST_MONGODB_URI || 'mongodb://127.0.0.1:27017/runnersrun_test';
process.env.JWT_SECRET = 'segredo-de-teste';

const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M/wHwAEAQH/7yMK/gAAAABJRU5ErkJggg==',
  'base64'
);

let server: Server;
let origin = '';
let sequence = 0;
const uploaded: string[] = [];

interface ApiResult {
  status: number;
  json: any;
}

const api = async (method: string, path: string, token?: string, body?: unknown): Promise<ApiResult> => {
  const response = await fetch(`${origin}/api${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: response.status, json: await response.json() };
};

const upload = async (token: string | undefined, files: [Buffer, string, string][]): Promise<ApiResult> => {
  const form = new FormData();
  for (const [data, name, type] of files) form.append('fotos', new Blob([data], { type }), name);
  const response = await fetch(`${origin}/api/workouts/photos`, {
    method: 'POST',
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    body: form,
  });
  const json: any = await response.json();
  if (response.status === 201) uploaded.push(...json.dados);
  return { status: response.status, json };
};

const newUser = async (tipo?: string): Promise<{ id: string; token: string; email: string }> => {
  sequence += 1;
  const email = `atleta${sequence}@teste.com`;
  const { json } = await api('POST', '/auth/register', undefined, {
    nome: `Atleta ${sequence}`,
    email,
    senha: 'senha-de-teste',
    ...(tipo ? { tipo } : {}),
  });
  return { id: json.dados._id, token: json.dados.token, email };
};

// O cadastro público nunca cria admin: a promoção é feita direto no banco.
const newAdmin = async () => {
  const admin = await newUser();
  await User.updateOne({ _id: admin.id }, { tipo: 'admin' });
  return admin;
};

const WORKOUT = { titulo: 'Treino', distanciaKm: 10, duracaoSegundos: 3000 };
const RACE = {
  nome: 'Corrida de Teste',
  data: '2030-01-10T09:00:00.000Z',
  local: { cidade: 'Parauapebas', estado: 'PA' },
  distancias: [{ distanciaKm: 5 }],
};

before(async () => {
  await mongoose.connect(MONGO_URI);
  assert.match(mongoose.connection.name, /_test$/, 'Os testes só rodam em banco terminado em _test.');
  await mongoose.connection.dropDatabase();
  await User.init();
  await new Promise<void>((resolve) => {
    server = app.listen(0, resolve);
  });
  origin = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});

after(async () => {
  await removePhotos(uploaded);
  await new Promise((resolve) => server.close(resolve));
  await mongoose.connection.dropDatabase();
  await mongoose.disconnect();
});

describe('troca de senha', () => {
  const SENHA = 'senha-de-teste';

  it('troca a senha, invalida o token antigo e o novo funciona', async () => {
    const { token, email } = await newUser();
    // O token guarda a hora em segundos: é preciso passar para o segundo seguinte.
    await new Promise((resolve) => setTimeout(resolve, 1100));

    const changed = await api('PUT', '/auth/password', token, { senhaAtual: SENHA, novaSenha: 'senha-nova' });
    assert.equal(changed.status, 200);
    assert.equal((await api('GET', '/auth/me', token)).status, 401);
    assert.equal((await api('GET', '/auth/me', changed.json.token)).status, 200);

    assert.equal((await api('POST', '/auth/login', undefined, { email, senha: SENHA })).status, 401);
    assert.equal((await api('POST', '/auth/login', undefined, { email, senha: 'senha-nova' })).status, 200);
    assert.notEqual((await User.findOne({ email }).select('+senha'))?.senha, 'senha-nova');
  });

  it('senha atual errada responde 400, para não encerrar a sessão no app', async () => {
    const { token } = await newUser();
    const wrong = await api('PUT', '/auth/password', token, { senhaAtual: 'errada', novaSenha: 'senha-nova' });
    assert.equal(wrong.status, 400);
    assert.equal((await api('GET', '/auth/me', token)).status, 200);
  });

  it('recusa nova senha inválida e pedido sem login', async () => {
    const { token } = await newUser();
    const send = (body: unknown, who?: string) => api('PUT', '/auth/password', who, body);
    assert.equal((await send({ senhaAtual: SENHA, novaSenha: '123' }, token)).status, 400);
    assert.equal((await send({ senhaAtual: SENHA, novaSenha: SENHA }, token)).status, 400);
    assert.equal((await send({ senhaAtual: SENHA }, token)).status, 400);
    assert.equal((await send({ senhaAtual: { $ne: '' }, novaSenha: 'senha-nova' }, token)).status, 400);
    assert.equal((await send({ senhaAtual: SENHA, novaSenha: 'senha-nova' })).status, 401);
    assert.equal((await api('GET', '/auth/me', token)).status, 200);
  });
});

describe('foto de perfil', () => {
  const sendAvatar = async (token: string | undefined, data: Buffer = PNG): Promise<ApiResult> => {
    const form = new FormData();
    form.append('foto', new Blob([new Uint8Array(data)], { type: 'image/png' }), 'foto.png');
    const response = await fetch(`${origin}/api/auth/avatar`, {
      method: 'POST',
      headers: token ? { Authorization: `Bearer ${token}` } : {},
      body: form,
    });
    const json: any = await response.json();
    if (response.status === 200) uploaded.push(json.dados.avatarUrl);
    return { status: response.status, json };
  };

  it('envia, troca apagando a anterior e remove', async () => {
    const { token, id } = await newUser();
    const sent = (await sendAvatar(token)).json.dados;
    const first = sent.avatarUrl;
    assert.equal(sent.senha, undefined);
    assert.match(first, new RegExp(`^/uploads/avatars/${id}-`));
    assert.equal((await fetch(`${origin}${first}`)).status, 200);

    const second = (await sendAvatar(token)).json.dados.avatarUrl;
    assert.notEqual(second, first);
    assert.equal((await fetch(`${origin}${first}`)).status, 404);
    assert.equal((await api('GET', `/auth/profile/${id}`)).json.dados.avatarUrl, second);

    const removed = await api('DELETE', '/auth/avatar', token);
    assert.equal(removed.status, 200);
    assert.equal(removed.json.dados.avatarUrl, '');
    assert.equal((await fetch(`${origin}${second}`)).status, 404);
  });

  it('recusa arquivo que não é imagem, grande demais ou sem login', async () => {
    const { token } = await newUser();
    assert.equal((await sendAvatar(token, Buffer.from('<svg/>'))).status, 400);
    assert.equal((await sendAvatar(token, Buffer.concat([PNG, Buffer.alloc(6 * 1024 * 1024)]))).status, 400);
    assert.equal((await sendAvatar(undefined)).status, 401);
    assert.equal((await api('DELETE', '/auth/avatar')).status, 401);
  });

  it('o link da foto não pode ser definido pelo perfil nem pelo cadastro', async () => {
    const { token, id } = await newUser();
    await api('PUT', '/auth/profile', token, { avatarUrl: 'https://exemplo.com/rastreador.png' });
    assert.equal((await api('GET', `/auth/profile/${id}`)).json.dados.avatarUrl, '');

    const created = await api('POST', '/auth/register', undefined, {
      nome: 'Com link',
      email: 'com-link@teste.com',
      senha: 'senha-de-teste',
      avatarUrl: 'https://exemplo.com/rastreador.png',
    });
    assert.equal(created.json.dados.avatarUrl, '');
  });
});

describe('autenticação', () => {
  it('não deixa ninguém se cadastrar como admin', async () => {
    const { id } = await newUser('admin');
    const saved = await User.findById(id);
    assert.equal(saved?.tipo, 'atleta');
  });

  it('permite cadastro como organizador', async () => {
    const { id } = await newUser('organizador');
    assert.equal((await User.findById(id))?.tipo, 'organizador');
  });

  it('aceita domínios de e-mail longos', async () => {
    const { status } = await api('POST', '/auth/register', undefined, {
      nome: 'Tech',
      email: 'pessoa+corrida@empresa.technology',
      senha: 'senha-de-teste',
    });
    assert.equal(status, 201);
  });

  it('recusa e-mail inválido e senha curta sem erro 500', async () => {
    const invalid = await api('POST', '/auth/register', undefined, { nome: 'X', email: 'sem-arroba', senha: '123456' });
    assert.equal(invalid.status, 400);
    const short = await api('POST', '/auth/register', undefined, { nome: 'X', email: 'x@teste.com', senha: '123' });
    assert.equal(short.status, 400);
  });

  it('recusa e-mail repetido, mesmo com outra caixa', async () => {
    const { email } = await newUser();
    const { status } = await api('POST', '/auth/register', undefined, {
      nome: 'Dup',
      email: email.toUpperCase(),
      senha: 'senha-de-teste',
    });
    assert.equal(status, 400);
  });

  it('faz login com a senha certa e recusa a errada', async () => {
    const { email } = await newUser();
    assert.equal((await api('POST', '/auth/login', undefined, { email, senha: 'senha-de-teste' })).status, 200);
    assert.equal((await api('POST', '/auth/login', undefined, { email, senha: 'errada-123' })).status, 401);
  });

  it('não aceita objetos no lugar de e-mail e senha', async () => {
    const { status } = await api('POST', '/auth/login', undefined, { email: { $gt: '' }, senha: { $gt: '' } });
    assert.equal(status, 400);
  });

  it('nunca devolve a senha', async () => {
    const { id, token } = await newUser();
    const me = await api('GET', '/auth/me', token);
    const profile = await api('GET', `/auth/profile/${id}`);
    assert.equal(me.json.dados.senha, undefined);
    assert.equal(profile.json.dados.senha, undefined);
    assert.equal(profile.json.dados.email, undefined);
  });

  it('salva recordes pessoais sem apagar os anteriores', async () => {
    const { token } = await newUser();
    await api('PUT', '/auth/profile', token, { recordesPessoais: { rp5k: '22:41' } });
    const { json } = await api('PUT', '/auth/profile', token, { bio: 'Oi', recordesPessoais: { rp10k: '48:32' } });
    assert.equal(json.dados.recordesPessoais.rp5k, '22:41');
    assert.equal(json.dados.recordesPessoais.rp10k, '48:32');
    assert.equal(json.dados.bio, 'Oi');
  });

  it('o perfil não muda o tipo da conta', async () => {
    const { id, token } = await newUser();
    await api('PUT', '/auth/profile', token, { tipo: 'admin', estatisticas: { totalKm: 9999 } });
    const saved = await User.findById(id);
    assert.equal(saved?.tipo, 'atleta');
    assert.equal(saved?.estatisticas.totalKm, 0);
  });
});

describe('seguidores', () => {
  it('segue, conta nos dois lados, avisa e deixa de seguir', async () => {
    const a = await newUser();
    const b = await newUser();

    const follow = await api('POST', `/auth/users/${b.id}/toggle-follow`, a.token);
    assert.equal(follow.json.seguindo, true);
    assert.equal(follow.json.totalSeguidores, 1);

    const profile = await api('GET', `/auth/profile/${b.id}`);
    assert.equal(profile.json.dados.seguidores, 1);
    assert.equal(profile.json.dados.seguindo, 0);
    assert.deepEqual((await api('GET', '/auth/me', a.token)).json.dados.seguindo, [b.id]);

    const notices = await api('GET', '/notifications', b.token);
    assert.equal(notices.json.dados[0].tipo, 'seguidor');
    assert.equal(notices.json.dados[0].autor._id, a.id);

    const unfollow = await api('POST', `/auth/users/${b.id}/toggle-follow`, a.token);
    assert.equal(unfollow.json.seguindo, false);
    assert.equal(unfollow.json.totalSeguidores, 0);
    assert.equal((await api('GET', '/notifications', b.token)).json.total, 0);
  });

  it('não permite seguir a si mesmo nem usuário inexistente', async () => {
    const a = await newUser();
    assert.equal((await api('POST', `/auth/users/${a.id}/toggle-follow`, a.token)).status, 400);
    const missing = new mongoose.Types.ObjectId().toString();
    assert.equal((await api('POST', `/auth/users/${missing}/toggle-follow`, a.token)).status, 404);
    assert.equal((await api('POST', '/auth/users/abc/toggle-follow', a.token)).status, 404);
    assert.equal((await api('POST', `/auth/users/${a.id}/toggle-follow`)).status, 401);
  });
});

describe('notificações', () => {
  it('curtida e comentário avisam o dono, com treino e autor', async () => {
    const owner = await newUser();
    const fan = await newUser();
    const workout = (await api('POST', '/workouts', owner.token, WORKOUT)).json.dados;

    await api('POST', `/workouts/${workout._id}/like`, fan.token);
    await api('POST', `/workouts/${workout._id}/comments`, fan.token, { texto: 'Boa!' });

    const { json } = await api('GET', '/notifications', owner.token);
    assert.equal(json.naoLidas, 2);
    assert.deepEqual(json.dados.map((n: any) => n.tipo).sort(), ['comentario', 'curtida']);
    assert.equal(json.dados[0].treino.titulo, 'Treino');
    assert.equal(json.dados[0].autor.nome.startsWith('Atleta'), true);
    assert.equal((await api('GET', '/notifications/unread-count', owner.token)).json.naoLidas, 2);
  });

  it('as próprias ações não geram aviso', async () => {
    const owner = await newUser();
    const workout = (await api('POST', '/workouts', owner.token, WORKOUT)).json.dados;
    await api('POST', `/workouts/${workout._id}/like`, owner.token);
    await api('POST', `/workouts/${workout._id}/comments`, owner.token, { texto: 'Eu mesmo' });
    assert.equal((await api('GET', '/notifications', owner.token)).json.total, 0);
  });

  it('desfazer a ação remove o aviso', async () => {
    const owner = await newUser();
    const fan = await newUser();
    const workout = (await api('POST', '/workouts', owner.token, WORKOUT)).json.dados;

    await api('POST', `/workouts/${workout._id}/like`, fan.token);
    await api('POST', `/workouts/${workout._id}/like`, fan.token);
    assert.equal((await api('GET', '/notifications', owner.token)).json.total, 0);

    const comments = (await api('POST', `/workouts/${workout._id}/comments`, fan.token, { texto: 'Oi' })).json.dados;
    await api('DELETE', `/workouts/${workout._id}/comments/${comments[0]._id}`, fan.token);
    assert.equal((await api('GET', '/notifications', owner.token)).json.total, 0);
  });

  it('excluir o treino remove os avisos dele', async () => {
    const owner = await newUser();
    const fan = await newUser();
    const workout = (await api('POST', '/workouts', owner.token, WORKOUT)).json.dados;
    await api('POST', `/workouts/${workout._id}/like`, fan.token);
    await api('DELETE', `/workouts/${workout._id}`, owner.token);
    assert.equal((await api('GET', '/notifications', owner.token)).json.total, 0);
  });

  it('cada pessoa vê só as suas, e marcar como lidas zera a contagem', async () => {
    const owner = await newUser();
    const fan = await newUser();
    const workout = (await api('POST', '/workouts', owner.token, WORKOUT)).json.dados;
    await api('POST', `/workouts/${workout._id}/like`, fan.token);

    assert.equal((await api('GET', '/notifications', fan.token)).json.total, 0);
    assert.equal((await api('GET', '/notifications')).status, 401);

    await api('POST', '/notifications/read-all', owner.token);
    const { json } = await api('GET', '/notifications', owner.token);
    assert.equal(json.naoLidas, 0);
    assert.equal(json.total, 1);
  });
});

describe('provas', () => {
  it('atleta não cria prova', async () => {
    const { token } = await newUser();
    assert.equal((await api('POST', '/races', token, RACE)).status, 403);
  });

  it('só o organizador que criou altera ou exclui', async () => {
    const owner = await newUser('organizador');
    const other = await newUser('organizador');
    const race = (await api('POST', '/races', owner.token, RACE)).json.dados;
    assert.equal(race.criadoPor, owner.id);

    assert.equal((await api('PUT', `/races/${race._id}`, other.token, { nome: 'Invadida' })).status, 403);
    assert.equal((await api('DELETE', `/races/${race._id}`, other.token)).status, 403);

    const updated = await api('PUT', `/races/${race._id}`, owner.token, { nome: 'Novo nome' });
    assert.equal(updated.json.dados.nome, 'Novo nome');
    assert.equal((await api('DELETE', `/races/${race._id}`, owner.token)).status, 200);
  });

  it('admin pode alterar qualquer prova', async () => {
    const owner = await newUser('organizador');
    const admin = await newUser();
    await User.updateOne({ _id: admin.id }, { tipo: 'admin' });
    const race = (await api('POST', '/races', owner.token, RACE)).json.dados;
    assert.equal((await api('PUT', `/races/${race._id}`, admin.token, { nome: 'Pelo admin' })).status, 200);
  });

  it('o cliente não escolhe dono nem confirmados', async () => {
    const owner = await newUser('organizador');
    const other = await newUser('organizador');
    const fake = new mongoose.Types.ObjectId().toString();
    const race = (
      await api('POST', '/races', owner.token, { ...RACE, criadoPor: other.id, participantesConfirmados: [fake] })
    ).json.dados;
    assert.equal(race.criadoPor, owner.id);
    assert.deepEqual(race.participantesConfirmados, []);

    const updated = await api('PUT', `/races/${race._id}`, owner.token, { criadoPor: other.id });
    assert.equal(updated.json.dados.criadoPor, owner.id);
  });

  it('recusa link que não seja http ou https', async () => {
    const { token } = await newUser('organizador');
    const bad = await api('POST', '/races', token, { ...RACE, linkInscricao: 'javascript:alert(1)' });
    assert.equal(bad.status, 400);
    const good = await api('POST', '/races', token, { ...RACE, linkInscricao: 'https://exemplo.com/inscricao' });
    assert.equal(good.status, 201);
  });

  it('busca trata símbolos como texto e limita a paginação', async () => {
    const { token } = await newUser('organizador');
    await api('POST', '/races', token, { ...RACE, nome: 'Corrida (Noturna)' });
    const found = await api('GET', `/races?busca=${encodeURIComponent('(Noturna)')}`);
    assert.equal(found.status, 200);
    assert.equal(found.json.dados.length, 1);
    assert.equal((await api('GET', `/races?busca=${encodeURIComponent('(')}`)).status, 200);
    assert.equal((await api('GET', '/races?limit=999999&page=-3')).status, 200);
  });

  it('id inválido responde 404', async () => {
    assert.equal((await api('GET', '/races/abc')).status, 404);
    assert.equal((await api('GET', '/workouts/abc')).status, 404);
    assert.equal((await api('GET', '/news/abc')).status, 404);
  });

  it('confirma presença e salva prova nos dois sentidos', async () => {
    const organizer = await newUser('organizador');
    const athlete = await newUser();
    const race = (await api('POST', '/races', organizer.token, RACE)).json.dados;

    const going = await api('POST', `/auth/races/${race._id}/toggle-presence`, athlete.token);
    assert.equal(going.json.confirmado, true);
    assert.equal((await api('GET', `/races/${race._id}`)).json.dados.participantesConfirmados[0].nome.length > 0, true);
    assert.equal((await api('POST', `/auth/races/${race._id}/toggle-presence`, athlete.token)).json.confirmado, false);

    assert.equal((await api('POST', `/auth/races/${race._id}/toggle-save`, athlete.token)).json.salva, true);
    assert.equal((await api('GET', '/auth/me', athlete.token)).json.dados.corridasSalvas[0].nome, RACE.nome);
  });
});

describe('cadastro de provas', () => {
  const uploadCover = async (token: string, data: Buffer = PNG): Promise<ApiResult> => {
    const form = new FormData();
    form.append('capa', new Blob([data], { type: 'image/png' }), 'capa.png');
    const response = await fetch(`${origin}/api/races/cover`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: form,
    });
    const json: any = await response.json();
    if (response.status === 201) uploaded.push(json.dados);
    return { status: response.status, json };
  };

  it('dá mensagens claras para dados inválidos', async () => {
    const { token } = await newUser('organizador');
    const cases: [object, RegExp][] = [
      [{ nome: 'X' }, /nome/],
      [{ data: 'ontem' }, /data/],
      [{ data: '2020-01-01T09:00:00.000Z' }, /passado/],
      [{ local: { cidade: '', estado: 'PA' } }, /cidade/],
      [{ local: { cidade: 'Marabá', estado: 'Pará' } }, /UF/],
      [{ distancias: [] }, /distância/],
      [{ distancias: [{ distanciaKm: 0 }] }, /distâncias/],
      [{ distancias: [{ distanciaKm: 5 }, { distanciaKm: 5 }] }, /repetidas/],
      [{ distancias: [{ distanciaKm: 5, altimetria: -1 }] }, /elevação/],
      [{ horarioLargada: '25:00' }, /horário/],
    ];
    for (const [change, message] of cases) {
      const { status, json } = await api('POST', '/races', token, { ...RACE, ...change });
      assert.equal(status, 400, JSON.stringify(change));
      assert.match(json.mensagem, message);
    }
  });

  it('usa o nome da conta como organizador', async () => {
    const owner = await newUser('organizador');
    const { json } = await api('POST', '/races', owner.token, { ...RACE, organizador: { contato: '(94) 90000-0000' } });
    assert.match(json.dados.organizador.nome, /^Atleta/);
    assert.equal(json.dados.organizador.contato, '(94) 90000-0000');
  });

  it('lista em Minhas provas só as da própria conta, em ordem de data', async () => {
    const owner = await newUser('organizador');
    const other = await newUser('organizador');
    const athlete = await newUser();
    await api('POST', '/races', owner.token, { ...RACE, nome: 'Depois', data: '2031-05-01T09:00:00.000Z' });
    await api('POST', '/races', owner.token, { ...RACE, nome: 'Antes', data: '2030-05-01T09:00:00.000Z' });
    await api('POST', '/races', other.token, { ...RACE, nome: 'Outra' });

    const { json } = await api('GET', '/races/mine', owner.token);
    assert.deepEqual(json.dados.map((r: any) => r.nome), ['Antes', 'Depois']);
    assert.equal((await api('GET', '/races/mine', athlete.token)).status, 403);
    assert.equal((await api('GET', '/races/mine')).status, 401);
  });

  it('edita passando por prazos antigos e mantém o que não foi enviado', async () => {
    const owner = await newUser('organizador');
    const race = (await api('POST', '/races', owner.token, { ...RACE, preco: 'R$ 80,00' })).json.dados;
    const past = await api('PUT', `/races/${race._id}`, owner.token, {
      data: '2020-01-01T09:00:00.000Z',
      status: 'concluida',
      posCorrida: { linkResultadosChip: 'https://exemplo.com/resultados' },
    });
    assert.equal(past.status, 200);
    assert.equal(past.json.dados.status, 'concluida');
    assert.equal(past.json.dados.preco, 'R$ 80,00');
    assert.equal(past.json.dados.posCorrida.linkResultadosChip, 'https://exemplo.com/resultados');
    assert.equal((await api('PUT', `/races/${race._id}`, owner.token, { distancias: [] })).status, 400);
  });

  describe('percurso', () => {
    const PERCURSO = {
      pontos: [{ lat: -6, lng: -49 }, { lat: -6.1, lng: -49.1 }],
      trechos: [{ coordenadas: [[-49, -6, 200], [-49.1, -6.1, 210]], subidaM: 10 }],
    };
    const newRace = async (token: string) =>
      (await api('POST', '/races', token, { ...RACE, distancias: [{ distanciaKm: 5 }, { distanciaKm: 10 }] })).json.dados;
    const path = (id: string, km: number | string = 5) => `/races/${id}/distancias/${km}/percurso`;
    const of = (race: any, km: number) => race.distancias.find((d: any) => d.distanciaKm === km);

    it('salva calculando a distância e só aparece ao abrir a prova', async () => {
      const owner = await newUser('organizador');
      const race = await newRace(owner.token);
      const saved = await api('PUT', path(race._id), owner.token, { ...PERCURSO, distanciaM: 1, temLinhaReta: true });
      assert.equal(saved.status, 200);
      assert.ok(of(saved.json.dados, 5).percurso.distanciaM > 10000);
      assert.equal(of(saved.json.dados, 5).percurso.subidaM, 10);
      assert.equal(of(saved.json.dados, 5).percurso.temLinhaReta, false);

      const opened = (await api('GET', `/races/${race._id}`)).json.dados;
      assert.equal(of(opened, 5).percurso.pontos.length, 2);
      assert.equal(of(opened, 10).percurso, undefined);

      const listed = (await api('GET', '/races?limit=60')).json.dados.find((r: any) => r._id === race._id);
      assert.equal(of(listed, 5).percurso, undefined);
      const mine = (await api('GET', '/races/mine', owner.token)).json.dados.find((r: any) => r._id === race._id);
      assert.equal(of(mine, 5).percurso, undefined);
    });

    it('editar as distâncias preserva o percurso das que continuam', async () => {
      const owner = await newUser('organizador');
      const race = await newRace(owner.token);
      await api('PUT', path(race._id), owner.token, PERCURSO);
      const { json } = await api('PUT', `/races/${race._id}`, owner.token, {
        distancias: [{ distanciaKm: 5, altimetria: 40 }, { distanciaKm: 21 }],
      });
      assert.equal(of(json.dados, 5).altimetria, 40);
      assert.equal(of(json.dados, 5).percurso.pontos.length, 2);
      assert.deepEqual(json.dados.distancias.map((d: any) => d.distanciaKm), [5, 21]);
    });

    it('não aceita percurso sem validação pelos dados da prova', async () => {
      const owner = await newUser('organizador');
      const invalido = { pontos: 'x' };
      const created = await api('POST', '/races', owner.token, {
        ...RACE,
        distancias: [{ distanciaKm: 5, percurso: invalido }],
      });
      assert.equal(created.status, 201);
      assert.equal(of(created.json.dados, 5).percurso, undefined);
      const updated = await api('PUT', `/races/${created.json.dados._id}`, owner.token, {
        distancias: [{ distanciaKm: 5, percurso: invalido }],
      });
      assert.equal(updated.status, 200);
      assert.equal(of(updated.json.dados, 5).percurso, undefined);
    });

    it('remove o percurso', async () => {
      const owner = await newUser('organizador');
      const race = await newRace(owner.token);
      await api('PUT', path(race._id), owner.token, PERCURSO);
      const removed = await api('DELETE', path(race._id), owner.token);
      assert.equal(removed.status, 200);
      assert.equal(of((await api('GET', `/races/${race._id}`)).json.dados, 5).percurso, undefined);
    });

    it('recusa quem não gerencia a prova, distância inexistente e traçado inválido', async () => {
      const owner = await newUser('organizador');
      const other = await newUser('organizador');
      const athlete = await newUser();
      const race = await newRace(owner.token);

      assert.equal((await api('PUT', path(race._id), undefined, PERCURSO)).status, 401);
      assert.equal((await api('PUT', path(race._id), athlete.token, PERCURSO)).status, 403);
      assert.equal((await api('PUT', path(race._id), other.token, PERCURSO)).status, 403);
      assert.equal((await api('DELETE', path(race._id), other.token)).status, 403);
      assert.equal((await api('PUT', path(race._id, 42), owner.token, PERCURSO)).status, 404);
      assert.equal((await api('PUT', path(race._id, 'x'), owner.token, PERCURSO)).status, 404);
      assert.equal((await api('PUT', path('000000000000000000000000'), owner.token, PERCURSO)).status, 404);
      assert.equal((await api('PUT', path(race._id), owner.token, { ...PERCURSO, trechos: [] })).status, 400);
    });
  });

  it('valida a capa, troca e apaga o arquivo antigo', async () => {
    const owner = await newUser('organizador');
    const other = await newUser('organizador');
    const athlete = await newUser();

    assert.equal((await uploadCover(athlete.token)).status, 403);
    assert.equal((await uploadCover(owner.token, Buffer.from('<svg/>'))).status, 400);
    assert.equal((await uploadCover(owner.token, Buffer.concat([PNG, Buffer.alloc(6 * 1024 * 1024)]))).status, 400);

    const first = (await uploadCover(owner.token)).json.dados;
    assert.equal((await api('POST', '/races', other.token, { ...RACE, bannerUrl: first })).status, 400);
    assert.equal((await api('POST', '/races', owner.token, { ...RACE, bannerUrl: 'https://exemplo.com/x.png' })).status, 400);

    const race = (await api('POST', '/races', owner.token, { ...RACE, bannerUrl: first })).json.dados;
    assert.equal(race.bannerUrl, first);
    assert.equal((await fetch(origin + first)).status, 200);

    // Salvar sem mudar a capa não apaga o arquivo.
    assert.equal((await api('PUT', `/races/${race._id}`, owner.token, { bannerUrl: first })).status, 200);
    assert.equal((await fetch(origin + first)).status, 200);

    const second = (await uploadCover(owner.token)).json.dados;
    assert.equal((await api('PUT', `/races/${race._id}`, owner.token, { bannerUrl: second })).status, 200);
    assert.equal((await fetch(origin + first)).status, 404);

    assert.equal((await api('DELETE', `/races/${race._id}`, owner.token)).status, 200);
    assert.equal((await fetch(origin + second)).status, 404);
  });

  it('excluir a prova tira ela das salvas de quem favoritou', async () => {
    const owner = await newUser('organizador');
    const fan = await newUser();
    const race = (await api('POST', '/races', owner.token, RACE)).json.dados;
    await api('POST', `/auth/races/${race._id}/toggle-save`, fan.token);
    await api('DELETE', `/races/${race._id}`, owner.token);
    assert.deepEqual((await api('GET', '/auth/me', fan.token)).json.dados.corridasSalvas, []);
  });
});

describe('notícias', () => {
  it('só organizador ou admin publica, e recusa categoria inválida', async () => {
    const athlete = await newUser();
    const organizer = await newUser('organizador');
    const body = { titulo: 'Título', conteudo: 'Texto', categoria: 'Aviso' };
    assert.equal((await api('POST', '/news', athlete.token, body)).status, 403);
    assert.equal((await api('POST', '/news', organizer.token, { ...body, categoria: 'Inexistente' })).status, 400);
    const created = await api('POST', '/news', organizer.token, body);
    assert.equal(created.status, 201);
    assert.equal((await api('GET', `/news/${created.json.dados._id}`)).json.dados.titulo, 'Título');
    assert.equal((await api('GET', '/news?categoria=Aviso')).json.dados.length >= 1, true);
  });

  describe('edição e exclusão', () => {
    const BODY = { titulo: 'Título', conteudo: 'Texto', categoria: 'Aviso' };

    it('quem publicou edita só os campos permitidos', async () => {
      const owner = await newUser('organizador');
      const created = (await api('POST', '/news', owner.token, BODY)).json.dados;
      assert.equal(created.criadoPor, owner.id);

      const updated = await api('PUT', `/news/${created._id}`, owner.token, {
        titulo: 'Novo título',
        destaque: true,
        autor: 'Outra pessoa',
        criadoPor: '000000000000000000000000',
        linkOriginal: 'https://exemplo.com/forjado',
      });
      assert.equal(updated.status, 200);
      assert.equal(updated.json.dados.titulo, 'Novo título');
      assert.equal(updated.json.dados.conteudo, 'Texto');
      assert.equal(updated.json.dados.destaque, true);
      assert.equal(updated.json.dados.autor, created.autor);
      assert.equal(updated.json.dados.criadoPor, owner.id);
      assert.equal(updated.json.dados.linkOriginal, undefined);
    });

    it('recusa dados inválidos', async () => {
      const owner = await newUser('organizador');
      const { _id } = (await api('POST', '/news', owner.token, BODY)).json.dados;
      assert.equal((await api('PUT', `/news/${_id}`, owner.token, { titulo: '   ' })).status, 400);
      assert.equal((await api('PUT', `/news/${_id}`, owner.token, { conteudo: 7 })).status, 400);
      assert.equal((await api('PUT', `/news/${_id}`, owner.token, { categoria: 'Inexistente' })).status, 400);
    });

    it('só quem publicou ou um admin altera', async () => {
      const owner = await newUser('organizador');
      const other = await newUser('organizador');
      const athlete = await newUser();
      const admin = await newAdmin();
      const { _id } = (await api('POST', '/news', owner.token, BODY)).json.dados;

      assert.equal((await api('PUT', `/news/${_id}`, undefined, BODY)).status, 401);
      assert.equal((await api('PUT', `/news/${_id}`, athlete.token, BODY)).status, 403);
      assert.equal((await api('PUT', `/news/${_id}`, other.token, BODY)).status, 403);
      assert.equal((await api('DELETE', `/news/${_id}`, other.token)).status, 403);
      assert.equal((await api('PUT', `/news/${_id}`, admin.token, { titulo: 'Corrigido' })).status, 200);

      assert.equal((await api('DELETE', `/news/${_id}`, owner.token)).status, 200);
      assert.equal((await api('GET', `/news/${_id}`)).status, 404);
      assert.equal((await api('DELETE', `/news/${_id}`, owner.token)).status, 404);
    });

    it('notícia antiga, sem dono, só o admin altera; matéria externa nem o admin', async () => {
      const organizer = await newUser('organizador');
      const admin = await newAdmin();
      const old = await News.create({ titulo: 'Antiga', conteudo: 'Texto' });
      assert.equal((await api('PUT', `/news/${old._id}`, organizer.token, { titulo: 'X' })).status, 403);
      assert.equal((await api('PUT', `/news/${old._id}`, admin.token, { titulo: 'X' })).status, 200);

      const external = await News.create({
        titulo: 'Externa',
        conteudo: 'Resumo',
        linkOriginal: `https://exemplo.com/${old._id}`,
      });
      assert.equal((await api('PUT', `/news/${external._id}`, admin.token, { titulo: 'X' })).status, 403);
      assert.equal((await api('DELETE', `/news/${external._id}`, admin.token)).status, 403);
    });
  });
});

describe('notícias de fontes externas', () => {
  const NOW = new Date('2026-11-05T12:00:00Z');
  const rss = (items: string) => `<rss version="2.0"><channel>${items}</channel></rss>`;
  const item = (slug: string, title: string, date: string, extra = '') =>
    `<item><title>${title}</title><link>https://webrun.com.br/${slug}/</link><pubDate>${date}</pubDate><description>Resumo de ${slug}</description>${extra}</item>`;

  // Só o Webrun responde; as outras fontes ficam com feed vazio.
  const fakeFetcher = (feed: string, requests: string[] = []): Fetcher => async (url) => {
    requests.push(url);
    if (url === 'https://webrun.com.br/feed/') return feed;
    if (url.endsWith('/feed/')) return rss('');
    return '<meta property="og:image" content="https://webrun.com.br/capa.jpg">';
  };
  const sync = (feed: string, requests?: string[]) =>
    syncNewsSources({ force: true, fetcher: fakeFetcher(feed, requests), pageDelayMs: 0, now: NOW });

  const admin = async () => {
    const user = await newUser();
    await User.updateOne({ _id: user.id }, { tipo: 'admin' });
    return user;
  };
  const reset = () => Promise.all([News.deleteMany({ fonteId: { $exists: true } }), NewsSource.deleteMany({})]);
  const titles = async () => (await api('GET', '/news')).json.dados.map((n: { titulo: string }) => n.titulo);

  it('importa resumo, crédito, link e capa, sem repetir a matéria', async () => {
    await reset();
    const requests: string[] = [];
    const feed = rss(
      item('primeira', 'Primeira matéria', 'Wed, 04 Nov 2026 10:00:00 +0000', '<content:encoded>TEXTO INTEIRO</content:encoded>')
    );
    const [webrun] = await sync(feed, requests);
    assert.equal(webrun.novas, 1);

    const news = (await api('GET', '/news')).json.dados.find((n: { titulo: string }) => n.titulo === 'Primeira matéria');
    assert.equal(news.conteudo, 'Resumo de primeira');
    assert.equal(news.fonteNome, 'Webrun');
    assert.equal(news.autor, 'Webrun');
    assert.equal(news.linkOriginal, 'https://webrun.com.br/primeira/');
    assert.equal(news.imagemUrl, 'https://webrun.com.br/capa.jpg');
    assert.equal(requests.includes('https://webrun.com.br/primeira/'), true);

    requests.length = 0;
    assert.equal((await sync(feed, requests))[0].novas, 0);
    assert.equal(requests.includes('https://webrun.com.br/primeira/'), false, 'não abre de novo matéria já conhecida');
    assert.equal(await News.countDocuments({ fonteId: 'webrun' }), 1);
  });

  it('fonte que recusa as imagens fica sem capa, inclusive nas matérias antigas', async () => {
    await reset();
    await News.create({
      titulo: 'Antiga',
      conteudo: 'R',
      linkOriginal: 'https://contrarelogio.com.br/antiga/',
      fonteId: 'contra-relogio',
      imagemUrl: 'https://contrarelogio.com.br/a.jpg',
    });
    const requests: string[] = [];
    await syncNewsSources({
      force: true,
      now: NOW,
      pageDelayMs: 0,
      fetcher: async (url) => {
        requests.push(url);
        if (url !== 'https://contrarelogio.com.br/feed/') return rss('');
        return rss(
          `<item><title>Nova</title><link>https://contrarelogio.com.br/nova/</link><pubDate>Wed, 04 Nov 2026 10:00:00 +0000</pubDate><description>R</description></item>`
        );
      },
    });
    assert.equal((await News.findOne({ titulo: 'Nova' }))?.imagemUrl, undefined);
    assert.equal((await News.findOne({ titulo: 'Antiga' }))?.imagemUrl, undefined);
    assert.equal(requests.includes('https://contrarelogio.com.br/nova/'), false, 'não abre a página atrás da capa');
  });

  it('ignora matéria antiga e link fora do domínio da fonte', async () => {
    await reset();
    const [webrun] = await sync(
      rss(
        item('velha', 'Velha', 'Wed, 23 Oct 2019 13:33:21 +0000') +
          '<item><title>Fora</title><link>https://outro.com/a/</link><description>R</description></item>'
      )
    );
    assert.equal(webrun.novas, 0);
  });

  it('a falha de uma fonte fica registrada e não apaga o que já existe', async () => {
    await reset();
    await sync(rss(item('a', 'Matéria A', 'Wed, 04 Nov 2026 10:00:00 +0000')));
    const [webrun] = await syncNewsSources({
      force: true,
      now: NOW,
      fetcher: async () => {
        throw new Error('HTTP 503');
      },
    });
    assert.equal(webrun.erro, 'HTTP 503');
    assert.equal((await NewsSource.findOne({ fonteId: 'webrun' }))?.ultimoErro, 'HTTP 503');
    assert.equal((await titles()).includes('Matéria A'), true);
  });

  it('não lê de novo uma fonte recém-lida, a menos que o admin peça', async () => {
    await reset();
    await sync(rss(''));
    const requests: string[] = [];
    const results = await syncNewsSources({ fetcher: fakeFetcher(rss(''), requests), now: NOW });
    assert.deepEqual(requests, []);
    assert.equal(results[0].pulada, true);
  });

  it('ordena próprias e externas pela data', async () => {
    await reset();
    await sync(
      rss(item('futura', 'Mais nova', 'Thu, 05 Nov 2026 11:00:00 +0000') + item('antiga', 'Mais antiga', 'Mon, 02 Nov 2026 10:00:00 +0000'))
    );
    const list = await titles();
    assert.ok(list.indexOf('Mais nova') < list.indexOf('Mais antiga'));
  });

  it('só o admin acessa as fontes e oculta matérias', async () => {
    const organizer = await newUser('organizador');
    for (const [method, path] of [
      ['GET', '/news/sources'],
      ['GET', '/news/hidden'],
      ['POST', '/news/sources/sync'],
      ['PUT', '/news/sources/webrun'],
      ['PUT', `/news/${new mongoose.Types.ObjectId()}/visibility`],
    ] as const) {
      assert.equal((await api(method, path)).status, 401, path);
      assert.equal((await api(method, path, organizer.token)).status, 403, path);
    }
  });

  it('matéria oculta some da lista e do link direto, e pode voltar', async () => {
    await reset();
    const { token } = await admin();
    await sync(rss(item('a', 'Matéria oculta', 'Wed, 04 Nov 2026 10:00:00 +0000')));
    const news = await News.findOne({ titulo: 'Matéria oculta' });
    const path = `/news/${news?._id}`;

    assert.equal((await api('PUT', `${path}/visibility`, token, { oculta: 'sim' })).status, 400);
    assert.equal((await api('PUT', `${path}/visibility`, token, { oculta: true })).status, 200);
    assert.equal((await titles()).includes('Matéria oculta'), false);
    assert.equal((await api('GET', path)).status, 404);
    assert.equal((await api('GET', '/news/hidden', token)).json.dados[0].titulo, 'Matéria oculta');

    await sync(rss(item('a', 'Matéria oculta', 'Wed, 04 Nov 2026 10:00:00 +0000')));
    assert.equal((await titles()).includes('Matéria oculta'), false, 'nova busca não traz de volta');

    assert.equal((await api('PUT', `${path}/visibility`, token, { oculta: false })).status, 200);
    assert.equal((await titles()).includes('Matéria oculta'), true);
  });

  it('fonte desligada some do app, deixa de ser lida e volta ao religar', async () => {
    await reset();
    const { token } = await admin();
    const feed = rss(item('a', 'Matéria da fonte', 'Wed, 04 Nov 2026 10:00:00 +0000'));
    await sync(feed);
    const news = await News.findOne({ titulo: 'Matéria da fonte' });

    assert.equal((await api('PUT', '/news/sources/inexistente', token, { ativa: false })).status, 404);
    assert.equal((await api('PUT', '/news/sources/webrun', token, { ativa: 'nao' })).status, 400);
    assert.equal((await api('PUT', '/news/sources/webrun', token, { ativa: false })).status, 200);
    assert.equal((await titles()).includes('Matéria da fonte'), false);
    assert.equal((await api('GET', `/news/${news?._id}`)).status, 404);

    const requests: string[] = [];
    await sync(feed, requests);
    assert.equal(requests.includes('https://webrun.com.br/feed/'), false);

    const sources = (await api('GET', '/news/sources', token)).json.dados;
    assert.equal(sources.find((s: { id: string }) => s.id === 'webrun').ativa, false);
    assert.equal(sources.length, 3);

    assert.equal((await api('PUT', '/news/sources/webrun', token, { ativa: true })).status, 200);
    assert.equal((await titles()).includes('Matéria da fonte'), true);
  });

  it('a lista é paginada, sem repetir nem pular notícia', async () => {
    await News.deleteMany({});
    await NewsSource.deleteMany({});
    await News.insertMany(
      Array.from({ length: 5 }, (_, i) => ({
        titulo: `Matéria ${i}`,
        conteudo: 'R',
        linkOriginal: `https://webrun.com.br/m${i}/`,
        fonteId: 'webrun',
        publicadoEm: new Date(Date.UTC(2026, 10, 5 - i)),
      }))
    );
    const first = (await api('GET', '/news?limit=2&page=1')).json;
    const second = (await api('GET', '/news?limit=2&page=2')).json;
    const third = (await api('GET', '/news?limit=2&page=3')).json;
    const names = (list: { titulo: string }[]) => list.map((n) => n.titulo);
    assert.deepEqual(names(first.dados), ['Matéria 0', 'Matéria 1']);
    assert.deepEqual(names(second.dados), ['Matéria 2', 'Matéria 3']);
    assert.deepEqual(names(third.dados), ['Matéria 4']);
    assert.deepEqual([first.temMais, second.temMais, third.temMais], [true, true, false]);
    assert.equal((await api('GET', '/news?limit=5')).json.temMais, false);
    assert.equal((await api('GET', '/news?limit=abc&page=-1')).status, 200);
    await reset();
  });

  describe('matérias anteriores', () => {
    const dateOf = (index: number) => new Date(NOW.getTime() - index * 86_400_000).toUTCString();
    const page = (number: number, age = number) =>
      rss(item(`p${number}`, `Página ${number}`, dateOf(age)));
    const options = (fetcher: Fetcher) => ({ fetcher, pageDelayMs: 0, feedDelayMs: 0, now: NOW });

    // Responde as páginas de cada feed; a capa vem da página da matéria.
    const pages = (handler: (page: number) => string, requests: string[] = []): Fetcher =>
      async (url) => {
        requests.push(url);
        if (!url.startsWith('https://webrun.com.br/')) {
          if (url.includes('paged=')) throw new Error('HTTP 404');
          return rss('');
        }
        const number = /paged=(\d+)/.exec(url);
        if (number) return handler(Number(number[1]));
        return '<meta property="og:image" content="https://webrun.com.br/capa.jpg">';
      };

    it('traz as páginas anteriores até o fim do feed e não repete a busca', async () => {
      await reset();
      const requests: string[] = [];
      const fetcher = pages((n) => {
        if (n > 3) throw new Error('HTTP 404');
        return page(n);
      }, requests);

      const results = await backfillNewsSources(options(fetcher));
      assert.equal(results.find((r) => r.fonteId === 'webrun')?.novas, 2);
      const stored = await News.findOne({ titulo: 'Página 2' });
      assert.equal(stored?.imagemUrl, 'https://webrun.com.br/capa.jpg');
      assert.equal((await NewsSource.findOne({ fonteId: 'webrun' }))?.historicoConcluido, true);

      requests.length = 0;
      assert.deepEqual(await backfillNewsSources(options(fetcher)), []);
      assert.deepEqual(requests, []);
    });

    it('para no teto de páginas', async () => {
      await reset();
      const requests: string[] = [];
      await backfillNewsSources(options(pages((n) => page(n), requests)));
      const read = requests.filter((url) => url.startsWith('https://webrun.com.br/feed/?paged='));
      assert.equal(read.length, 10);
      assert.equal(read.at(-1), 'https://webrun.com.br/feed/?paged=11');
    });

    it('para quando as matérias ficam antigas demais', async () => {
      await reset();
      const requests: string[] = [];
      await backfillNewsSources(options(pages((n) => page(n, n === 2 ? 1 : 400), requests)));
      assert.equal(requests.filter((url) => url.includes('webrun.com.br/feed/?paged=')).length, 2);
      assert.equal(await News.countDocuments({ fonteId: 'webrun' }), 1);
    });

    it('falha no meio fica para a próxima rodada, sem abrir de novo o que já entrou', async () => {
      await reset();
      let broken = true;
      const requests: string[] = [];
      const fetcher = pages((n) => {
        if (n === 3 && broken) throw new Error('HTTP 503');
        if (n > 3) throw new Error('HTTP 404');
        return page(n);
      }, requests);

      const failed = await backfillNewsSources(options(fetcher));
      assert.equal(failed.find((r) => r.fonteId === 'webrun')?.erro, 'HTTP 503');
      assert.equal((await NewsSource.findOne({ fonteId: 'webrun' }))?.historicoConcluido ?? false, false);

      broken = false;
      requests.length = 0;
      await backfillNewsSources(options(fetcher));
      assert.equal(requests.includes('https://webrun.com.br/p2/'), false);
      assert.equal(requests.includes('https://webrun.com.br/p3/'), true);
      assert.equal((await NewsSource.findOne({ fonteId: 'webrun' }))?.historicoConcluido, true);
    });

    it('ignora fonte desligada e não pagina o feed de assuntos gerais', async () => {
      await reset();
      await NewsSource.create({ fonteId: 'webrun', ativa: false });
      const requests: string[] = [];
      await backfillNewsSources(options(pages((n) => page(n), requests)));
      assert.equal(requests.some((url) => url.startsWith('https://webrun.com.br')), false);
      assert.equal(requests.includes('https://correiodecarajas.com.br/feed/?paged=2'), false);
      assert.equal(requests.includes('https://correiodecarajas.com.br/tag/corrida/feed/?paged=2'), true);
      await reset();
    });
  });

  it('notícia própria continua aparecendo com as fontes desligadas', async () => {
    await reset();
    const { token } = await admin();
    await api('POST', '/news', token, { titulo: 'Própria', conteudo: 'Texto' });
    await api('PUT', '/news/sources/webrun', token, { ativa: false });
    assert.equal((await titles()).includes('Própria'), true);
    await reset();
  });
});

describe('rotas', () => {
  const A = { lat: -6.07, lng: -49.9 };
  const B = { lat: -6.08, lng: -49.91 };
  const C = { lat: -6.09, lng: -49.92 };
  const trecho = (de: typeof A, para: typeof A, extra = {}) => ({
    coordenadas: [
      [de.lng, de.lat, 200],
      [para.lng, para.lat, 210],
    ],
    subidaM: 10,
    ...extra,
  });
  const ROTA = { nome: 'Volta do parque', pontos: [A, B, C], trechos: [trecho(A, B), trecho(B, C)] };

  let fakeOrs: Server;
  let reply: { status: number; body: unknown } = { status: 200, body: {} };
  let received: { authorization?: string; body?: any; path?: string } = {};

  before(async () => {
    fakeOrs = createServer((request, response) => {
      let text = '';
      request.on('data', (chunk) => (text += chunk));
      request.on('end', () => {
        received = { authorization: request.headers.authorization, body: JSON.parse(text), path: request.url };
        response.writeHead(reply.status, { 'Content-Type': 'application/json' });
        response.end(JSON.stringify(reply.body));
      });
    });
    await new Promise<void>((resolve) => fakeOrs.listen(0, '127.0.0.1', resolve));
    process.env.ORS_BASE_URL = `http://127.0.0.1:${(fakeOrs.address() as AddressInfo).port}`;
    process.env.ORS_API_KEY = 'chave-de-teste';
  });

  after(async () => {
    delete process.env.ORS_BASE_URL;
    delete process.env.ORS_API_KEY;
    await new Promise((resolve) => fakeOrs.close(resolve));
  });

  describe('trecho a pé', () => {
    it('pede o caminho a pé com altitude e devolve traçado e subida', async () => {
      const { token } = await newUser();
      reply = {
        status: 200,
        body: {
          features: [
            {
              geometry: { coordinates: [[-49.9000001, -6.07, 200.123], [-49.905, -6.075, 205], [-49.91, -6.08, 210]] },
              properties: { ascent: 12.34, descent: 2 },
            },
          ],
        },
      };
      const result = await api('POST', '/routes/segment', token, { de: A, para: B });
      assert.equal(result.status, 200);
      assert.deepEqual(result.json.dados.coordenadas[0], [-49.9, -6.07, 200.1]);
      assert.equal(result.json.dados.subidaM, 12.3);
      assert.equal(received.authorization, 'chave-de-teste');
      assert.equal(received.path, '/v2/directions/foot-walking/geojson');
      assert.deepEqual(received.body, { coordinates: [[A.lng, A.lat], [B.lng, B.lat]], elevation: true });
    });

    it('explica cada falha do serviço', async () => {
      const { token } = await newUser();
      const cases: [number, unknown, number, string][] = [
        [404, { error: { code: 2010 } }, 422, 'sem_caminho'],
        [500, { error: { code: 2009 } }, 422, 'sem_caminho'],
        [429, {}, 429, 'limite'],
        [403, {}, 503, 'indisponivel'],
        [200, { features: [] }, 503, 'indisponivel'],
        [200, { features: [{ geometry: { coordinates: [[1, 'x']] } }] }, 503, 'indisponivel'],
      ];
      for (const [status, body, expected, code] of cases) {
        reply = { status, body };
        const result = await api('POST', '/routes/segment', token, { de: A, para: B });
        assert.equal(result.status, expected, code);
        assert.equal(result.json.codigo, code);
        assert.equal(JSON.stringify(result.json).includes('chave-de-teste'), false);
      }
    });

    it('sem chave configurada, avisa sem chamar o serviço', async () => {
      const { token } = await newUser();
      delete process.env.ORS_API_KEY;
      received = {};
      const result = await api('POST', '/routes/segment', token, { de: A, para: B });
      process.env.ORS_API_KEY = 'chave-de-teste';
      assert.equal(result.status, 503);
      assert.equal(result.json.codigo, 'sem_chave');
      assert.deepEqual(received, {});
    });

    it('exige login, pontos válidos e distância razoável', async () => {
      const { token } = await newUser();
      assert.equal((await api('POST', '/routes/segment', undefined, { de: A, para: B })).status, 401);
      assert.equal((await api('POST', '/routes/segment', token, { de: A })).status, 400);
      assert.equal((await api('POST', '/routes/segment', token, { de: { lat: 91, lng: 0 }, para: B })).status, 400);
      assert.equal((await api('POST', '/routes/segment', token, { de: { lat: '1', lng: 0 }, para: B })).status, 400);
      assert.equal((await api('POST', '/routes/segment', token, { de: A, para: { lat: 0, lng: 0 } })).status, 400);
    });

    it('limita os pedidos de cada usuário por minuto', async () => {
      const { token } = await newUser();
      const other = await newUser();
      reply = { status: 200, body: { features: [{ geometry: { coordinates: [[-49.9, -6.07], [-49.91, -6.08]] }, properties: {} }] } };
      for (let i = 0; i < 30; i += 1) {
        assert.equal((await api('POST', '/routes/segment', token, { de: A, para: B })).status, 200);
      }
      const blocked = await api('POST', '/routes/segment', token, { de: A, para: B });
      assert.equal(blocked.status, 429);
      assert.equal((await api('POST', '/routes/segment', other.token, { de: A, para: B })).status, 200);
    });
  });

  describe('rotas salvas', () => {
    it('salva recalculando distância e subida, sem confiar no que veio do app', async () => {
      const { id, token } = await newUser();
      const created = await api('POST', '/routes', token, {
        ...ROTA,
        distanciaM: 1,
        dono: new mongoose.Types.ObjectId().toString(),
      });
      assert.equal(created.status, 201);
      assert.equal(created.json.dados.dono, id);
      assert.ok(Math.abs(created.json.dados.distanciaM - 3120) < 30, String(created.json.dados.distanciaM));
      assert.equal(created.json.dados.subidaM, 20);
      assert.equal(created.json.dados.temLinhaReta, false);

      const list = await api('GET', '/routes', token);
      assert.equal(list.json.dados.length, 1);
      assert.equal(list.json.dados[0].trechos, undefined, 'a lista não carrega o traçado');

      const opened = await api('GET', `/routes/${created.json.dados._id}`, token);
      assert.equal(opened.json.dados.trechos.length, 2);
      assert.deepEqual(opened.json.dados.trechos[0].coordenadas[0], [A.lng, A.lat, 200]);
    });

    it('marca a rota que tem trecho em linha reta', async () => {
      const { token } = await newUser();
      const created = await api('POST', '/routes', token, {
        ...ROTA,
        trechos: [trecho(A, B), trecho(B, C, { emLinhaReta: true })],
      });
      assert.equal(created.json.dados.temLinhaReta, true);
    });

    it('recusa rota inválida', async () => {
      const { token } = await newUser();
      const invalid = [
        { ...ROTA, nome: 'ab' },
        { ...ROTA, nome: 'x'.repeat(61) },
        { ...ROTA, pontos: [A], trechos: [] },
        { ...ROTA, trechos: [trecho(A, B)] },
        { ...ROTA, pontos: [{ lat: 99, lng: 0 }, B, C] },
        { ...ROTA, trechos: [trecho(A, B), { coordenadas: [[0, 0]] }] },
        { ...ROTA, trechos: [trecho(A, B), { coordenadas: [[0, 0], [500, 0]] }] },
        { ...ROTA, trechos: [trecho(A, B), { coordenadas: [[0, 0], ['a', 0]] }] },
        { ...ROTA, pontos: 'x' },
      ];
      for (const body of invalid) {
        assert.equal((await api('POST', '/routes', token, body)).status, 400, JSON.stringify(body).slice(0, 80));
      }
    });

    it('aceita um traçado longo', async () => {
      const { token } = await newUser();
      const coordenadas = Array.from({ length: 5000 }, (_, i) => [-49.9 + i / 100000, -6.07 - i / 100000, 200.5]);
      const result = await api('POST', '/routes', token, {
        nome: 'Longão',
        pontos: [A, B],
        trechos: [{ coordenadas, subidaM: 50 }],
      });
      assert.equal(result.status, 201);
    });

    it('a rota é privada: outra pessoa não vê, não altera e não exclui', async () => {
      const owner = await newUser();
      const stranger = await newUser();
      const admin = await newUser();
      await User.updateOne({ _id: admin.id }, { tipo: 'admin' });
      const { _id } = (await api('POST', '/routes', owner.token, ROTA)).json.dados;

      for (const { token } of [stranger, admin]) {
        assert.equal((await api('GET', `/routes/${_id}`, token)).status, 404);
        assert.equal((await api('PUT', `/routes/${_id}`, token, { ...ROTA, nome: 'Roubada' })).status, 404);
        assert.equal((await api('DELETE', `/routes/${_id}`, token)).status, 404);
        assert.equal((await api('GET', '/routes', token)).json.dados.length, 0);
      }
      assert.equal((await api('GET', `/routes/${_id}`)).status, 401);
      assert.equal((await api('GET', `/routes/${_id}`, owner.token)).json.dados.nome, ROTA.nome);
    });

    it('o dono altera e exclui', async () => {
      const { token } = await newUser();
      const { _id } = (await api('POST', '/routes', token, ROTA)).json.dados;
      const updated = await api('PUT', `/routes/${_id}`, token, {
        nome: 'Só ida',
        pontos: [A, B],
        trechos: [trecho(A, B)],
      });
      assert.equal(updated.status, 200);
      assert.equal(updated.json.dados.nome, 'Só ida');
      assert.equal(updated.json.dados.subidaM, 10);
      assert.equal((await api('PUT', `/routes/${_id}`, token, { nome: 'x' })).status, 400);
      assert.equal((await api('DELETE', `/routes/${_id}`, token)).status, 200);
      assert.equal((await api('GET', `/routes/${_id}`, token)).status, 404);
      assert.equal((await api('GET', '/routes/id-invalido', token)).status, 404);
    });
  });
});

describe('rota no treino', () => {
  const A = { lat: -6.07, lng: -49.9 };
  const B = { lat: -6.08, lng: -49.91 };
  const longa = Array.from({ length: 500 }, (_, i) => [-49.9 - i / 1e4, -6.07 - i / 1e4, 200]);
  const ROTA = { nome: 'Volta do parque', pontos: [A, B], trechos: [{ coordenadas: longa, subidaM: 30 }] };
  const newRoute = async (token: string) => (await api('POST', '/routes', token, ROTA)).json.dados;

  it('publica uma cópia: resumo nas listas e traçado completo só ao abrir', async () => {
    const { token, id } = await newUser();
    const route = await newRoute(token);
    const created = await api('POST', '/workouts', token, { ...WORKOUT, rotaId: route._id });
    assert.equal(created.status, 201);
    const workoutId = created.json.dados._id;

    const feed = (await api('GET', '/workouts/feed?limit=50')).json.dados.find((w: any) => w._id === workoutId);
    assert.equal(feed.rota.nome, 'Volta do parque');
    assert.ok(feed.rota.resumo.length >= 2 && feed.rota.resumo.length <= 80);
    assert.deepEqual(feed.rota.resumo[0], [-49.9, -6.07]);
    assert.deepEqual(feed.rota.resumo.at(-1), [longa[499][0], longa[499][1]].map((v) => Number(v.toFixed(5))));
    assert.equal(feed.rota.trechos, undefined);
    assert.equal(feed.rota.pontos, undefined);

    const mine = (await api('GET', `/workouts/user/${id}`)).json.dados[0];
    assert.equal(mine.rota.trechos, undefined);

    const opened = (await api('GET', `/workouts/${workoutId}`)).json.dados;
    assert.equal(opened.rota.trechos[0].coordenadas.length, 500);
    assert.equal(opened.rota.pontos.length, 2);
    assert.equal(opened.rota.subidaM, 30);
  });

  it('a rota original continua privada, e mudá-la não altera o treino', async () => {
    const owner = await newUser();
    const other = await newUser();
    const route = await newRoute(owner.token);
    const { _id } = (await api('POST', '/workouts', owner.token, { ...WORKOUT, rotaId: route._id })).json.dados;

    assert.equal((await api('GET', `/routes/${route._id}`, other.token)).status, 404);
    await api('PUT', `/routes/${route._id}`, owner.token, { ...ROTA, nome: 'Outro nome' });
    assert.equal((await api('GET', `/workouts/${_id}`)).json.dados.rota.nome, 'Volta do parque');
    await api('DELETE', `/routes/${route._id}`, owner.token);
    assert.equal((await api('GET', `/workouts/${_id}`)).json.dados.rota.trechos[0].coordenadas.length, 500);
  });

  it('não publica a rota de outra pessoa nem id inválido', async () => {
    const owner = await newUser();
    const other = await newUser();
    const route = await newRoute(owner.token);
    assert.equal((await api('POST', '/workouts', other.token, { ...WORKOUT, rotaId: route._id })).status, 404);
    assert.equal((await api('POST', '/workouts', other.token, { ...WORKOUT, rotaId: 'abc' })).status, 404);
    assert.equal((await api('POST', '/workouts', other.token, { ...WORKOUT, rotaId: { $ne: null } })).status, 404);

    const { _id } = (await api('POST', '/workouts', other.token, WORKOUT)).json.dados;
    assert.equal((await api('PUT', `/workouts/${_id}`, other.token, { rotaId: route._id })).status, 404);
    assert.equal((await api('GET', `/workouts/${_id}`)).json.dados.rota, undefined);
    assert.equal(
      (await api('POST', '/workouts', other.token, { ...WORKOUT, rota: { nome: 'Forjada', resumo: [[0, 0]] } })).json.dados.rota,
      undefined
    );
  });

  it('a edição coloca, mantém e retira a rota', async () => {
    const { token } = await newUser();
    const route = await newRoute(token);
    const { _id } = (await api('POST', '/workouts', token, WORKOUT)).json.dados;

    const added = await api('PUT', `/workouts/${_id}`, token, { rotaId: route._id });
    assert.equal(added.json.dados.rota.nome, 'Volta do parque');
    const kept = await api('PUT', `/workouts/${_id}`, token, { titulo: 'Só o título' });
    assert.equal(kept.json.dados.rota.nome, 'Volta do parque');
    const removed = await api('PUT', `/workouts/${_id}`, token, { rotaId: null });
    assert.equal(removed.status, 200);
    assert.equal(removed.json.dados.rota, undefined);
    assert.equal((await api('GET', `/workouts/${_id}`)).json.dados.rota, undefined);
  });
});

describe('edição de treino', () => {
  const stats = async (token: string) => (await api('GET', '/auth/me', token)).json.dados.estatisticas;

  it('recalcula tempo, pace e só a diferença nos totais', async () => {
    const { token } = await newUser();
    const { _id } = (await api('POST', '/workouts', token, WORKOUT)).json.dados;
    await api('POST', '/workouts', token, WORKOUT);

    const updated = await api('PUT', `/workouts/${_id}`, token, { distanciaKm: 5, duracaoSegundos: 1800, titulo: ' Novo ' });
    assert.equal(updated.status, 200);
    assert.equal(updated.json.dados.titulo, 'Novo');
    assert.equal(updated.json.dados.tempoFormatado, '00:30:00');
    assert.equal(updated.json.dados.paceMedio, '06:00 min/km');
    assert.equal(updated.json.dados.atleta.nome !== undefined, true);

    const totals = await stats(token);
    assert.equal(totals.totalKm, 15);
    assert.equal(totals.tempoTotalSegundos, 4800);
    assert.equal(totals.totalTreinos, 2);
  });

  it('mantém o que não foi enviado, curtidas e comentários', async () => {
    const owner = await newUser();
    const fan = await newUser();
    const { _id } = (await api('POST', '/workouts', owner.token, { ...WORKOUT, descricao: 'Boa' })).json.dados;
    await api('POST', `/workouts/${_id}/like`, fan.token);
    await api('POST', `/workouts/${_id}/comments`, fan.token, { texto: 'Parabéns' });

    const { json } = await api('PUT', `/workouts/${_id}`, owner.token, { titulo: 'Outro', curtidas: [], atleta: fan.id });
    assert.equal(json.dados.descricao, 'Boa');
    assert.equal(json.dados.distanciaKm, 10);
    assert.equal(json.dados.curtidas.length, 1);
    assert.equal(json.dados.comentarios[0].autor.nome !== undefined, true);
    assert.equal(json.dados.atleta._id, owner.id);
    assert.equal((await stats(owner.token)).totalKm, 10);
  });

  it('só quem publicou edita; nem o admin altera o treino de outra pessoa', async () => {
    const owner = await newUser();
    const other = await newUser();
    const admin = await newAdmin();
    const { _id } = (await api('POST', '/workouts', owner.token, WORKOUT)).json.dados;
    assert.equal((await api('PUT', `/workouts/${_id}`, undefined, WORKOUT)).status, 401);
    assert.equal((await api('PUT', `/workouts/${_id}`, other.token, WORKOUT)).status, 403);
    assert.equal((await api('PUT', `/workouts/${_id}`, admin.token, WORKOUT)).status, 403);
    assert.equal((await api('PUT', '/workouts/000000000000000000000000', owner.token, WORKOUT)).status, 404);
  });

  it('recusa dados inválidos sem mexer nos totais', async () => {
    const { token } = await newUser();
    const { _id } = (await api('POST', '/workouts', token, WORKOUT)).json.dados;
    const invalid = [
      { titulo: '   ' },
      { distanciaKm: 0 },
      { distanciaKm: 'abc' },
      { duracaoSegundos: 0 },
      { altimetria: -1 },
      { dataTreino: 'ontem' },
      { tipoTreino: 'voo' },
      { sensacaoEsforco: 'nenhum' },
      { fotos: 'x' },
      { fotos: ['https://exemplo.com/a.png'] },
    ];
    for (const body of invalid) {
      assert.equal((await api('PUT', `/workouts/${_id}`, token, body)).status, 400, JSON.stringify(body));
    }
    assert.equal((await stats(token)).totalKm, 10);
  });

  it('troca as fotos e apaga do disco só as que saíram', async () => {
    const { token } = await newUser();
    const [first, second] = (await upload(token, [[PNG, 'a.png', 'image/png'], [PNG, 'b.png', 'image/png']])).json.dados;
    const { _id } = (await api('POST', '/workouts', token, { ...WORKOUT, fotos: [first, second] })).json.dados;

    const { json } = await api('PUT', `/workouts/${_id}`, token, { fotos: [second] });
    assert.deepEqual(json.dados.fotos, [second]);
    assert.equal((await fetch(`${origin}${first}`)).status, 404);
    assert.equal((await fetch(`${origin}${second}`)).status, 200);
  });
});

describe('treinos', () => {
  it('soma e desconta os totais do atleta', async () => {
    const { id, token } = await newUser();
    const workout = (await api('POST', '/workouts', token, WORKOUT)).json.dados;
    assert.equal((await User.findById(id))?.estatisticas.totalKm, 10);
    assert.equal(workout.paceMedio, '05:00 min/km');
    await api('DELETE', `/workouts/${workout._id}`, token);
    const saved = await User.findById(id);
    assert.equal(saved?.estatisticas.totalKm, 0);
    assert.equal(saved?.estatisticas.totalTreinos, 0);
  });

  it('busca um treino pelo id, com autor e comentários', async () => {
    const owner = await newUser();
    const fan = await newUser();
    const workout = (await api('POST', '/workouts', owner.token, WORKOUT)).json.dados;
    await api('POST', `/workouts/${workout._id}/comments`, fan.token, { texto: 'Boa' });
    const { json } = await api('GET', `/workouts/${workout._id}`);
    assert.equal(json.dados.atleta._id, owner.id);
    assert.equal(json.dados.comentarios[0].autor._id, fan.id);
    assert.equal(json.dados.atleta.email, undefined);
  });

  it('valida fotos: formato, quantidade, tamanho e dono', async () => {
    const a = await newUser();
    const b = await newUser();
    const png: [Buffer, string, string] = [PNG, 'a.png', 'image/png'];

    assert.equal((await upload(undefined, [png])).status, 401);
    const ok = await upload(a.token, [png, png]);
    assert.equal(ok.status, 201);
    assert.equal((await upload(a.token, [[Buffer.from('<svg/>'), 'x.png', 'image/png']])).status, 400);
    assert.equal((await upload(a.token, [png, png, png, png, png])).status, 400);
    const big: [Buffer, string, string] = [Buffer.concat([PNG, Buffer.alloc(6 * 1024 * 1024)]), 'g.png', 'image/png'];
    assert.equal((await upload(a.token, [big])).status, 400);

    const post = (fotos: string[], token: string) => api('POST', '/workouts', token, { ...WORKOUT, fotos });
    assert.equal((await post(['https://exemplo.com/x.png'], a.token)).status, 400);
    assert.equal((await post(['/uploads/workouts/../../.env'], a.token)).status, 400);
    assert.equal((await post(ok.json.dados, b.token)).status, 400);

    const created = await post(ok.json.dados, a.token);
    assert.equal(created.status, 201);
    assert.equal((await fetch(origin + ok.json.dados[0])).status, 200);
    await api('DELETE', `/workouts/${created.json.dados._id}`, a.token);
    assert.equal((await fetch(origin + ok.json.dados[0])).status, 404);
  });

  it('só autor, dono do treino ou admin excluem comentário', async () => {
    const owner = await newUser();
    const author = await newUser();
    const stranger = await newUser();
    const workout = (await api('POST', '/workouts', owner.token, WORKOUT)).json.dados;
    const add = async () =>
      (await api('POST', `/workouts/${workout._id}/comments`, author.token, { texto: 'Oi' })).json.dados.at(-1)._id;

    const first = await add();
    assert.equal((await api('DELETE', `/workouts/${workout._id}/comments/${first}`, stranger.token)).status, 403);
    assert.equal((await api('DELETE', `/workouts/${workout._id}/comments/${first}`, author.token)).status, 200);
    const second = await add();
    assert.equal((await api('DELETE', `/workouts/${workout._id}/comments/${second}`, owner.token)).status, 200);
    assert.equal((await api('DELETE', `/workouts/${workout._id}/comments/${second}`, owner.token)).status, 404);
  });
});

describe('erros', () => {
  it('JSON malformado responde 400, sem detalhes internos', async () => {
    const response = await fetch(`${origin}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{ quebrado',
    });
    assert.equal(response.status, 400);
    assert.equal(((await response.json()) as any).stack, undefined);
  });
});
