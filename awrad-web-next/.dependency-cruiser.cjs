/**
 * Module rules for awrad-web-next (same shape as the Android, iOS and server rules).
 * Run by `npm run validate` and CI.
 */
module.exports = {
  forbidden: [
    {
      name: "features-are-independent",
      comment: "A feature never imports another feature; shared code goes in src/shared.",
      severity: "error",
      from: { path: "^src/features/([^/]+)/" },
      to: { path: "^src/features/([^/]+)/", pathNot: "^src/features/$1/" },
    },
    {
      name: "shared-never-imports-features",
      severity: "error",
      from: { path: "^src/shared/" },
      to: { path: "^src/(features|routes|app)/" },
    },
    {
      name: "only-main-loads-the-dev-gallery",
      comment:
        "src/dev is development-only (the component gallery): only main.tsx loads it, behind import.meta.env.DEV, so it never reaches a production build.",
      severity: "error",
      from: { path: "^src/", pathNot: "^src/(dev/|main\\.tsx$)" },
      to: { path: "^src/dev/" },
    },
    {
      name: "only-shared-api-uses-the-network-client",
      comment: "openapi-fetch is wrapped once, in src/shared/api.",
      severity: "error",
      from: { path: "^src/", pathNot: "^src/shared/api/" },
      to: { path: "node_modules/openapi-fetch" },
    },
    {
      name: "routes-stay-thin",
      comment: "Route files map URLs to feature pages; they don't reach into shared/api directly.",
      severity: "error",
      from: { path: "^src/routes/" },
      to: { path: "^src/shared/api/" },
    },
    {
      name: "no-circular",
      severity: "error",
      from: {},
      to: { circular: true },
    },
    {
      name: "production-code-never-imports-tests",
      severity: "error",
      from: { path: "^src/", pathNot: "(\\.test\\.tsx?$|^src/test/)" },
      to: { path: "(\\.test\\.tsx?$|^src/test/)" },
    },
  ],
  options: {
    doNotFollow: { path: "node_modules" },
    exclude: { path: "(^dist/|routeTree\\.gen\\.ts$)" },
    tsConfig: { fileName: "tsconfig.app.json" },
    enhancedResolveOptions: { exportsFields: ["exports"], conditionNames: ["import", "require", "node", "default"] },
  },
};
