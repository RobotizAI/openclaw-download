const OLLAMA_HOST = "http://127.0.0.1:11434";
const WEB_SEARCH_API = `${OLLAMA_HOST}/api/experimental/web_search`;
const WEB_FETCH_API = `${OLLAMA_HOST}/api/experimental/web_fetch`;
const MAX_RESULTS = 5;
const TIMEOUT_MS = 15_000;

async function ollamaFetch(
  url: string,
  body: Record<string, any>,
  signal?: AbortSignal,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);
  if (signal) {
    signal.addEventListener("abort", () => controller.abort(), { once: true });
  }

  try {
    return await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
  } catch (err) {
    if ((err as Error).name === "AbortError") {
      throw new Error(`Request timed out after ${TIMEOUT_MS}ms`);
    }
    throw err;
  } finally {
    clearTimeout(timeout);
  }
}

async function executeWebSearch(
  _toolCallId: string,
  params: { query: string },
  signal?: AbortSignal,
) {
  const query = params.query?.trim();
  if (!query) {
    throw new Error("query parameter is required");
  }

  const response = await ollamaFetch(WEB_SEARCH_API, { query, max_results: MAX_RESULTS }, signal);

  if (response.status === 401) {
    throw new Error(
      "Web search authentication failed. Make sure you are signed in to ollama (run `ollama signin`).",
    );
  }
  if (response.status === 403) {
    throw new Error("Web search is unavailable (ensure ollama cloud is enabled).");
  }
  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(`Web search failed (${response.status}): ${body}`);
  }

  const data = (await response.json()) as {
    results: { title: string; url: string; content: string }[];
  };

  if (!data.results?.length) {
    return { content: [{ type: "text" as const, text: `No results for: ${query}` }] };
  }

  const text = data.results
    .map(
      (r, i) =>
        `${i + 1}. ${r.title}\n   ${r.url}\n   ${r.content?.length > 300 ? r.content.slice(0, 300) + "..." : r.content}`,
    )
    .join("\n\n");

  return { content: [{ type: "text" as const, text }] };
}

async function executeWebFetch(
  _toolCallId: string,
  params: { url: string },
  signal?: AbortSignal,
) {
  const url = params.url?.trim();
  if (!url) {
    throw new Error("url parameter is required");
  }

  const response = await ollamaFetch(WEB_FETCH_API, { url }, signal);

  if (response.status === 401) {
    throw new Error(
      "Web fetch authentication failed. Make sure you are signed in to ollama (run `ollama signin`).",
    );
  }
  if (response.status === 403) {
    throw new Error("Web fetch is unavailable (ensure ollama cloud is enabled).");
  }
  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(`Web fetch failed (${response.status}): ${body}`);
  }

  const data = (await response.json()) as {
    title: string;
    content: string;
    links: string[];
  };

  const parts = [];
  if (data.title) parts.push(`# ${data.title}`);
  if (data.content) parts.push(data.content);
  if (data.links?.length) {
    parts.push("\n## Links\n" + data.links.map((l) => `- ${l}`).join("\n"));
  }

  const text = parts.join("\n\n") || "No content returned.";
  return { content: [{ type: "text" as const, text }] };
}

const ollamaWebSearchPlugin = {
  id: "openclaw-web-search",
  name: "Ollama Web Search",
  description: "Web search and fetch via local ollama server",
  register(api: any) {
    api.registerTool({
      name: "ollama_web_search",
      label: "Ollama Web Search",
      description:
        "Search the web for current information using Ollama's search API.",
      parameters: {
        type: "object",
        properties: {
          query: { type: "string", description: "The search query" },
        },
        required: ["query"],
      },
      execute: executeWebSearch,
    } as any);
    api.registerTool({
      name: "ollama_web_fetch",
      label: "Ollama Web Fetch",
      description:
        "Fetch the content of a web page by URL.",
      parameters: {
        type: "object",
        properties: {
          url: { type: "string", description: "The URL to fetch" },
        },
        required: ["url"],
      },
      execute: executeWebFetch,
    } as any);
  },
};

export default ollamaWebSearchPlugin;
