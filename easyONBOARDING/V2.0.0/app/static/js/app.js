document.body.addEventListener("htmx:afterSwap", () => {
    const refreshed = document.querySelector("#metrics-grid");
    if (refreshed) {
        refreshed.dataset.lastRefresh = new Date().toISOString();
    }

    const previewSource = document.querySelector("#preview_markdown");
    if (previewSource) {
        previewSource.dataset.lastPreviewSync = new Date().toISOString();
    }
});
