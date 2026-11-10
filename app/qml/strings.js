.pragma library
// UI texts (pl, en). The language comes from the phone setting (uiLang, main.py).
// A missing entry falls back to English; component titles fall back to the
// English title from the engine's component list.

var texts = {
    "title":         { "pl": "MeeRevive", "en": "MeeRevive" },
    "subtitle":      { "pl": "Wersja %1 · %2", "en": "Version %1 · %2 build" },
    "private":       { "pl": "prywatna", "en": "private" },
    "public":        { "pl": "publiczna", "en": "public" },
    "loading":       { "pl": "Sprawdzam telefon…", "en": "Checking the phone…" },
    "listError":     { "pl": "Nie udało się odczytać stanu telefonu", "en": "Could not read the phone's state" },
    "retry":         { "pl": "Spróbuj ponownie", "en": "Try again" },
    "install":       { "pl": "Zainstaluj", "en": "Install" },
    "installN":      { "pl": "Zainstaluj (%1)", "en": "Install (%1)" },
    "remove":        { "pl": "Usuń", "en": "Remove" },
    "removeAsk":     { "pl": "Usunąć „%1”?", "en": "Remove \"%1\"?" },
    "cancel":        { "pl": "Anuluj", "en": "Cancel" },
    "selectNeeded":  { "pl": "Zaznacz brakujące i nieaktualne", "en": "Select missing and outdated" },
    "selectNone":    { "pl": "Odznacz wszystko", "en": "Clear selection" },
    "backup":        { "pl": "Kopia do przeniesienia", "en": "Backup for moving" },
    "backupHint":    { "pl": "Zapisuje dane (m.in. subskrypcje Kanałów) w MyDocs/MeeRevive. Skopiuj ten folder na nowy telefon i wybierz tam „Przywróć z kopii”.",
                       "en": "Saves data (e.g. Feeds subscriptions) to MyDocs/MeeRevive. Copy that folder to the new phone and choose \"Restore from backup\" there." },
    "restore":       { "pl": "Przywróć z kopii", "en": "Restore from backup" },
    "tlsFinish":     { "pl": "Dokończ łatkę TLS", "en": "Finish TLS patch" },
    "check":         { "pl": "Sprawdź pakiet", "en": "Check package" },
    "log":           { "pl": "Dziennik", "en": "Log" },
    "reboot":        { "pl": "Uruchom ponownie", "en": "Restart phone" },
    "rebootAsk":     { "pl": "Uruchomić telefon ponownie teraz?", "en": "Restart the phone now?" },
    "rebootNeeded":  { "pl": "Potrzebne ponowne uruchomienie telefonu. Uruchomić teraz?", "en": "The phone needs a restart. Restart now?" },
    "yes":           { "pl": "Tak", "en": "Yes" },
    "no":            { "pl": "Nie", "en": "No" },
    "about":         { "pl": "O programie", "en": "About" },
    "aboutText":     { "pl": "Instaluje łatki i aplikacje, które przywracają Nokię N9 do życia: TLS 1.2, czcionkę emoji, przeglądarkę, pogodę i aplikacje.",
                       "en": "Installs the patches and apps that bring the Nokia N9 back to life: TLS 1.2, emoji font, browser, weather and apps." },
    "credit":        { "pl": "Zaprojektowany i napisany przez Claude (Anthropic) wspólnie ze smyhu dla Nokii N9.",
                       "en": "Designed and written by Claude (Anthropic) together with smyhu for the Nokia N9." },
    "close":         { "pl": "Zamknij", "en": "Close" },
    "working":       { "pl": "Pracuję… nie wyłączaj telefonu", "en": "Working… do not switch the phone off" },
    "doneOk":        { "pl": "Gotowe, bez błędów", "en": "Done, no errors" },
    "doneErr":       { "pl": "Zakończono z błędami (kod %1)", "en": "Finished with errors (code %1)" },
    "back":          { "pl": "Wróć", "en": "Back" },
    "nothing":       { "pl": "Zaznacz elementy na liście", "en": "Select items on the list" },
    "itemsN":        { "pl": "Elementy: %1", "en": "Items: %1" },
    "logFull":       { "pl": "Pełny dziennik", "en": "Full log" },
    "oldVersion":    { "pl": "starsza", "en": "older" },
    "needs":         { "pl": "wymaga: %1", "en": "needs: %1" },

    "st_installed":  { "pl": "zainstalowany", "en": "installed" },
    "st_missing":    { "pl": "brak", "en": "not installed" },
    "st_outdated":   { "pl": "do aktualizacji", "en": "update available" },
    "st_store":      { "pl": "wersja ze sklepu (zastąpimy)", "en": "store version (will be replaced)" },
    "st_partial":    { "pl": "niekompletny", "en": "incomplete" },
    "st_n/a":        { "pl": "nie dotyczy", "en": "not applicable" },

    "c_apt-sources":       { "pl": "Wyłącz martwe serwery apt" },
    "c_tls":               { "pl": "Łatka TLS 1.2 (n9-tls, OpenSSL 1.0.2u)" },
    "c_emoji-font":        { "pl": "Czcionka emoji (Symbola)" },
    "c_webp":              { "pl": "Obrazy WebP (wtyczka Qt + webp2jpg)" },
    "c_default-browser":   { "pl": "Linki otwiera przeglądarka systemowa (nie Opera)" },
    "c_waluty":            { "pl": "Waluty - kursy walut" },
    "c_lyrion-n9":         { "pl": "Lyrion - odtwarzacz i pilot muzyki" },
    "c_meetranslate":      { "pl": "MeeTranslate - tłumacz" },
    "c_hal2027":           { "pl": "HAL 2027 - asystent AI" },
    "c_forum-qml":         { "pl": "Klient forum talk.maemo.org (forum-qml)" },
    "c_feedmee":           { "pl": "FeedMee - wiadomości z ikonami serwisów na ekranie Wydarzenia" },
    "c_meeconf":           { "pl": "MeeConf - hurtowe zakładanie kont pocztowych (ręcznie i z CSV)" },
    "c_gpsinfo-n9":        { "pl": "GPS Info - satelity i mapa" },
    "c_ttrss":             { "pl": "Klient Tiny Tiny RSS" },
    "c_netmee-n9":         { "pl": "NetMee - lekka przeglądarka" },
    "c_authmee-n9":        { "pl": "AuthMee - kody 2FA" },
    "c_cloudgps-fix":      { "pl": "CloudGPS z wyszukiwaniem i trasami (samochód, pieszo, rower)" },
    "c_modrana":           { "pl": "modRana - mapy i wyszukiwanie" },
    "c_meerun":            { "pl": "MeeRun - trening sportowy z nowymi mapami (OSM, CyclOSM, OpenTopoMap, Esri)" },
    "c_meecast":           { "pl": "Pogoda MeeCast 1.1.33 (vasvlad)" },
    "c_meecast-applet":    { "pl": "Pogoda MeeCast w widoku Zdarzeń (zamiast AccuWeather)" },
    "c_meecast-openmeteo": { "pl": "Źródło pogody Open-Meteo dla MeeCast" },
    "c_kanaly":            { "pl": "Menedżer Kanałów (kanaly.sh: kopia, przywracanie, odświeżanie)" }
};

function t(lang, key) {
    var e = texts[key];
    if (!e) return key;
    return e[lang] !== undefined ? e[lang] : (e["en"] !== undefined ? e["en"] : key);
}

function a(lang, key, arg) { return t(lang, key).replace("%1", arg); }

function title(lang, id, fallback) {
    var e = texts["c_" + id];
    return (e && e[lang] !== undefined) ? e[lang] : fallback;
}
