import { env, createExecutionContext, waitOnExecutionContext } from "cloudflare:test";
import { describe, it, expect } from "vitest";
import worker from "./index";

// The worker domain used in URL responses
const WORKER_DOMAIN = "https://piper.workers.dev";

describe("POST /save", () => {
  it("returns { url } containing a UUID path when given title and content", async () => {
    const request = new Request("https://piper.workers.dev/save", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: "Test Article", content: "<p>Hello</p>" }),
    });
    const ctx = createExecutionContext();
    const response = await worker.fetch(request, env, ctx);
    await waitOnExecutionContext(ctx);

    expect(response.status).toBe(200);
    const body = await response.json() as { url: string };
    expect(body.url).toBeDefined();
    expect(body.url).toMatch(/^https:\/\/piper\.workers\.dev\/[0-9a-f-]{36}$/);
  });

  it("returns 400 when title is missing", async () => {
    const request = new Request("https://piper.workers.dev/save", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ content: "<p>No title</p>" }),
    });
    const ctx = createExecutionContext();
    const response = await worker.fetch(request, env, ctx);
    await waitOnExecutionContext(ctx);

    expect(response.status).toBe(400);
  });

  it("returns 400 when content is missing", async () => {
    const request = new Request("https://piper.workers.dev/save", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: "Title only" }),
    });
    const ctx = createExecutionContext();
    const response = await worker.fetch(request, env, ctx);
    await waitOnExecutionContext(ctx);

    expect(response.status).toBe(400);
  });

  it("returns 400 when body is empty", async () => {
    const request = new Request("https://piper.workers.dev/save", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({}),
    });
    const ctx = createExecutionContext();
    const response = await worker.fetch(request, env, ctx);
    await waitOnExecutionContext(ctx);

    expect(response.status).toBe(400);
  });
});

describe("GET /{uuid}", () => {
  it("returns clean HTML page with title and content for a valid UUID", async () => {
    // First save some content
    const saveRequest = new Request("https://piper.workers.dev/save", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: "My Article", content: "<p>Article body</p>" }),
    });
    const saveCtx = createExecutionContext();
    const saveResponse = await worker.fetch(saveRequest, env, saveCtx);
    await waitOnExecutionContext(saveCtx);
    const { url } = await saveResponse.json() as { url: string };

    // Now fetch it
    const getRequest = new Request(url);
    const getCtx = createExecutionContext();
    const getResponse = await worker.fetch(getRequest, env, getCtx);
    await waitOnExecutionContext(getCtx);

    expect(getResponse.status).toBe(200);
    const html = await getResponse.text();
    expect(html).toContain("My Article");
    expect(html).toContain("<p>Article body</p>");
    expect(getResponse.headers.get("content-type")).toContain("text/html");
  });

  it("returns 404 for an unknown UUID", async () => {
    const uuid = "00000000-0000-0000-0000-000000000000";
    const request = new Request(`${WORKER_DOMAIN}/${uuid}`);
    const ctx = createExecutionContext();
    const response = await worker.fetch(request, env, ctx);
    await waitOnExecutionContext(ctx);

    expect(response.status).toBe(404);
  });
});

describe("unknown routes", () => {
  it("returns 404 for unrecognised paths", async () => {
    const request = new Request("https://piper.workers.dev/unknown");
    const ctx = createExecutionContext();
    const response = await worker.fetch(request, env, ctx);
    await waitOnExecutionContext(ctx);

    expect(response.status).toBe(404);
  });
});
