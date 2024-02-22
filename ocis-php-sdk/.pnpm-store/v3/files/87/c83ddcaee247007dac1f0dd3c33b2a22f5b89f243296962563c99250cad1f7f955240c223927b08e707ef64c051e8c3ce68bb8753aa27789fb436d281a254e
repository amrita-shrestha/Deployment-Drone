// NOTE(longsleep): This loads all translation files to be included in the
// app bundle. They are not that large.

// Please keep imports and exports alphabetically sorted.
import de from './de.json';
import fr from './fr.json';
import hi from './hi.json';
import is from './is.json';
import nb from './nb.json';
import nl from './nl.json';
import ptPT from './pt_PT.json';
import ru from './ru.json';

// Locales must follow BCP 47 format (https://tools.ietf.org/html/rfc5646).
export const locales = {
  de,
  'en-GB': {},
  'en-US': {},
  fr,
  hi,
  is,
  nb,
  nl,
  'pt-PT': ptPT,
  ru,
};

export default locales;

/**
 * Helper function to merge two locale objects into one. The function will
 * return a new locales object, containing all keys from l1 and l2, having
 * keys from l2 override keys from l1.
 */
export function mergeLocales(l1, l2) {
  const l = {
    ...l1,
  };
  for (let locale of Object.keys(l2)) {
    l[locale] = {
      ...l1[locale],
      ...l2[locale],
    };
  }
  return l;
}

/**
 * Helper function to merge a locale object with additional messages, returning
 * only a single locale's messages.
 */
export function mergeLocaleWithMessages(locales, messages, locale) {
  locales = locales ? locales : {};
  messages = messages ? messages : {};
  const localeBase = locale.split('-', 1)[0];
  if (localeBase !== locale) {
    return {
      ...locales[localeBase],
      ...locales[locale],
      ...messages,
    };
  } else {
    return {
      ...locales[locale],
      ...messages,
    };
  }
}

/**
 * Helper function to simplify initialization of app locale together with
 * locale defined by kpop.
 */
export function defineLocale(localeMessages, locale) {
  return mergeLocaleWithMessages(locales, localeMessages, locale);
}

/**
 * Helper function to simplify initialization of app locales together with
 * locales defined by kpop.
 */
export function defineLocales(appLocales) {
  return mergeLocales(locales, appLocales);
}
