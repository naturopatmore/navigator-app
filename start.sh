#!/bin/sh
pnpm --filter @workspace/db run push-force || true
node --enable-source-maps artifacts/api-server/dist/index.mjs
