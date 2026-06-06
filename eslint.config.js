import js from "@eslint/js"
import globals from "globals"

export default [
  {
    ignores: [
      "app/assets/builds/**",
      "node_modules/**"
    ]
  },
  {
    files: ["app/javascript/**/*.js"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: {
        ...globals.browser,
        bootstrap: "readonly",
        Cropper: "readonly",
        Turbo: "readonly"
      }
    },
    rules: {
      ...js.configs.recommended.rules,
      "curly": ["error", "multi-line"],
      "eqeqeq": ["error", "always", { null: "ignore" }],
      "no-console": ["warn", { allow: ["warn", "error"] }],
      "no-duplicate-imports": "error",
      "no-var": "error",
      "prefer-const": ["error", { destructuring: "all" }],
      "no-unused-vars": ["error", {
        argsIgnorePattern: "^_",
        caughtErrorsIgnorePattern: "^_",
        varsIgnorePattern: "^_"
      }]
    }
  }
]
