// Lint rules are standards, enforced by `npm run validate` and CI (root ADR 0004 pattern).
import js from "@eslint/js";
import prettier from "eslint-config-prettier";
import i18next from "eslint-plugin-i18next";
import jsxA11y from "eslint-plugin-jsx-a11y";
import reactHooks from "eslint-plugin-react-hooks";
import globals from "globals";
import tseslint from "typescript-eslint";

export default tseslint.config(
  { ignores: ["dist", "src/routeTree.gen.ts", "src/shared/api/schema.gen.ts"] },
  js.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  ...tseslint.configs.stylisticTypeChecked,
  {
    languageOptions: {
      globals: globals.browser,
      parserOptions: { projectService: true, tsconfigRootDir: import.meta.dirname },
    },
  },
  // Hooks rules plus the React Compiler's rules (eslint-plugin-react-hooks 7).
  reactHooks.configs.flat["recommended-latest"],
  jsxA11y.flatConfigs.strict,
  // UI text lives in src/shared/i18n/locales, never inline (root AGENTS.md).
  i18next.configs["flat/recommended"],
  {
    rules: {
      // Same limit as the other three projects.
      "max-lines": ["error", { max: 400, skipBlankLines: false, skipComments: false }],
      "max-lines-per-function": ["error", { max: 80, skipBlankLines: true, skipComments: true }],
      "@typescript-eslint/explicit-module-boundary-types": "error",
      "@typescript-eslint/switch-exhaustiveness-check": "error",
      "@typescript-eslint/consistent-type-imports": "error",
      "no-restricted-globals": ["error", { name: "fetch", message: "Use `api` from @/shared/api/client." }],
    },
  },
  {
    // Tests and the API client may use fetch and test-only literals.
    files: ["src/**/*.test.{ts,tsx}", "src/test/**", "src/shared/api/client.ts"],
    rules: { "no-restricted-globals": "off", "i18next/no-literal-string": "off" },
  },
  {
    // Config files and Node scripts: plain JS, not part of a TypeScript project.
    files: ["**/*.{js,cjs,mjs}"],
    ...tseslint.configs.disableTypeChecked,
    languageOptions: { ...tseslint.configs.disableTypeChecked.languageOptions, globals: globals.node },
    rules: { ...tseslint.configs.disableTypeChecked.rules, "i18next/no-literal-string": "off" },
  },
  {
    files: ["vite.config.ts"],
    languageOptions: { globals: globals.node },
    rules: { "i18next/no-literal-string": "off" },
  },
  prettier,
);
