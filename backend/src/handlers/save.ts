import { saveContent } from "../store";

interface Env {
  CONTENT_STORE: KVNamespace;
}

export async function handleSave(request: Request, env: Env): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  }

  if (
    typeof body !== "object" ||
    body === null ||
    !("title" in body) ||
    !("content" in body) ||
    typeof (body as Record<string, unknown>).title !== "string" ||
    typeof (body as Record<string, unknown>).content !== "string" ||
    ((body as Record<string, unknown>).title as string).trim() === "" ||
    ((body as Record<string, unknown>).content as string).trim() === ""
  ) {
    return new Response(JSON.stringify({ error: "Missing required fields: title, content" }), {
      status: 400,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  }

  const { title, content } = body as { title: string; content: string };
  const uuid = crypto.randomUUID();
  const origin = new URL(request.url).origin;

  await saveContent(env.CONTENT_STORE, uuid, {
    title,
    content,
    savedAt: new Date().toISOString(),
  });

  const url = `${origin}/${uuid}`;
  return new Response(JSON.stringify({ url }), {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
