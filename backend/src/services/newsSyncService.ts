import { NEWS_SOURCES, NewsFeed, NewsSourceConfig } from '../config/newsSources';
import { News } from '../models/News';
import { NewsSource } from '../models/NewsSource';
import {
  extractCover,
  FeedItem,
  isAboutRunning,
  normalizeArticleLink,
  normalizeImageUrl,
  parseFeed,
  toCategory,
} from './newsFeedParser';

/** Lê um endereço da fonte e devolve o texto. Trocado por um falso nos testes. */
export type Fetcher = (url: string, host: string) => Promise<string>;

export interface SyncOptions {
  /** Busca mesmo que a fonte tenha sido lida há pouco tempo. */
  force?: boolean;
  fetcher?: Fetcher;
  /** Pausa entre as páginas de matéria abertas para encontrar a capa. */
  pageDelayMs?: number;
  now?: Date;
}

export interface SyncResult {
  fonteId: string;
  novas: number;
  erro?: string;
  pulada?: boolean;
}

export interface BackfillOptions {
  fetcher?: Fetcher;
  pageDelayMs?: number;
  /** Pausa entre as páginas do feed. */
  feedDelayMs?: number;
  now?: Date;
}

export interface BackfillResult {
  fonteId: string;
  novas: number;
  erro?: string;
}

const USER_AGENT ='RunnersRun/1.0 (leitor de feed RSS)';
const REQUEST_TIMEOUT_MS = 15_000;
const MAX_RESPONSE_BYTES = 3 * 1024 * 1024;
const MAX_REDIRECTS = 3;
const MAX_NEW_PER_RUN = 15;
/** Teto da busca de matérias anteriores: cerca de 100 por fonte, para não pesar nos sites. */
const MAX_BACKFILL_PAGES = 10;
const MAX_ARTICLE_AGE_MS = 180 * 24 * 60 * 60 * 1000;
const MIN_INTERVAL_MS = 60 * 60 * 1000;
const SYNC_INTERVAL_MS = 6 * 60 * 60 * 1000;
const FIRST_SYNC_DELAY_MS = 30_000;

const isOnHost = (url: URL, host: string): boolean =>
  url.protocol === 'https:' && (url.hostname === host || url.hostname.endsWith(`.${host}`));

/** Lê no máximo 3 MB, só em https e sem seguir redirecionamento para fora do domínio da fonte. */
export const fetchFromSource: Fetcher = async (start, host) => {
  let url = new URL(start);
  for (let hop = 0; hop <= MAX_REDIRECTS; hop += 1) {
    if (!isOnHost(url, host)) throw new Error(`Endereço fora de ${host}`);
    const response = await fetch(url, {
      headers: { 'User-Agent': USER_AGENT, Accept: 'application/rss+xml, application/xml, text/xml, text/html' },
      redirect: 'manual',
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
    if (response.status >= 300 && response.status < 400) {
      await response.body?.cancel();
      const location = response.headers.get('location');
      if (!location) throw new Error(`Redirecionamento sem destino (HTTP ${response.status})`);
      url = new URL(location, url);
      continue;
    }
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error(`HTTP ${response.status}`);
    }

    const reader = response.body?.getReader();
    if (!reader) return '';
    const decoder = new TextDecoder('utf-8');
    let text = '';
    let received = 0;
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      received += value.length;
      text += decoder.decode(value, { stream: true });
      if (received > MAX_RESPONSE_BYTES) {
        await reader.cancel();
        break;
      }
    }
    return text + decoder.decode();
  }
  throw new Error('Redirecionamentos demais');
};

const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const coverFor = async (item: FeedItem, link: string, source: NewsSourceConfig, fetcher: Fetcher) => {
  if (source.semCapa) return undefined;
  const fromFeed = normalizeImageUrl(item.imagem, link);
  if (fromFeed) return fromFeed;
  try {
    return extractCover(await fetcher(link, source.host), link);
  } catch {
    return undefined; // sem capa a matéria continua válida; o app mostra a arte da marca
  }
};

const isTooOld = (item: FeedItem, now: Date) => now.getTime() - item.publicadoEm.getTime() > MAX_ARTICLE_AGE_MS;

const collectItems = (
  items: FeedItem[],
  feed: NewsFeed,
  source: NewsSourceConfig,
  now: Date,
  found: Map<string, FeedItem>
): void => {
  for (const item of items) {
    if (feed.apenasSobreCorrida && !isAboutRunning(item.titulo)) continue;
    if (isTooOld(item, now)) continue;
    const link = normalizeArticleLink(item.link, source.host);
    if (link && !found.has(link)) found.set(link, item);
  }
};

/** Grava as matérias ainda desconhecidas, com pausa entre as páginas abertas atrás da capa. */
const storeNewItems = async (
  found: Map<string, FeedItem>,
  source: NewsSourceConfig,
  fetcher: Fetcher,
  pageDelayMs: number,
  maxNew = Number.POSITIVE_INFINITY
): Promise<number> => {
  const known = new Set(
    (await News.find({ linkOriginal: { $in: [...found.keys()] } }).select('linkOriginal').lean()).map(
      (news) => news.linkOriginal
    )
  );

  let novas = 0;
  for (const [link, item] of found) {
    if (known.has(link) || novas >= maxNew) continue;
    if (novas > 0) await wait(pageDelayMs);
    const imagemUrl = await coverFor(item, link, source, fetcher);
    await News.updateOne(
      { linkOriginal: link },
      {
        $setOnInsert: {
          titulo: item.titulo,
          conteudo: item.resumo,
          categoria: toCategory(item.categorias),
          autor: item.autor ?? source.nome,
          imagemUrl,
          linkOriginal: link,
          fonteId: source.id,
          fonteNome: source.nome,
          publicadoEm: item.publicadoEm,
        },
      },
      { upsert: true }
    );
    novas += 1;
  }
  return novas;
};

const syncSource = async (
  source: NewsSourceConfig,
  { fetcher = fetchFromSource, pageDelayMs = 1000, now = new Date() }: SyncOptions
): Promise<SyncResult> => {
  const found = new Map<string, FeedItem>();
  const errors: string[] = [];

  for (const feed of source.feeds) {
    try {
      collectItems(parseFeed(await fetcher(feed.url, source.host), now), feed, source, now, found);
    } catch (error) {
      errors.push(error instanceof Error ? error.message : 'Falha ao ler o feed');
    }
  }

  if (source.semCapa) {
    await News.updateMany({ fonteId: source.id, imagemUrl: { $exists: true } }, { $unset: { imagemUrl: 1 } });
  }

  const novas = await storeNewItems(found, source, fetcher, pageDelayMs, MAX_NEW_PER_RUN);

  const erro = errors.length > 0 ? errors.join('; ') : undefined;
  await NewsSource.updateOne(
    { fonteId: source.id },
    { $set: { ultimaBusca: now, ultimasNovas: novas, ...(erro ? { ultimoErro: erro } : {}) }, ...(erro ? {} : { $unset: { ultimoErro: 1 } }) },
    { upsert: true }
  );
  return { fonteId: source.id, novas, ...(erro ? { erro } : {}) };
};

let running: Promise<SyncResult[]> | null = null;

/** Busca as fontes ligadas. Se já houver uma busca em andamento, aproveita o resultado dela. */
export const syncNewsSources = (options: SyncOptions = {}): Promise<SyncResult[]> => {
  if (running) return running;
  running = (async () => {
    const now = options.now ?? new Date();
    const states = await NewsSource.find({ fonteId: { $in: NEWS_SOURCES.map((s) => s.id) } }).lean();
    const results: SyncResult[] = [];
    for (const source of NEWS_SOURCES) {
      const state = states.find((s) => s.fonteId === source.id);
      const recent = state?.ultimaBusca && now.getTime() - state.ultimaBusca.getTime() < MIN_INTERVAL_MS;
      if (state?.ativa === false || (recent && !options.force)) {
        results.push({ fonteId: source.id, novas: 0, pulada: true });
        continue;
      }
      results.push(await syncSource(source, options));
    }
    return results;
  })().finally(() => {
    running = null;
  });
  return running;
};

/**
 * Lê as páginas anteriores de um feed. Devolve false quando a leitura falhou no meio, para tentar de novo
 * na próxima rodada; matérias já gravadas não são abertas outra vez.
 */
const backfillSource = async (
  source: NewsSourceConfig,
  { fetcher = fetchFromSource, pageDelayMs = 1000, feedDelayMs = 2000, now = new Date() }: BackfillOptions
): Promise<BackfillResult> => {
  let novas = 0;
  // Feed de assuntos gerais fica de fora: seriam muitas páginas para poucas matérias sobre corrida.
  for (const feed of source.feeds.filter((f) => !f.apenasSobreCorrida)) {
    for (let page = 2; page <= MAX_BACKFILL_PAGES + 1; page += 1) {
      await wait(feedDelayMs);
      let items: FeedItem[];
      try {
        items = parseFeed(await fetcher(`${feed.url}?paged=${page}`, source.host), now);
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Falha ao ler o feed';
        if (message === 'HTTP 404') break; // o feed acabou
        return { fonteId: source.id, novas, erro: message };
      }
      if (items.length === 0 || items.every((item) => isTooOld(item, now))) break;

      const found = new Map<string, FeedItem>();
      collectItems(items, feed, source, now, found);
      novas += await storeNewItems(found, source, fetcher, pageDelayMs);
    }
  }
  await NewsSource.updateOne({ fonteId: source.id }, { $set: { historicoConcluido: true } }, { upsert: true });
  return { fonteId: source.id, novas };
};

let backfilling: Promise<BackfillResult[]> | null = null;

/** Traz as matérias anteriores das fontes ligadas. Cada fonte passa por isso uma única vez. */
export const backfillNewsSources = (options: BackfillOptions = {}): Promise<BackfillResult[]> => {
  if (backfilling) return backfilling;
  backfilling = (async () => {
    const states = await NewsSource.find({ fonteId: { $in: NEWS_SOURCES.map((s) => s.id) } }).lean();
    const results: BackfillResult[] = [];
    for (const source of NEWS_SOURCES) {
      const state = states.find((s) => s.fonteId === source.id);
      if (state?.ativa === false || state?.historicoConcluido) continue;
      results.push(await backfillSource(source, options));
    }
    return results;
  })().finally(() => {
    backfilling = null;
  });
  return backfilling;
};

/** Agenda a busca: pouco depois de o servidor subir e, depois, a cada 6 horas. */
export const startNewsSync = (): void => {
  if (process.env.NEWS_SYNC === 'off') return;
  const log = (results: (SyncResult | BackfillResult)[]) => {
    for (const result of results) {
      if (result.erro) console.error(`📰 Fonte ${result.fonteId}: ${result.erro}`);
      else if (result.novas > 0) console.log(`📰 Fonte ${result.fonteId}: ${result.novas} matérias novas`);
    }
  };
  const run = () => {
    syncNewsSources()
      .then(log)
      .then(() => backfillNewsSources())
      .then(log)
      .catch((error) => console.error('📰 Falha na busca de notícias:', error));
  };
  setTimeout(run, FIRST_SYNC_DELAY_MS).unref();
  setInterval(run, SYNC_INTERVAL_MS).unref();
};
