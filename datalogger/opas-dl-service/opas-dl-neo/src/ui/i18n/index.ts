import i18n from "i18next";
import { initReactI18next } from "react-i18next";

import it from "./locales/it.json";
import en from "./locales/en.json";

i18n
  .use(initReactI18next)
  .init({
    resources: {
      it: { translation: it },
      en: { translation: en },
    },
    lng: localStorage.getItem("lang") || "it",
    fallbackLng: "en",
    interpolation: {
      escapeValue: false,
    },
  });

export default i18n;