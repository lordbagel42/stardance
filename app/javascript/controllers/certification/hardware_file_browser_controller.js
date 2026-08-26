import { Controller } from "@hotwired/stimulus";

// Loads the cockpit file-browser card. On connect it fetches the file tree +
// README from `urlValue` and injects them (a rail of files beside a preview
// pane). Clicking a file fetches that file from `previewUrlValue` and swaps only
// the preview pane; "README" restores the default README view. Kept off the main
// cockpit render so first paint never waits on GitHub HTTP.
export default class extends Controller {
  static values = { url: String, previewUrl: String };
  static targets = ["content"];

  connect() {
    this.load();
  }

  // The preview pane lives inside the injected content; query it live rather than
  // as a target so we don't race the Stimulus target scan right after injection.
  get previewEl() {
    return this.element.querySelector(".hardware-cockpit__preview");
  }

  async load() {
    if (!this.hasContentTarget || !this.urlValue) return;

    this.renderStatus(this.contentTarget, "Loading files…", { spinner: true });

    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "text/html" },
        credentials: "same-origin",
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      this.contentTarget.innerHTML = await response.text();
      // Snapshot the default README so "README" can restore it without a refetch.
      this.readmeHtml = this.previewEl ? this.previewEl.innerHTML : null;
    } catch (error) {
      this.renderError();
    }
  }

  async select(event) {
    const button = event.currentTarget;
    const path = button.dataset.path;
    const pane = this.previewEl;
    if (!path || !pane) return;

    this.setActive(button);
    this.renderStatus(pane, "Loading…", { spinner: true });

    try {
      const url = `${this.previewUrlValue}?path=${encodeURIComponent(path)}`;
      const response = await fetch(url, {
        headers: { Accept: "text/html" },
        credentials: "same-origin",
      });
      // The endpoint renders a fragment even for not-found/errors, so show it.
      pane.innerHTML = await response.text();
    } catch (error) {
      pane.innerHTML =
        '<p class="hardware-cockpit__files-note" role="alert">Couldn\'t load this file.</p>';
    }
  }

  showReadme() {
    this.setActive(null);
    if (this.previewEl && this.readmeHtml != null) {
      this.previewEl.innerHTML = this.readmeHtml;
    }
  }

  setActive(button) {
    this.element
      .querySelectorAll(".hardware-cockpit__file.is-active")
      .forEach((el) => el.classList.remove("is-active"));
    if (button) button.classList.add("is-active");
  }

  renderStatus(target, text, { spinner = false } = {}) {
    const spinnerEl = spinner
      ? '<span class="hardware-cockpit__files-spinner" aria-hidden="true"></span>'
      : "";
    target.innerHTML = `<div class="hardware-cockpit__files-status" role="status">${spinnerEl}${text}</div>`;
  }

  renderError() {
    this.contentTarget.innerHTML =
      '<div class="hardware-cockpit__files-status" role="alert">' +
      "Couldn't load files. " +
      '<button type="button" class="hardware-cockpit__files-retry" data-action="certification--hardware-file-browser#load">Retry</button>' +
      "</div>";
  }
}
