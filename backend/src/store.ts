export interface StoredContent {
  title: string;
  content: string;
  savedAt: string;
}

const TTL = 3600;

export async function saveContent(
  kv: KVNamespace,
  uuid: string,
  data: StoredContent
): Promise<void> {
  await kv.put(uuid, JSON.stringify(data), { expirationTtl: TTL });
}

export async function getContent(
  kv: KVNamespace,
  uuid: string
): Promise<StoredContent | null> {
  const raw = await kv.get(uuid);
  if (raw === null) return null;
  return JSON.parse(raw) as StoredContent;
}
