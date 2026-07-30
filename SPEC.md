# Model Discovery
> Model discovery is a cli app that scrapes ai models names and api names, parameters, quantization, context length, tokens, tags, etc. from dirty html or apis and turns it into clean jsons so we can have it for our custom harness later. written in rust 


# Websites

1. Cloudflare - https://developers.cloudflare.com/workers-ai/models/ (all the free models start with @cf)
2. Ollama - https://ollama.com/search?c=cloud


> for cloudflare a model looks like this api_name: @cf/moonshotai/kimi-k2.7-code slug: kimi-k2.7-code, Name: Kimi K2.7 (readable name)
> Ollama has an API as well but just in case it must be able to do it through the html as well