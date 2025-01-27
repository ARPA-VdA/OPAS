import globals from "globals";
import pluginJs from "@eslint/js";

//  https://eslint.org/docs/latest/use/getting-started
export default [
  {files: ["**/*.js"], languageOptions: {sourceType: "script"}},
  {languageOptions: { globals: globals.browser }},
  pluginJs.configs.recommended,
  {
      rules: {
          "no-unused-vars": "error",
          "no-undef": "error",
          "parserOptions": {
            "sourceType": "module"
          }
      }
  }
];