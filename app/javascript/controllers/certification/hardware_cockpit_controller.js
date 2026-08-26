import { Controller } from "@hotwired/stimulus";

// Drives the hardware review cockpit:
//   1. Contextual shortcut bar — shows the global shortcuts always plus the set
//      for whichever region (devlogs / project / actions) holds focus.
//   2. Top-bar claim countdown (HH:MM:SS), skew-corrected against the server.
//   3. Keyboard shortcuts — devlog navigation, image/timelapse lightbox, and
//      arm-then-confirm verdict submission.
export default class extends Controller {
  static targets = ["countdown", "escHint"];
  static values = { expiresAt: String, serverNow: String };

  connect() {
    this.onFocusIn = this.onFocusIn.bind(this);
    this.onKeydown = this.onKeydown.bind(this);
    this.element.addEventListener("focusin", this.onFocusIn);
    document.addEventListener("keydown", this.onKeydown);
    this.activate(null);
    this.startCountdown();
    this.currentDevlog = 0;
    this.armed = null;
  }

  disconnect() {
    this.element.removeEventListener("focusin", this.onFocusIn);
    document.removeEventListener("keydown", this.onKeydown);
    this.stopCountdown();
    this.closeLightbox();
    this.clearArm();
  }

  // ── Contextual shortcut bar ──────────────────────────────────────────────
  onFocusIn(event) {
    const region = event.target.closest("[data-cockpit-region]");
    this.activate(region ? region.dataset.cockpitRegion : null);
  }

  activate(region) {
    this.element.querySelectorAll("[data-cockpit-group]").forEach((group) => {
      group.hidden = group.dataset.cockpitGroup !== region;
    });
  }

  // ── Claim countdown ──────────────────────────────────────────────────────
  startCountdown() {
    if (!this.hasCountdownTarget || !this.expiresAtValue) return;
    this.expiresAt = new Date(this.expiresAtValue).getTime();
    const serverNow = this.serverNowValue ? new Date(this.serverNowValue).getTime() : Date.now();
    this.timeOffset = serverNow - Date.now();
    this.tick();
    this.timer = setInterval(() => this.tick(), 1000);
  }

  stopCountdown() {
    if (this.timer) clearInterval(this.timer);
  }

  tick() {
    const remaining = this.expiresAt - (Date.now() + this.timeOffset);
    this.countdownTarget.textContent = this.formatClock(remaining);
    if (remaining <= 0) this.stopCountdown();
  }

  formatClock(ms) {
    const total = Math.max(0, Math.floor(ms / 1000));
    const pad = (n) => String(n).padStart(2, "0");
    return `${pad(Math.floor(total / 3600))}h:${pad(Math.floor((total % 3600) / 60))}m:${pad(total % 60)}s`;
  }

  // ── Keyboard shortcuts ───────────────────────────────────────────────────
  onKeydown(event) {
    if (event.altKey) return;
    const ctrl = event.ctrlKey || event.metaKey;

    // The lightbox is modal: it captures escape + arrows and blocks the rest.
    if (this.lightbox) {
      if (event.key === "Escape") return this.consume(event, () => this.closeLightbox());
      // Video → Premiere-style JKL transport + arrow scrubbing (shift = coarse).
      if (this.lbVideo) {
        if (event.code === "KeyJ") return this.consume(event, () => this.nudgeRate(-1));
        if (event.code === "KeyK") return this.consume(event, () => this.togglePlay());
        if (event.code === "KeyL") return this.consume(event, () => this.nudgeRate(1));
        if (event.key === "ArrowLeft") return this.consume(event, () => this.stepVideo(event.shiftKey ? -10 : -1));
        if (event.key === "ArrowRight") return this.consume(event, () => this.stepVideo(event.shiftKey ? 10 : 1));
        return;
      }
      // Images → prev/next.
      if (event.key === "ArrowLeft") return this.consume(event, () => this.stepLightbox(-1));
      if (event.key === "ArrowRight") return this.consume(event, () => this.stepLightbox(1));
      return;
    }

    // Escape cancels an armed verdict, otherwise unfocuses the current card/field.
    if (event.key === "Escape") {
      if (this.armed) return this.consume(event, () => this.clearArm());
      const focused = document.activeElement;
      if (focused && focused !== document.body && this.element.contains(focused)) {
        return this.consume(event, () => focused.blur());
      }
      return;
    }

    // Ctrl combos are safe even while typing — they never insert text.
    if (ctrl && event.code === "Space") return this.consume(event, () => this.focusDevlogs());
    if (ctrl && event.key === "Enter") return this.consume(event, () => this.focusFeedback());
    if (ctrl && event.key === "ArrowDown") return this.consume(event, () => this.stepDevlog(1));
    if (ctrl && event.key === "ArrowUp") return this.consume(event, () => this.stepDevlog(-1));
    if (ctrl && event.code === "KeyP") return this.consume(event, () => this.armVerdict("approve"));
    if (ctrl && event.code === "KeyE") return this.consume(event, () => this.armVerdict("return"));

    // Single-key shortcuts must not fight text entry.
    if (ctrl || this.isTyping(event.target)) return;

    if (event.shiftKey && event.code === "KeyD") return this.consume(event, () => this.scrollToDevlogPart("body"));
    if (event.shiftKey && event.code === "KeyI") return this.consume(event, () => this.scrollToDevlogPart("gallery"));
    if (event.shiftKey && event.code === "KeyT") return this.consume(event, () => this.openTimelapse());
    const image = { Digit1: 0, Digit2: 1, Digit3: 2 }[event.code];
    if (event.shiftKey && image !== undefined) return this.consume(event, () => this.openImage(image));
  }

  consume(event, fn) {
    event.preventDefault();
    fn();
  }

  isTyping(el) {
    if (!el) return false;
    return ["INPUT", "TEXTAREA", "SELECT"].includes(el.tagName) || el.isContentEditable;
  }

  // ── Devlog navigation ────────────────────────────────────────────────────
  devlogEls() {
    return Array.from(this.element.querySelectorAll(".hardware-cockpit__devlog"));
  }

  focusDevlogs() {
    this.element.querySelector(".hardware-cockpit__col--devlogs")?.focus();
    this.setDevlog(this.currentDevlog);
  }

  stepDevlog(delta) {
    this.setDevlog(this.currentDevlog + delta);
  }

  setDevlog(index) {
    const els = this.devlogEls();
    if (!els.length) return;
    this.currentDevlog = Math.max(0, Math.min(index, els.length - 1));
    els.forEach((el, i) => el.classList.toggle("is-current", i === this.currentDevlog));
    // Align the current devlog to the top of the column so it doesn't ride the
    // bottom edge once the list has scrolled (scroll-margin-top gives it breathing
    // room below the config bar).
    els[this.currentDevlog].scrollIntoView({ block: "start", behavior: "smooth" });
  }

  // Reorder the devlog cards by timestamp (newest/oldest), driven by the config
  // bar's sort segments.
  sortDevlogs(event) {
    const order = event.currentTarget.dataset.order;
    const list = this.element.querySelector(".hardware-cockpit__devlogs");
    if (!list) return;
    this.devlogEls()
      .sort((a, b) => {
        const at = Number(a.dataset.time || 0), bt = Number(b.dataset.time || 0);
        return order === "oldest" ? at - bt : bt - at;
      })
      .forEach((el) => list.appendChild(el));
    this.element.querySelectorAll(".hardware-cockpit__config-btn").forEach((b) => {
      const on = b === event.currentTarget;
      b.classList.toggle("is-active", on);
      b.setAttribute("aria-pressed", on ? "true" : "false");
    });
    this.setDevlog(0);
  }

  currentDevlogEl() {
    return this.devlogEls()[this.currentDevlog] || null;
  }

  scrollToDevlogPart(part) {
    const devlog = this.currentDevlogEl();
    if (!devlog) return this.focusDevlogs();
    const selector = part === "gallery"
      ? ".feed-post-card__media, .hardware-cockpit__timelapses"
      : ".hardware-cockpit__devlog-body";
    (devlog.querySelector(selector) || devlog).scrollIntoView({ block: "nearest", behavior: "smooth" });
  }

  focusFeedback() {
    const card = this.element.querySelector(".hardware-cockpit__card--feedback");
    if (!card) return;
    // Prefer the feedback textarea; fall back to the card itself (idle state has
    // no field). Skip the form's hidden/file inputs — they can't take focus.
    const field = card.querySelector("textarea") || card;
    field.focus();
    field.scrollIntoView({ block: "nearest", behavior: "smooth" });
  }

  // ── Verdict: arm then confirm ────────────────────────────────────────────
  verdictButton(kind) {
    return this.element.querySelector(`.hardware-cockpit__action--${kind}`);
  }

  armVerdict(kind) {
    const button = this.verdictButton(kind);
    if (!button || button.disabled) return;
    if (this.armed === kind) {
      this.clearArm();
      button.click();
      return;
    }
    this.clearArm();
    this.armed = kind;
    button.classList.add("is-armed");
    this.showEscHint(kind);
    this.armTimer = setTimeout(() => this.clearArm(), 4000);
  }

  clearArm() {
    if (this.armTimer) clearTimeout(this.armTimer);
    if (this.armed) this.verdictButton(this.armed)?.classList.remove("is-armed");
    this.armed = null;
    this.hideEscHint();
  }

  // While a verdict is armed, spell out the confirm/cancel keys in the top bar.
  showEscHint(kind) {
    if (!this.hasEscHintTarget) return;
    const key = kind === "approve" ? "ctrl+p" : kind === "return" ? "ctrl+e" : "the shortcut";
    this.escHintTarget.textContent = `press ${key} again to ${kind} · esc to cancel`;
    this.escHintTarget.hidden = false;
  }

  hideEscHint() {
    if (this.hasEscHintTarget) this.escHintTarget.hidden = true;
  }

  // ── Lightbox for devlog images + timelapses ──────────────────────────────
  openImage(index) {
    const devlog = this.currentDevlogEl();
    if (!devlog) return;
    const items = Array.from(devlog.querySelectorAll(".feed-post-card__image"))
      .map((img) => ({ type: "image", src: img.currentSrc || img.src, alt: img.alt }));
    if (items.length && index < items.length) this.showLightbox(items, index);
  }

  openTimelapse() {
    const devlog = this.currentDevlogEl();
    if (!devlog) return;
    const items = Array.from(devlog.querySelectorAll(".hardware-cockpit__timelapse"))
      .map((a) => ({ type: "video", src: a.href }));
    if (items.length) this.showLightbox(items, 0);
  }

  // Clicking a timelapse tile opens it in the JKL lightbox instead of navigating
  // to the raw R2 video. Loads the devlog's lapses starting at the clicked one.
  openLapse(event) {
    event.preventDefault();
    const link = event.currentTarget;
    const devlog = link.closest(".hardware-cockpit__devlog");
    if (!devlog) return;
    const links = Array.from(devlog.querySelectorAll(".hardware-cockpit__timelapse"));
    const items = links.map((a) => ({ type: "video", src: a.href }));
    if (items.length) this.showLightbox(items, Math.max(0, links.indexOf(link)));
  }

  showLightbox(items, index) {
    this.closeLightbox();
    this.lbItems = items;
    this.lbIndex = index;

    const box = document.createElement("div");
    box.className = "hardware-cockpit__lightbox";
    box.setAttribute("role", "dialog");
    box.setAttribute("aria-modal", "true");
    box.addEventListener("click", (e) => { if (e.target === box) this.closeLightbox(); });

    const close = document.createElement("button");
    close.type = "button";
    close.className = "hardware-cockpit__lightbox-close";
    close.setAttribute("aria-label", "Close");
    close.textContent = "×";
    close.addEventListener("click", () => this.closeLightbox());

    this.lbStage = document.createElement("div");
    this.lbStage.className = "hardware-cockpit__lightbox-stage";
    this.lbCaption = document.createElement("p");
    this.lbCaption.className = "hardware-cockpit__lightbox-caption";

    box.append(close, this.lbStage, this.lbCaption);
    this.element.appendChild(box);
    this.lightbox = box;
    this.renderLightbox();
  }

  renderLightbox() {
    const item = this.lbItems[this.lbIndex];
    this.stopReverse();
    this.lbStage.innerHTML = "";
    if (item.type === "video") {
      const video = document.createElement("video");
      Object.assign(video, { src: item.src, controls: true, autoplay: true, playsInline: true });
      video.className = "hardware-cockpit__lightbox-media";
      this.lbStage.appendChild(video);
      this.lbVideo = video;
      this.rate = 1;      // signed speed: + forward, − reverse, 0 paused (autoplay = 1×)
      this.lastRate = 1;  // K resumes here after a pause
      this.updatePlayerCaption();
    } else {
      const img = document.createElement("img");
      img.src = item.src;
      img.alt = item.alt || "";
      img.className = "hardware-cockpit__lightbox-media";
      this.lbStage.appendChild(img);
      this.lbVideo = null;
      const nav = this.lbItems.length > 1 ? " · ←/→" : "";
      this.lbCaption.textContent = `${this.lbIndex + 1} / ${this.lbItems.length}${nav} · esc to close`;
    }
  }

  // ── Premiere-style JKL transport ─────────────────────────────────────────
  // One shared signed-speed ladder: L nudges toward faster-forward, J toward
  // faster-reverse, meeting in the middle (…4×▶ 2×▶ 1×▶ | 1×◀ 2×◀…). So from 8×
  // forward, J steps down to 4×. HTML5 video can't play backwards, so reverse is
  // emulated with a timer that walks currentTime back.
  RATE_LADDER = [ -8, -4, -2, -1, 1, 2, 4, 8 ];

  nudgeRate(direction) {
    if (!this.lbVideo) return;
    let next;
    if (!this.rate) {
      next = direction > 0 ? 1 : -1;
    } else {
      const i = this.RATE_LADDER.indexOf(this.rate);
      next = i === -1
        ? (direction > 0 ? 1 : -1)
        : this.RATE_LADDER[Math.max(0, Math.min(this.RATE_LADDER.length - 1, i + direction))];
    }
    this.applyRate(next);
  }

  // K: pause when playing, resume the last speed when paused.
  togglePlay() {
    if (!this.lbVideo) return;
    this.applyRate(this.rate ? 0 : this.lastRate || 1);
  }

  applyRate(rate) {
    if (!this.lbVideo) return;
    this.rate = rate;
    if (rate) this.lastRate = rate;
    this.stopReverse();
    if (rate > 0) {
      this.lbVideo.playbackRate = rate;
      this.lbVideo.play();
    } else if (rate < 0) {
      this.lbVideo.pause();
      this.reverseSpeed = -rate;
      this.startReverse();
    } else {
      this.lbVideo.pause();
    }
    this.updatePlayerCaption();
  }

  startReverse() {
    this.stopReverse();
    this.reverseTimer = setInterval(() => {
      if (!this.lbVideo) return this.stopReverse();
      const t = this.lbVideo.currentTime - this.reverseSpeed * 0.066;
      if (t <= 0) {
        this.lbVideo.currentTime = 0;
        this.applyRate(0); // hit the start → stop
      } else {
        this.lbVideo.currentTime = t;
      }
    }, 66);
  }

  stopReverse() {
    if (this.reverseTimer) clearInterval(this.reverseTimer);
    this.reverseTimer = null;
  }

  stepVideo(seconds) {
    if (!this.lbVideo) return;
    this.applyRate(0); // frame-scrub pauses first
    const max = this.lbVideo.duration || Number.MAX_SAFE_INTEGER;
    this.lbVideo.currentTime = Math.max(0, Math.min(max, this.lbVideo.currentTime + seconds));
    this.updatePlayerCaption();
  }

  updatePlayerCaption() {
    if (!this.lbVideo || !this.lbCaption) return;
    const mode = this.rate > 0 ? `▶ ${this.rate}×`
      : this.rate < 0 ? `◀ ${-this.rate}×`
      : "❚❚ paused";
    this.lbCaption.textContent =
      `${this.lbIndex + 1} / ${this.lbItems.length} · ${mode} · J/K/L · ←/→ scrub (shift = 10s) · esc`;
  }

  stepLightbox(direction) {
    const count = this.lbItems.length;
    this.lbIndex = (this.lbIndex + direction + count) % count;
    this.renderLightbox();
  }

  closeLightbox() {
    this.stopReverse();
    this.lightbox?.remove();
    this.lightbox = null;
    this.lbVideo = null;
  }
}
