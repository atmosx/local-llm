#!/usr/bin/env bash

/opt/local/bin/llama server \
	-hf ggml-org/Qwen3.8-27B-GGUF:Q4_K_M \
	-hfd ggml-org/Qwen3.8-27B-GGUF:Q4_0 \
	--alias qwen3.8-27b \
	--metrics \
	--spec-default \
	--spec-type draft-mtp \
	--reasoning-preserve \
	--host 192.168.102.73 \
	--port 9931 \
	-lv 2 \
	--image-min-tokens 1024 \
	--api-key 'HERE_GOES_THE_API_KEY'
