import { saveContent } from "../store";

interface Env {
  CONTENT_STORE: KVNamespace;
}

function isValidPayload(body: unknown): body is { title: string; content: string } {
  if (typeof body !== "object" || body === null) return false;
  const b = body as Record<string, unknown>;
  return (
    typeof b.title === "string" && b.title.trim() !== "" &&
    typeof b.content === "string" && b.content.trim() !== ""
  );
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

  if (!isValidPayload(body)) {
    return new Response(JSON.stringify({ error: "Missing required fields: title, content" }), {
      status: 400,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  }

  const { title, content } = body;
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
