# awrad-web-next

The Awrad web app (React 19, TypeScript, Vite), an online-only client of `awrad-server-next`'s API. Start with [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`AGENTS.md`](AGENTS.md).

```bash
npm ci
npm run dev          # http://localhost:5173, proxying /api and /socket to Phoenix on :4000
npm run validate     # the validation command CI runs
```
