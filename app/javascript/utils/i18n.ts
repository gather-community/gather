import { I18n } from "i18n-js";
import translations from "../i18n/translations.json";

const i18n = new I18n(translations);
i18n.defaultLocale = "en";
i18n.locale = document.documentElement.lang || "en";

// Expose globally for legacy Backbone/jQuery code
(window as any).I18n = i18n;

export default i18n;
