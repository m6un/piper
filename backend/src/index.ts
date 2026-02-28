import { handleSave } from "./handlers/save";
import { handleGet } from "./handlers/get";

interface Env {
  CONTENT_STORE: KVNamespace;
}

// UUID v4 pattern
const UUID_PATTERN = /^\/([0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})$/i;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { pathname } = new URL(request.url);

    if (pathname === "/save" && request.method === "POST") {
      return handleSave(request, env);
    }

    const uuidMatch = UUID_PATTERN.exec(pathname);
    if (uuidMatch !== null && request.method === "GET") {
      return handleGet(uuidMatch[1], env);
    }

    return new Response("Not Found", { status: 404 });
  },
};
