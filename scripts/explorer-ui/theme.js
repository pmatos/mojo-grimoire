// Applies the saved theme before the page paints.
(function () {
  try {
    const saved = localStorage.getItem("explorer-theme");
    if (saved === "light" || saved === "dark") {
      document.documentElement.dataset.theme = saved;
    }
  } catch (e) {
    // No storage: the system's theme applies.
  }
})();
