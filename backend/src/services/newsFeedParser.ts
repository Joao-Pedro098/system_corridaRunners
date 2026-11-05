import { XMLParser } from 'fast-xml-parser';
import { NewsCategory } from '../types';

export interface FeedItem {
  titulo: string;
  link: string;
  resumo: string;
  autor?: string;
  publicadoEm: Date;
  categorias: string[];
  imagem?: string;
}

export const MAX_TITLE = 200;
export const MAX_EXCERPT = 280;

const NAMED_ENTITIES: Record<string, string> = {
  amp: '&',
  lt: '<',
  gt: '>',
  quot: '"',
  apos: "'",
  nbsp: ' ',
  hellip: '…',
  ndash: '–',
  mdash: '—',
  ldquo: '“',
  rdquo: '”',
  lsquo: '‘',
  rsquo: '’',
};

const decodeEntities = (text: string): string =>
  text.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (match, code: string) => {
    if (code[0] !== '#') return NAMED_ENTITIES[code.toLowerCase()] ?? match;
    const value = code[1].toLowerCase() === 'x' ? parseInt(code.slice(2), 16) : parseInt(code.slice(1), 10);
    return value > 0 && value <= 0x10ffff ? String.fromCodePoint(value) : match;
  });

/** Converte HTML de feed em texto simples. */
export const toPlainText = (html: string): string =>
  decodeEntities(
    html
      .replace(/<(script|style)\b[\s\S]*?<\/\1>/gi, ' ')
      .replace(/<[^>]*>/g, ' ')
  )
    .replace(/<[^>]*>/g, ' ')
    .replace(/[\u0000-\u001f\u007f]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

const cut = (text: string, max: number): string => {
  if (text.length <= max) return text;
  const slice = text.slice(0, max - 1);
  const lastSpace = slice.lastIndexOf(' ');
  return `${(lastSpace > max / 2 ? slice.slice(0, lastSpace) : slice).replace(/[\s,;:.–—-]+$/, '')}…`;
};

/** Resumo curto: nunca usa o texto completo da matéria, nem a assinatura "appeared first on" do WordPress. */
export const toExcerpt = (description: string): string => {
  const text = toPlainText(description)
    .replace(/\s*The post .* appeared first on .*$/i, '')
    .replace(/\s*O post .* apareceu primeiro em .*$/i, '')
    .replace(/\s*\[(…|\.\.\.)\]\s*$/, '…')
    .trim();
  return cut(text, MAX_EXCERPT);
};

/** Só frases inequívocas: "corrida" sozinha também descreve viagem de aplicativo, de cavalos e eleitoral. */
const RUNNING_TITLE = /corridas? de rua|meia[- ]maratona|corrida e caminhada|caminhada e corrida|corredores de rua/i;
/** Maratona só com nome próprio depois: "Maratona de Belém" sim, "maratona de vacinação" não. */
const NAMED_MARATHON = /[Mm]aratona (de|do|da) [A-ZÀ-Ú]/;

export const isAboutRunning = (title: string): boolean => RUNNING_TITLE.test(title) || NAMED_MARATHON.test(title);

export const toCategory = (categories: string[]): NewsCategory => {
  const text = categories.join(' ').toLowerCase();
  if (/nutri|aliment|dieta|suplement/.test(text)) return 'Nutrição';
  if (/treino|treinamento|t[eé]cnica|preparo|les[aã]o|les[oõ]es/.test(text)) return 'Dica de Treino';
  return 'Novidade';
};

const asArray = <T>(value: T | T[] | undefined): T[] => (value === undefined ? [] : Array.isArray(value) ? value : [value]);

const textOf = (value: unknown): string => {
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  if (value && typeof value === 'object') return textOf((value as Record<string, unknown>)['#text']);
  return '';
};

const imageFromAttributes = (value: unknown): string | undefined => {
  for (const entry of asArray(value as object | object[] | undefined)) {
    const attrs = entry as Record<string, unknown>;
    const url = attrs['@_url'];
    const type = attrs['@_type'];
    if (typeof url === 'string' && (typeof type !== 'string' || type.startsWith('image/'))) return url;
  }
  return undefined;
};

const parser = new XMLParser({
  ignoreAttributes: false,
  processEntities: false, // a decodificação é feita aqui, sem expandir entidades declaradas pelo próprio feed
  htmlEntities: false,
  parseTagValue: false,
  parseAttributeValue: false,
  trimValues: true,
});

/** Lê um feed RSS 2.0. Devolve lista vazia quando o conteúdo não é RSS. */
export const parseFeed = (xml: string, now = new Date()): FeedItem[] => {
  const root = parser.parse(xml) as Record<string, any>;
  const items = asArray<Record<string, unknown>>(root?.rss?.channel?.item);

  return items.flatMap((item) => {
    const titulo = cut(toPlainText(textOf(item.title)), MAX_TITLE);
    const link = decodeEntities(textOf(item.link)).trim();
    const resumo = toExcerpt(textOf(item.description));
    if (!titulo || !link || !resumo) return [];

    const date = new Date(textOf(item.pubDate));
    const autor = toPlainText(textOf(item['dc:creator']));
    const imagem =
      imageFromAttributes(item['media:content']) ??
      imageFromAttributes(item['media:thumbnail']) ??
      imageFromAttributes(item.enclosure);
    return [
      {
        titulo,
        link,
        resumo,
        autor: autor || undefined,
        publicadoEm: Number.isNaN(date.getTime()) || date > now ? now : date,
        categorias: asArray(item.category as unknown).map(textOf).map(toPlainText).filter(Boolean),
        imagem: imagem ? decodeEntities(imagem) : undefined,
      },
    ];
  });
};

/** Link canônico para reconhecer a mesma matéria: https, sem âncora e sem parâmetros de campanha. */
export const normalizeArticleLink = (raw: string, host: string): string | null => {
  try {
    const url = new URL(raw);
    if (url.protocol !== 'https:' && url.protocol !== 'http:') return null;
    if (url.hostname !== host && !url.hostname.endsWith(`.${host}`)) return null;
    url.protocol = 'https:';
    url.hash = '';
    for (const key of [...url.searchParams.keys()]) {
      if (key.toLowerCase().startsWith('utm_')) url.searchParams.delete(key);
    }
    return url.toString();
  } catch {
    return null;
  }
};

/** Capa só em https: uma imagem http seria bloqueada quando o app roda em https. */
export const normalizeImageUrl = (raw: string | undefined, base?: string): string | undefined => {
  if (!raw) return undefined;
  try {
    const url = new URL(decodeEntities(raw.trim()), base);
    return url.protocol === 'https:' ? url.toString() : undefined;
  } catch {
    return undefined;
  }
};

const metaContent = (html: string, property: string): string | undefined => {
  for (const [tag] of html.matchAll(/<meta\b[^>]*>/gi)) {
    const name = /(?:property|name)\s*=\s*["']([^"']+)["']/i.exec(tag)?.[1];
    if (name?.toLowerCase() !== property) continue;
    const content = /content\s*=\s*"([^"]*)"|content\s*=\s*'([^']*)'/i.exec(tag);
    const value = content?.[1] ?? content?.[2];
    if (value) return value;
  }
  return undefined;
};

/** A capa que o próprio site indica para compartilhamento da matéria. */
export const extractCover = (html: string, pageUrl: string): string | undefined => {
  const raw = metaContent(html, 'og:image') ?? metaContent(html, 'twitter:image');
  const url = normalizeImageUrl(raw, pageUrl);
  return url && !/logo|favicon/i.test(url) ? url : undefined;
};
