// Testes de integração da API contra um MongoDB real: npm test
// O banco é apagado a cada execução, por isso o nome precisa terminar em _test.
import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import { Server } from 'node:http';
import { AddressInfo } from 'node:net';
import mongoose from 'mongoose';
import app from '../src/app';
import { removePhotos } from '../src/middlewares/uploadMiddleware';
import { User } from '../src/models/User';

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

  it('editar as distâncias preserva o percurso das que continuam', async () => {
    const owner = await newUser('organizador');
    const race = (await api('POST', '/races', owner.token, {
      ...RACE,
      distancias: [
        { distanciaKm: 5, rotaGeoJSON: { type: 'LineString', coordinates: [[-49, -6], [-49.1, -6.1]] } },
        { distanciaKm: 10 },
      ],
    })).json.dados;
    const { json } = await api('PUT', `/races/${race._id}`, owner.token, {
      distancias: [{ distanciaKm: 5, altimetria: 40 }, { distanciaKm: 21 }],
    });
    const five = json.dados.distancias.find((d: any) => d.distanciaKm === 5);
    assert.equal(five.altimetria, 40);
    assert.equal(five.rotaGeoJSON.coordinates.length, 2);
    assert.deepEqual(json.dados.distancias.map((d: any) => d.distanciaKm), [5, 21]);
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
