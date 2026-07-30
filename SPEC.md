# Model Discovery

A Rust CLI tool that scrapes **free** AI model metadata (names, API identifiers, parameters, quantization, context length, tokens, tags, etc.) from HTML pages and APIs, and outputs normalized JSON for downstream harness consumption. Only models available at no cost are collected; paid models are excluded.

## Input Sources

| Source | Website URL | API URL | Free Model Scope |
|--------|------------|---------|------------------|
| Cloudflare Workers AI | `https://developers.cloudflare.com/workers-ai/models/` | — | Models with `@cf` prefix (free tier) |
| Cohere | `https://docs.cohere.com/docs/models` | — | Free-tier models only |
| GitHub Marketplace | `https://github.com/marketplace?type=models` | `GET https://models.github.ai/catalog/models` | All models available via free rate limits |
| Groq | `https://console.groq.com/docs/models` | `GET https://api.groq.com/openai/v1/models` | Free models only (exclude paid) |
| Kilo AI Gateway | `https://kilo.ai/docs/gateway/models-and-providers` | `GET https://api.kilo.ai/api/gateway/models` | Free models only (identified by `:free` suffix) |
| LLM7 | `https://docs.llm7.io/guides/models` | `GET https://api.llm7.io/v1/models` | Turbo-tier (free) models only |
| Mistral AI | `https://mistral.ai/models/` | `GET https://api.mistral.ai/v1/models` (requires API key) | Open-weight/free models only |
| Modal | `https://modal.com/library` | — (data compiled into JS bundle) | Open-source models deployable on Modal |
| NVIDIA Build | `https://build.nvidia.com/models?orderBy=dateCreated%3ADESC&label=Coding` | `GET https://integrate.api.nvidia.com/v1/models` | Coding-tagged models with free tier |
| Ollama | `https://ollama.com/search?c=cloud` | `https://ollama.com/api/models` | Free cloud inference models only |
| OpenRouter | `https://openrouter.ai/models?max_output_price=0&output_modalities=text` | `GET https://openrouter.ai/api/v1/models` | Free models only (price = $0) |
| Pollinations AI | `https://gen.pollinations.ai/docs#tag/models` | `GET https://gen.pollinations.ai/models` | All models (virtual pollen currency, free to use) |
| Requesty | `https://www.requesty.ai/models?free=1` | `GET https://router.requesty.ai/v1/models` | Free models only (price = $0) |

> **Note**: API endpoints are the preferred method for listing models. Sources marked with `—` have no public, unauthenticated API available, so HTML scraping is the only option. Auth-required APIs (Mistral, Groq, Cohere) are listed but may fall back to HTML when credentials are unavailable.

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
| `source` | string | yes | Origin provider key: `"cloudflare"`, `"cohere"`, `"github"`, `"groq"`, `"kilo"`, `"llm7"`, `"mistral"`, `"modal"`, `"nvidia"`, `"ollama"`, `"openrouter"`, `"pollinations"`, or `"requesty"` |
| `api_name` | string | yes | Fully-qualified API identifier used in requests |
| `slug` | string | yes | URL-safe short identifier |
| `name` | string | yes | Human-readable display name |
| `provider` | string | yes | Model author/vendor (extracted from `api_name` or page metadata) |
| `parameters` | string | no | Parameter count string, e.g. `"7B"`, `"70B"`, `"2.7B"`. Omit if unavailable. |
| `quantization` | string | no | Quantization level, e.g. `"q4_k_m"`, `"q8_0"`. Omit if unavailable. |
| `context_length` | integer | no | Maximum context window in tokens. Omit if unavailable. |
| `tags` | array[string] | no | Classification tags (e.g. `["vision"]`, `["code"]`, `["embedding"]`) |
| `free` | boolean | yes | `true` if the model is available at no cost. `false` for paid-only models. |
| `deprecated` | boolean | no | `true` if the model is marked as deprecated/legacy. Omit if `false`. |
| `url` | string | yes | Permalink to the model's detail page |

## CLI Interface

```
Usage: model-discovery [OPTIONS] <SOURCE>

Arguments:
  <SOURCE>  Source to scrape [possible values: cloudflare, cohere, github, groq, kilo, llm7, mistral, modal, nvidia, ollama, openrouter, pollinations, requesty, all]

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
- Only collect models with `api_name` starting with `@cf` (free-tier eligible). Retain the `@cf` prefix in `api_name`.
- Extract `provider` from the first segment of `api_name` after `@cf`, e.g. `@cf/moonshotai/...` -> `provider: "moonshotai"`.
- The `slug` is the trailing path segment of the model's detail page URL.
- Pagination: follow "next page" links if present; stop when none remain.
- Gracefully skip rows whose structure differs from the expected model card format.

### Cohere

- Page: `https://docs.cohere.com/docs/models`
- Parse the models table/cards listing available Cohere models.
- Only collect models listed as free or with no associated cost. Skip models marked with paid-only pricing tiers.
- Extract `api_name` from the model's API identifier column (e.g. `command-r-plus`, `command-r`, `embed-english-v3.0`).
- Extract `context_length` if listed (Cohere documents max tokens per model).
- Extract `provider` as `"cohere"` for all models on this page.
- Filter out any model explicitly marked as deprecated, legacy, or retired.

### GitHub Marketplace

- **Primary (preferred)**: `GET https://models.github.ai/catalog/models` (public, no authentication required).
  - Response is a JSON array. Each entry maps to the data model as follows:
    - `source` -> `"github"`
    - `api_name` -> `id` field (e.g. `"openai/gpt-4.1"`)
    - `name` -> `name` field
    - `provider` -> `publisher` field
    - `tags` -> `tags` array
    - `context_length` -> `limits.max_input_tokens`
    - `url` -> `html_url` field
    - `capabilities` -> `capabilities` array (stored in a `capabilities` field if desired)
  - No pagination needed; the endpoint returns all models in a single response.
  - The API only returns active models; no explicit deprecated filtering is needed.
  - All models listed are available under free rate limits. Mark all as `free: true`.
- **Fallback**: Parse the HTML at `https://github.com/marketplace?type=models` when the API is unavailable.
  - The page requires authentication; the scraper must handle GitHub's sign-in redirect or use stored credentials.
  - Extract model cards from the marketplace grid listing.
  - Extract `api_name` from the model's card data or URL path (e.g. `/marketplace/models/azure-openai/gpt-4-1` -> `openai/gpt-4.1`).
  - All models on the marketplace page are available under free rate limits; mark all as `free: true`.
  - Fallback to HTML scraping only for non-interactive/SSR rendered content; skip dynamic client-side rendered sections.

### Groq

- Primary (preferred): Use the Groq API at `GET https://api.groq.com/openai/v1/models`. Requires `Authorization: Bearer <GROQ_API_KEY>` header. Returns a JSON array of active models with `id`, `owned_by`, `created`, etc.
  - `source` -> `"groq"`
  - `api_name` -> `id` field (e.g. `"llama-3.3-70b-versatile"`)
  - `provider` -> `owned_by` field
  - The API returns all models regardless of pricing. Cross-reference with the HTML page's PRICE column to identify and keep only free models.
- Fallback: Parse the HTML at `https://console.groq.com/docs/models` when the API key is unavailable.
  - The page lists models in tables with columns: MODEL ID, SPEED, PRICE, RATE LIMITS, CONTEXT WINDOW, MAX COMPLETION TOKENS.
  - Only collect models where PRICE is `$0.00` or listed as free. Skip any model with a non-zero price.
  - Extract `api_name` from the MODEL ID column.
  - Extract `context_length` from the CONTEXT WINDOW column.
  - Extract `provider` from the model name/icon label (e.g. Meta, OpenAI, Alibaba Cloud).
  - Extract `tags` from section headers: Production Models, Preview Models, Systems.
  - Skip the **Deprecated Models** section entirely.
  - Skip Preview models unless explicitly requested (they are marked as not for production use).

### Kilo AI Gateway

- Primary (preferred): `GET https://api.kilo.ai/api/gateway/models` (public, no authentication required).
  - Returns model info including model ID, provider, pricing, context window, and supported features.
  - `source` -> `"kilo"`
  - `api_name` -> Model ID field (e.g. `"anthropic/claude-sonnet-4.6"`)
  - `provider` -> Provider field (e.g. `"Anthropic"`, `"OpenAI"`, `"Google"`)
  - `context_length` -> from context window field
  - Models use the format `provider/model-name`; the provider segment can be extracted from the prefix.
  - Only collect free models. Free models are identified by a `:free` suffix in the model ID (e.g. `"stepfun/step-3.7-flash:free"`). Skip any model without this suffix.
  - Mark all collected models as `free: true`.
- Fallback: Parse the HTML at `https://kilo.ai/docs/gateway/models-and-providers`.
  - Extract free models from the "Free models" table specifically. Skip the "Popular models" table (paid).
  - Each row contains Model ID, Provider, and Description.
  - The `api_name` is the raw Model ID (e.g. `"stepfun/step-3.7-flash:free"`).
  - Free model IDs end with `:free` suffix.
  - Skip auto/routing models (e.g. `kilo-auto/*`).

### LLM7

- Primary (preferred): `GET https://api.llm7.io/v1/models` (public, no authentication required).
  - Returns a JSON object with a `data` array. Each entry maps as follows:
    - `source` -> `"llm7"`
    - `api_name` -> `id` field (e.g. `"gpt-5.4"`)
    - `provider` -> extract from the `id` prefix (e.g. `"gpt"`, `"gemini"`, `"claude"`)
    - `context_length` -> `context_window.tokens` field
    - `pricing` -> object with `input`/`output` prices in USD per 1M tokens
  - **Free model filter**: Only collect models where `tier` is `"turbo"` (free tier). Skip `"pro"` tier models.
  - No pagination needed; the endpoint returns all models in a single response.
- Fallback: Parse the HTML at `https://docs.llm7.io/guides/models`.
  - The page lists model selectors (`default`, `fast`, `pro`) and explains the API.
  - For concrete model IDs, the API is the preferred source.

### Mistral AI

- Page: `https://mistral.ai/models/`
- Primary: Parse the HTML page directly (the API at `GET https://api.mistral.ai/v1/models` requires authentication and is less accessible).
- The page lists models in cards with model ID, tags (Open/Premier/Labs), and description.
- Extract `api_name` from the model ID label on each card (e.g. `mistral-large-latest`, `mistral-small-latest`, `codestral-latest`, `ministral-8b-latest`, `mistral-embed`, `open-mistral-nemo`).
- Extract `provider` as `"Mistral"` for all models.
- Only collect models tagged as **Open** (open-weight, Apache 2.0 or similar license). Skip models tagged as **Premier** (paid API-only). Skip **Labs** models (experimental).
- Extract `context_length` from the model's specifications if listed on the card.
- Mark all collected models as `free: true`.

### Modal

- Page: `https://modal.com/library`
- No public API available. Model data is compiled into the SvelteKit JavaScript bundle at build time.
- Parse the rendered HTML page directly. Models are listed in category groups (Large language models, Audio transcription, Image generation, Text embedding).
- Each model card contains: `name`, `tag` (e.g. LLM, H100), `specs` (comma-separated tags), `description`, and a `link` to a detail page.
- Extract `api_name` from the model's name slugified (e.g. `"Kimi K3"` -> `"kimi-k3"`).
- Extract `provider` from the model name prefix or detail page content (e.g. `"Kimi K3"` -> `"Moonshot AI"`, `"Llama"` -> `"Meta"`).
- All models listed on Modal's library are open-source and free to download/run (compute costs apply on Modal). Mark all as `free: true`.
- Note: Modal is a compute platform, not a model provider. The library showcases open-source models you can deploy there.

### NVIDIA Build

- Page: `https://build.nvidia.com/models?orderBy=dateCreated%3ADESC&label=Coding`
- Primary (preferred): `GET https://integrate.api.nvidia.com/v1/models` (public, no authentication required).
  - Returns an OpenAI-compatible JSON object with a `data` array. Each entry maps as follows:
    - `source` -> `"nvidia"`
    - `api_name` -> `id` field (e.g. `"nvidia/llama-3.1-nemotron-70b-instruct"`)
    - `provider` -> `owned_by` field (e.g. `"nvidia"`, `"meta"`, `"mistralai"`)
  - The API does not provide pricing/free tier information. Cross-reference with the HTML page to determine which models have a free tier.
  - No pagination needed; the endpoint returns all models in a single response.
- Fallback: Parse the HTML at `https://build.nvidia.com/models?orderBy=dateCreated%3ADESC&label=Coding`.
  - Scope: Only models tagged with the `Coding` label that offer a free trial or free tier.
  - Filter out any model explicitly marked as **Deprecated** or **Legacy** on the page.
  - Filter out any model that requires payment (no free tier available).
  - Extract `api_name` from the model's API identifier field or card data attribute.
  - Extract `provider` from the author/publisher field on each model card.
  - Pagination: follow "Load more" or "next page" links; stop when none remain.
- Mark all collected models as `free: true`.

### Ollama

- Primary: Use the official Ollama API endpoint if available (`https://ollama.com/api/models` or similar documented endpoint).
- Fallback: Parse the HTML at `https://ollama.com/search?c=cloud` when the API is unavailable.
- Only collect models that offer free cloud inference. Skip models that require payment for API usage — even though the model weights are open-source, cloud hosting costs may apply.
- Look for a free tier indicator, tag, or price label on each model card. If a model has a non-zero price, skip it.
- The HTML fallback must not fail if page structure changes slightly — use fuzzy selectors and skip unrecognized blocks.
- Extract tags from category labels presented on the page.
- Mark all collected models as `free: true`.

### OpenRouter

- Primary (preferred): `GET https://openrouter.ai/api/v1/models` (public, no authentication required).
  - Returns a JSON object with a `data` array. Each entry maps as follows:
    - `source` -> `"openrouter"`
    - `api_name` -> `id` field (e.g. `"qwen/qwen3.7-flash"`)
    - `name` -> `name` field
    - `provider` -> extract from the `id` prefix (e.g. `"qwen/qwen3.7-flash"` -> `"qwen"`)
    - `context_length` -> `context_length` field
    - `pricing` -> object with `prompt` and `completion` price strings (per token)
  - **Free model filter**: Only collect models where both `pricing.prompt` and `pricing.completion` are `"0"`. Skip all paid models.
  - Model IDs often (but not always) end with `:free` suffix for free models. Always verify via pricing fields rather than relying on the suffix.
  - No pagination needed; the endpoint returns all models in a single response.
- Fallback: Parse the HTML at `https://openrouter.ai/models?max_output_price=0&output_modalities=text`.
  - The page is client-side rendered (React), so the scraper may need a headless browser or SSR snapshot.
  - The URL already filters for free (`max_output_price=0`) text-output models.
  - Extract model cards from the rendered grid.

### Pollinations AI

- Primary (preferred): `GET https://gen.pollinations.ai/models` (public, no authentication required).
  - Returns a JSON array of model objects. Each entry maps as follows:
    - `source` -> `"pollinations"`
    - `api_name` -> `name` field (e.g. `"openai"`, `"gpt-oss"`)
    - `name` -> `title` field (e.g. `"GPT-5.4 Nano"`)
    - `provider` -> `brand` field (e.g. `"OpenAI"`, `"Meta"`, `"Google"`)
    - `context_length` -> `context_length` field
    - `tags` -> `category` field (e.g. `"text"`, `"image"`, `"audio"`)
    - `input_modalities` -> `input_modalities` array
    - `output_modalities` -> `output_modalities` array
    - `pricing` -> object with `currency: "pollen"` (virtual currency, not real money)
  - All models use a virtual "pollen" currency and are free to use. Mark all as `free: true`.
  - No pagination needed; the endpoint returns all 240+ models in a single response.
  - Filter to text-output models only: only collect models where `"text"` is in `output_modalities`.

### Requesty

- Primary (preferred): `GET https://router.requesty.ai/v1/models` (public, no authentication required).
  - Returns a JSON object with a `data` array. Each entry maps as follows:
    - `source` -> `"requesty"`
    - `api_name` -> `id` field (e.g. `"anthropic/claude-haiku-4-5"`)
    - `provider` -> extract from the `id` prefix (e.g. `"anthropic/claude-haiku-4-5"` -> `"anthropic"`)
    - `context_length` -> `context_window` field
    - `max_output_tokens` -> `max_output_tokens` field
  - **Free model filter**: Only collect models where both `input_price` and `output_price` are `0`. Skip all paid models.
  - No pagination needed; the endpoint returns 589 models in a single response.

### Common Rules

- **Free models only**: Only collect models that are available at no cost. Set `free: true` for all output models. Skip any model that requires payment. The definition of "free" per source is detailed in the source-specific sections above.
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
    cohere.rs     -- Cohere docs page scraper
    github.rs     -- GitHub Marketplace catalog API scraper
    groq.rs       -- Groq API + HTML fallback scraper
    kilo.rs       -- Kilo AI Gateway API + HTML fallback scraper
    llm7.rs       -- LLM7 API + HTML fallback scraper
    mistral.rs    -- Mistral AI page scraper
    modal.rs      -- Modal library page scraper
    nvidia.rs     -- NVIDIA Build page scraper
    ollama.rs     -- Ollama API + HTML fallback scraper
    openrouter.rs -- OpenRouter API + HTML fallback scraper
    pollinations.rs -- Pollinations AI API scraper
    requesty.rs    -- Requesty API scraper
  model.rs        -- Model struct + serialization
  error.rs        -- Custom error types
```
