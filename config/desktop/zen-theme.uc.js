// ==UserScript==
// @name           blousy_desktop_theme
// @namespace      blousy_desktop_theme
// @version        1.1.0
// @description    Hot-reload generated desktop CSS into Zen's browser chrome.
// @onlyonce
// ==/UserScript==

(function () {
  "use strict";

  const styleId = "blousy-desktop-theme";
  const home = Services.dirsvc.get("Home", Ci.nsIFile).path;
  const stateHome = Services.env.get("XDG_STATE_HOME")
    || PathUtils.join(home, ".local", "state");
  const themePath = PathUtils.join(
    stateHome,
    "blousy",
    "zen-theme.css"
  );

  let fingerprint = "";
  let currentCss = "";
  let refreshing = false;
  const loadedSheets = new WeakMap();

  function validCss(css) {
    return typeof css === "string"
      && css.includes("--blousy-zen-primary");
  }

  function applyTheme(win, css) {
    const windowUtils = win?.windowUtils;
    if (!windowUtils)
      return;

    const oldSheet = loadedSheets.get(win);
    if (oldSheet) {
      try {
        windowUtils.removeSheet(oldSheet, windowUtils.USER_SHEET);
      } catch {}
    }

    const sheet = Services.io.newURI(
      `data:text/css;charset=utf-8,${encodeURIComponent(css)}#${styleId}`
    );
    windowUtils.loadSheet(sheet, windowUtils.USER_SHEET);
    loadedSheets.set(win, sheet);
  }

  function applyToAllWindows(css) {
    const windows = Services.wm.getEnumerator("navigator:browser");
    while (windows.hasMoreElements())
      applyTheme(windows.getNext(), css);
  }

  async function refresh() {
    if (refreshing)
      return;
    refreshing = true;

    try {
      const stat = await IOUtils.stat(themePath);
      const nextFingerprint = `${stat.lastModified}:${stat.size}`;
      if (nextFingerprint === fingerprint)
        return;

      const css = await IOUtils.readUTF8(themePath);
      if (!validCss(css))
        throw new Error("invalid generated CSS");

      fingerprint = nextFingerprint;
      currentCss = css;
      applyToAllWindows(css);
    } catch (error) {
      if (error.name !== "NotFoundError")
        console.error(`[blousy theme] ${error}`);
    } finally {
      refreshing = false;
    }
  }

  UC_API.Windows.onCreated(win => {
    if (currentCss)
      applyTheme(win, currentCss);
  });

  const interval = window.setInterval(refresh, 500);
  window.addEventListener(
    "unload",
    () => window.clearInterval(interval),
    { once: true }
  );
  refresh();
})();
