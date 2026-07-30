# Model Discovery

A Rust CLI tool that scrapes AI model metadata (names, API identifiers, parameters, quantization, context length, tags, etc.) from HTML pages and APIs, and outputs normalized JSON for downstream harness consumption.

## Input Sources

| Source | URL | Scope |
|--------|-----|-------|
| Cloudflare Workers AI | `https://developers.cloudflare.com/workers-ai/models/` | All models; free models are prefixed with `@cf` |
| Ollama | `https://ollama.com/search?c=cloud` | Cloud category models |
| NVIDIA Build | `https://build.nvidia.com/models?orderBy=dateCreated%3ADESC&label=Coding` | Coding-tagged models only |

## Data Model

Each discovered model is normalized to the following schema:

```json
{
  "source": "cloudflare",
  "api_name": "@cf/moonshotai/kimi-k2.7-code",
  "slug": "kimi-k2.7-code",
  "name": "Kimi K2.7",
  "provider": "moonshotai",
  "parameters": "2.7B",
  "quantization": "q4_k_m",
  "context_length": 8192,
  "tags": ["code", "chat"],
  "url": "https://developers.cloudflare.com/workers-ai/models/kimi-k2.7-code"
}
```

### Field Specification

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `source` | string | yes | Origin provider key: `"cloudflare"`, `"ollama"`, or `"nvidia"` |
| `api_name` | string | yes | Fully-qualified API identifier used in requests |
| `slug` | string | yes | URL-safe short identifier |
| `name` | string | yes | Human-readable display name |
| `provider` | string | yes | Model author/vendor (extracted from `api_name` or page metadata) |
| `parameters` | string | no | Parameter count string, e.g. `"7B"`, `"70B"`, `"2.7B"`. Omit if unavailable. |
| `quantization` | string | no | Quantization level, e.g. `"q4_k_m"`, `"q8_0"`. Omit if unavailable. |
| `context_length` | integer | no | Maximum context window in tokens. Omit if unavailable. |
| `tags` | array[string] | no | Classification tags (e.g. `["vision"]`, `["code"]`, `["embedding"]`) |
| `deprecated` | boolean | no | `true` if the model is marked as deprecated/legacy. Omit if `false`. |
| `url` | string | yes | Permalink to the model's detail page |

## CLI Interface

```
Usage: model-discovery [OPTIONS] <SOURCE>

Arguments:
  <SOURCE>  Source to scrape [possible values: cloudflare, ollama, nvidia, all]

Options:
  -o, --output <FILE>    Write output JSON to file (default: stdout)
  -f, --format <FMT>     Output format [possible values: json, jsonl] (default: json)
  --pretty               Pretty-print JSON output
  --timeout <SECONDS>    HTTP request timeout in seconds (default: 30)
  --user-agent <STRING>  Custom User-Agent header
  -h, --help             Print help
  -V, --version          Print version
```

### Exit Codes

| Exit Code | Meaning |
|-----------|---------|
| 0 | Success |
| 1 | Parse error (malformed HTML, unexpected structure) |
| 2 | Network error (timeout, DNS failure, HTTP non-200) |
| 3 | I/O error (cannot write output file) |

## Scraping Behavior

### Cloudflare

- Page: `https://developers.cloudflare.com/workers-ai/models/`
- Models with `api_name` starting with `@cf` are free-tier eligible; retain the `@cf` prefix in `api_name`.
- Extract `provider` from the first segment of `api_name` after `@cf`, e.g. `@cf/moonshotai/...` -> `provider: "moonshotai"`.
- The `slug` is the trailing path segment of the model's detail page URL.
- Pagination: follow "next page" links if present; stop when none remain.
- Gracefully skip rows whose structure differs from the expected model card format.

### Ollama

- Primary: Use the official Ollama API endpoint if available (`https://ollama.com/api/models` or similar documented endpoint).
- Fallback: Parse the HTML at `https://ollama.com/search?c=cloud` when the API is unavailable.
- The HTML fallback must not fail if page structure changes slightly — use fuzzy selectors and skip unrecognized blocks.
- Extract tags from category labels presented on the page.

### NVIDIA Build

- Page: `https://build.nvidia.com/models?orderBy=dateCreated%3ADESC&label=Coding`
- Scope: Only models tagged with the `Coding` label.
- Filter out any model explicitly marked as **Deprecated** or **Legacy** on the page.
- Extract `api_name` from the model's API identifier field or card data attribute.
- Extract `provider` from the author/publisher field on each model card.
- Pagination: follow "Load more" or "next page" links; stop when none remain.

### Common Rules

- **Exclude deprecated models**: Skip any model explicitly marked as deprecated, legacy, or end-of-life by the source. Set `deprecated: true` if the source distinguishes but you still choose to emit it; otherwise omit the entry entirely.
- **Deduplication**: If repeated `api_name` values appear from the same source, keep only the first occurrence. (Different sources may overlap; keep both.)
- **Missing fields**: Omit the JSON key entirely rather than emitting `null`.
- **Encoding**: All string values must be valid UTF-8. Replace or skip invalid byte sequences.
- **Rate limiting**: Insert a 500ms delay between consecutive HTTP requests to the same domain.
- **Retry**: Retry failed requests up to 2 times with exponential backoff (1s, 2s).

## Output

### JSON Format (default)

A single JSON array of model objects:

```json
[
  { "source": "cloudflare", "api_name": "@cf/meta/llama-3.1-8b", ... },
  { "source": "ollama", "api_name": "llama3.1:8b", ... }
]
```

### JSONL Format (`--format jsonl`)

One JSON object per line:

```jsonl
{"source":"cloudflare","api_name":"@cf/meta/llama-3.1-8b",...}
{"source":"ollama","api_name":"llama3.1:8b",...}
```

## Error Handling

- If a single model card fails to parse, log a warning to stderr and continue. Do not abort the entire scrape.
- If the entire page fails to load after retries, exit with code 2 and print the final HTTP error to stderr.
- All logging/progress output goes to stderr; stdout contains only the clean JSON output (when `-o` is not used).

## Project Structure (Rust)

```
src/
  main.rs         -- CLI entrypoint (clap arg parsing)
  scrape/
    mod.rs        -- Scraper trait + dispatch logic
    cloudflare.rs -- Cloudflare page scraper
    ollama.rs     -- Ollama API + HTML fallback scraper
    nvidia.rs     -- NVIDIA Build page scraper
  model.rs        -- Model struct + serialization
  error.rs        -- Custom error types
```
