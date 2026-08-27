import { Controller } from "@hotwired/stimulus";

// Thin loader for the 3D file preview: it pulls the heavy three.js/OpenCASCADE
// bundle on demand (kept out of application.js) and hands it the canvas. The
// bundle URL is resolved by the asset pipeline and passed in, so it stays correct
// under digested asset names. Disposes the scene on disconnect so swapping the
// preview doesn't leak WebGL contexts.
export default class extends Controller {
  static targets = ["canvas", "status"];
  static values = { src: String, format: String, bundleUrl: String, wasmUrl: String };

  async connect() {
    try {
      // Assigned to a variable so esbuild leaves it as a runtime import rather
      // than inlining the bundle into application.js.
      const url = this.bundleUrlValue;
      const mod = await import(url);
      this.dispose = await mod.renderModel({
        canvas: this.canvasTarget,
        src: this.srcValue,
        format: this.formatValue,
        wasmUrl: this.wasmUrlValue,
      });
      if (this.hasStatusTarget) this.statusTarget.remove();
    } catch (error) {
      const reason = error?.message || "your browser may not support WebGL";
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = `Couldn't render this model — ${reason}`;
      }
    }
  }

  disconnect() {
    this.dispose?.();
    this.dispose = null;
  }
}
