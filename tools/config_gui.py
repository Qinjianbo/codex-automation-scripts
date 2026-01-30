#!/usr/bin/env python3
"""
GUI editor for Codex automation config.yaml.

Features:
- Load/save config.yaml (fallback to config.example.yaml defaults).
- Per-field validation and file pickers for paths.
- Optional backup before save.
- Test codex-run.sh availability.
"""

from __future__ import annotations

import subprocess
import sys
import tkinter as tk
from dataclasses import dataclass
from pathlib import Path
from tkinter import filedialog, messagebox, ttk
from typing import Dict, List, Optional

try:
    import yaml
except ImportError:
    messagebox.showerror("Missing dependency", "Please install pyyaml: pip install pyyaml")
    raise SystemExit(1)


ROOT_DIR = Path(__file__).resolve().parent.parent
DEFAULT_CONFIG = ROOT_DIR / "config.yaml"
EXAMPLE_CONFIG = ROOT_DIR / "config.example.yaml"
CODEX_RUN = ROOT_DIR / "codex-run.sh"

SANDBOX_OPTIONS = ["read-only", "workspace-write", "danger-full-access"]


@dataclass
class FieldSpec:
    key: str
    label: str
    section: str
    required: bool = False
    placeholder: str = ""
    width: int = 48
    helper: Optional[str] = None
    path_picker: bool = False
    choices: Optional[List[str]] = None


FIELDS: List[FieldSpec] = [
    FieldSpec("project_name", "Project Name", "General", True, "ExampleProject"),
    FieldSpec("codex_language", "Codex Language", "General", False, "English"),
    FieldSpec("default_sandbox", "Default Sandbox", "General", False, "workspace-write", choices=SANDBOX_OPTIONS),
    FieldSpec("codex_node", "Node Path", "Paths", True, "~/.nvm/versions/node/v22.18.0/bin/node", path_picker=True),
    FieldSpec("codex_cli", "Codex CLI Path", "Paths", True, "~/.nvm/versions/node/v22.18.0/lib/node_modules/@openai/codex/bin/codex.js", path_picker=True),
    FieldSpec("codex_model_default", "Model Default", "Models", False, "gpt-5.1"),
    FieldSpec("codex_model_iterate", "Model Iterate", "Models", False, "gpt-5-mini"),
    FieldSpec("codex_model_plan", "Model Plan", "Models", False, "gpt-5-mini"),
    FieldSpec("codex_model_exec", "Model Exec", "Models", False, "gpt-5.2-codex"),
    FieldSpec("codex_model_commit", "Model Commit", "Models", False, "gpt-5-mini"),
    FieldSpec("git_branch", "Git Branch", "Git", True, "main"),
    FieldSpec("git_remote", "Git Remote", "Git", True, "origin"),
    FieldSpec("tasks_file", "Tasks File", "Files", False, "TASKS.md"),
    FieldSpec("plan_file", "Plan File", "Files", False, "PLAN.md"),
    FieldSpec("log_file", "Log File", "Files", False, "ITERATION_LOG.md"),
    FieldSpec("lock_file", "Lock File", "Files", False, ".auto-run.lock"),
    FieldSpec("plan_context_files", "Plan Context Files (comma-separated)", "Plan Context", False, "README.md,ROADMAP.md,CHANGELOG.md"),
    FieldSpec("plan_context_max_chars", "Plan Context Max Chars", "Plan Context", False, "12000"),
]


def load_yaml(path: Path) -> Dict[str, str]:
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    if not isinstance(data, dict):
        raise ValueError(f"Expected mapping in {path}, got {type(data)}")
    # Normalize to str keys/values where possible
    result: Dict[str, str] = {}
    for k, v in data.items():
        result[str(k)] = v
    return result


def save_yaml(path: Path, data: Dict[str, str]) -> None:
    with path.open("w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, sort_keys=False, allow_unicode=False, default_flow_style=False)


class ConfigGUI(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Codex Config Editor")
        self.geometry("880x720")
        self.resizable(True, True)

        self.config_path = tk.StringVar(value=str(DEFAULT_CONFIG))
        self.entries: Dict[str, tk.Entry] = {}
        self.combo_vars: Dict[str, tk.StringVar] = {}

        self._build_ui()
        self._load_into_form(initial=True)

    # UI construction
    def _build_ui(self):
        top_frame = ttk.Frame(self, padding="10 10 10 5")
        top_frame.pack(fill=tk.X)

        ttk.Label(top_frame, text="Config file:").pack(side=tk.LEFT)
        path_entry = ttk.Entry(top_frame, textvariable=self.config_path, width=80)
        path_entry.pack(side=tk.LEFT, padx=6, fill=tk.X, expand=True)
        ttk.Button(top_frame, text="Browse", command=self._choose_config_file).pack(side=tk.LEFT, padx=4)
        ttk.Button(top_frame, text="Reload", command=self._load_into_form).pack(side=tk.LEFT, padx=4)

        # Scrollable form
        canvas = tk.Canvas(self, borderwidth=0, highlightthickness=0)
        scrollbar = ttk.Scrollbar(self, orient="vertical", command=canvas.yview)
        self.form_frame = ttk.Frame(canvas, padding="10 10 10 10")
        self.form_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all")),
        )
        canvas.create_window((0, 0), window=self.form_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        self._build_sections()

        bottom = ttk.Frame(self, padding="10 10 10 10")
        bottom.pack(fill=tk.X)
        ttk.Button(bottom, text="Save", command=lambda: self._save(backup=False)).pack(side=tk.LEFT, padx=4)
        ttk.Button(bottom, text="Save + Backup", command=lambda: self._save(backup=True)).pack(side=tk.LEFT, padx=4)
        ttk.Button(bottom, text="Test codex-run.sh", command=self._test_codex_run).pack(side=tk.LEFT, padx=12)
        ttk.Button(bottom, text="Quit", command=self.destroy).pack(side=tk.RIGHT, padx=4)

    def _build_sections(self):
        sections: Dict[str, ttk.LabelFrame] = {}
        for field in FIELDS:
            if field.section not in sections:
                lf = ttk.LabelFrame(self.form_frame, text=field.section, padding="10 8 10 6")
                lf.pack(fill=tk.X, expand=True, pady=4)
                sections[field.section] = lf
            self._add_field(sections[field.section], field)

    def _add_field(self, parent: ttk.LabelFrame, spec: FieldSpec):
        row = ttk.Frame(parent)
        row.pack(fill=tk.X, pady=2)

        label_text = spec.label + (" *" if spec.required else "")
        ttk.Label(row, text=label_text, width=34, anchor="w").pack(side=tk.LEFT)

        if spec.choices:
            var = tk.StringVar()
            cb = ttk.Combobox(row, textvariable=var, values=spec.choices, width=spec.width)
            cb.pack(side=tk.LEFT, fill=tk.X, expand=True)
            self.combo_vars[spec.key] = var
        else:
            ent = ttk.Entry(row, width=spec.width)
            ent.pack(side=tk.LEFT, fill=tk.X, expand=True)
            ent.insert(0, spec.placeholder)
            self.entries[spec.key] = ent

        if spec.path_picker:
            ttk.Button(row, text="…", width=3, command=lambda k=spec.key: self._pick_path(k)).pack(side=tk.LEFT, padx=4)

        if spec.helper:
            ttk.Label(row, text=spec.helper, foreground="#555").pack(side=tk.LEFT, padx=6)

    # Data helpers
    def _current_values(self) -> Dict[str, str]:
        data: Dict[str, str] = {}
        for spec in FIELDS:
            if spec.choices:
                data[spec.key] = self.combo_vars[spec.key].get().strip()
            else:
                data[spec.key] = self.entries[spec.key].get().strip()
        return data

    def _apply_values(self, data: Dict[str, str]):
        for spec in FIELDS:
            val = data.get(spec.key, "")
            if spec.choices:
                self.combo_vars[spec.key].set(val or spec.placeholder)
            else:
                ent = self.entries[spec.key]
                ent.delete(0, tk.END)
                ent.insert(0, val or spec.placeholder)

    def _load_into_form(self, initial: bool = False):
        path = Path(self.config_path.get()).expanduser()
        try:
            data = load_yaml(EXAMPLE_CONFIG)  # start from example defaults
            data.update(load_yaml(path))
            self._apply_values(data)
            if not initial:
                messagebox.showinfo("Reloaded", f"Loaded config from {path}")
        except Exception as e:
            messagebox.showerror("Load failed", f"Could not load {path}:\n{e}")

    def _validate(self, data: Dict[str, str]) -> Optional[str]:
        for spec in FIELDS:
            if spec.required and not data.get(spec.key, "").strip():
                return f"Missing required field: {spec.label}"

        sandbox = data.get("default_sandbox", "")
        if sandbox and sandbox not in SANDBOX_OPTIONS:
            return f"default_sandbox must be one of {', '.join(SANDBOX_OPTIONS)}"

        max_chars = data.get("plan_context_max_chars", "")
        if max_chars:
            try:
                int(max_chars)
            except ValueError:
                return "plan_context_max_chars must be an integer"

        # Path existence checks are warnings, not blockers
        missing_paths = []
        for key in ("codex_node", "codex_cli"):
            p = Path(data.get(key, "")).expanduser()
            if p and not p.exists():
                missing_paths.append(f"{key} -> {p}")
        if missing_paths:
            resp = messagebox.askyesno(
                "Path warning",
                "These paths do not exist:\n- "
                + "\n- ".join(missing_paths)
                + "\n\nContinue anyway?",
            )
            if not resp:
                return "Aborted due to missing paths"

        return None

    # Actions
    def _save(self, backup: bool):
        path = Path(self.config_path.get()).expanduser()
        data = self._current_values()
        error = self._validate(data)
        if error:
            messagebox.showerror("Validation failed", error)
            return
        try:
            if backup and path.exists():
                backup_path = path.with_suffix(path.suffix + ".bak")
                backup_path.write_bytes(path.read_bytes())
            save_yaml(path, data)
            messagebox.showinfo("Saved", f"Config saved to {path}")
        except Exception as e:
            messagebox.showerror("Save failed", str(e))

    def _pick_path(self, key: str):
        chosen = filedialog.askopenfilename()
        if not chosen:
            return
        if key in self.entries:
            self.entries[key].delete(0, tk.END)
            self.entries[key].insert(0, chosen)

    def _choose_config_file(self):
        chosen = filedialog.askopenfilename(
            initialdir=str(ROOT_DIR),
            filetypes=[("YAML files", "*.yaml *.yml"), ("All files", "*.*")],
        )
        if chosen:
            self.config_path.set(chosen)
            self._load_into_form()

    def _test_codex_run(self):
        if not CODEX_RUN.exists():
            messagebox.showerror("codex-run.sh missing", f"Not found: {CODEX_RUN}")
            return
        try:
            result = subprocess.run(
                [str(CODEX_RUN), "--help"],
                cwd=str(ROOT_DIR),
                capture_output=True,
                text=True,
                timeout=15,
            )
            if result.returncode == 0:
                messagebox.showinfo("OK", "codex-run.sh responded successfully.")
            else:
                messagebox.showerror("codex-run.sh error", result.stderr or result.stdout)
        except Exception as e:
            messagebox.showerror("codex-run.sh error", str(e))


def main():
    app = ConfigGUI()
    app.mainloop()


if __name__ == "__main__":
    main()
