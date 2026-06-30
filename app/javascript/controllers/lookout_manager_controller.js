import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "row",
    "tab",
    "existingSelect",
    "newName",
    "projectNameField",
  ];

  connect() {
    this._activeId = null;
  }

  rowTargetConnected(row) {
    this._syncRow(row);
    if (!this._activeId) this._activeId = row.id;
    this._syncDisplay();
    if (!this.element.open) this.element.showModal();
  }

  rowTargetDisconnected(row) {
    if (this.rowTargets.length === 0) {
      this.element.close();
      return;
    }
    if (this._activeId === row.id) {
      this._activeId = this.rowTargets[0].id;
    }
    this._syncDisplay();
  }

  switchTab(event) {
    this._activeId = event.currentTarget.dataset.rowId;
    this._syncDisplay();
  }

  destinationChanged(event) {
    const row = event.target.closest(".lookout-manager__row");
    if (row) this._syncRow(row);
  }

  selectExisting(event) {
    const row = event.target.closest(".lookout-manager__row");
    if (!row) return;
    const radio = row.querySelector(
      "input[name^='lookout-dest'][value='existing']",
    );
    if (radio && !radio.disabled) {
      radio.checked = true;
      this._syncRow(row);
    }
  }

  selectNew(event) {
    const row = event.target.closest(".lookout-manager__row");
    if (!row) return;
    const radio = row.querySelector("input[name^='lookout-dest'][value='new']");
    if (radio) {
      radio.checked = true;
      this._syncRow(row);
    }
  }

  newNameChanged(event) {
    this.selectNew(event);
    const row = event.target.closest(".lookout-manager__row");
    if (!row) return;
    const field = row.querySelector(
      "[data-lookout-manager-target='projectNameField']",
    );
    if (field) field.value = event.target.value.trim();
  }

  _syncDisplay() {
    this.rowTargets.forEach((row) => {
      row.hidden = row.id !== this._activeId;
    });
    this.tabTargets.forEach((tab) => {
      tab.classList.toggle(
        "lookout-manager__tab--active",
        tab.dataset.rowId === this._activeId,
      );
    });
  }

  _syncRow(row) {
    const radio = row.querySelector("input[name^='lookout-dest']:checked");
    const existingSelect = row.querySelector(
      "[data-lookout-manager-target='existingSelect']",
    );
    const newInput = row.querySelector(
      "[data-lookout-manager-target='newName']",
    );
    const field = row.querySelector(
      "[data-lookout-manager-target='projectNameField']",
    );
    if (!radio || !field) return;

    const isNew = radio.value === "new";
    if (existingSelect) existingSelect.disabled = isNew;
    if (newInput) newInput.disabled = !isNew;

    field.value = isNew
      ? newInput?.value.trim() || ""
      : existingSelect?.value || "";
  }
}
