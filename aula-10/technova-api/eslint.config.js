import js from "@eslint/js";
import globals from "globals";

/** @type {import("eslint").Linter.Config[]} */
export default [
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      globals: {
        ...globals.node,
        ...globals.jest,
      },
    },
    rules: {
      // Erros reais
      "no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
      "no-console": "off",
      "eqeqeq": ["error", "always"],

      // Estilo
      "semi": ["error", "always"],
      "quotes": ["error", "single"],
      "indent": ["error", 2],
      "no-trailing-spaces": "error",
      "eol-last": ["error", "always"],
    },
  },
];
