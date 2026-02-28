import { getContent } from "../store";

interface Env {
  CONTENT_STORE: KVNamespace;
}

function renderHtml(title: string, content: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(title)}</title>
  <style>
    body { font-family: Georgia, serif; max-width: 720px; margin: 2rem auto; padding: 0 1rem; line-height: 1.6; color: #222; }
    h1 { font-size: 1.8rem; margin-bottom: 1.5rem; }
    article { font-size: 1.1rem; }
  </style>
</head>
<body>
  <h1>${escapeHtml(title)}</h1>
  <article>${content}</article>
</body>
</html>`;
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

export async function handleGet(uuid: string, env: Env): Promise<Response> {
  const stored = await getContent(env.CONTENT_STORE, uuid);
  if (stored === null) {
    return new Response("Not Found", { status: 404 });
  }

  return new Response(renderHtml(stored.title, stored.content), {
    status: 200,
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}
