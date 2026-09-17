import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

import type { HunkExtensionAPI } from "hunkdiff/extension";

function gitOutput(cwd: string, args: string[]): string | null {
  const result = Bun.spawnSync(
    ["git", "-C", cwd, ...args],
    {
      stdout: "pipe",
      stderr: "pipe",
    },
  );

  if (result.exitCode !== 0) {
    return null;
  }

  const output = result.stdout
    .toString()
    .trim();

  return output === ""
    ? null
    : output;
}

function resolveNewLine(
  patch: string,
  hunkIndex: number,
  oldTarget: number,
): number | null {
  const lines = patch.split(/\r?\n/);

  let currentHunk = -1;
  let oldLine = 0;
  let newLine = 0;

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];

    const header = line.match(
      /^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/,
    );

    if (header) {
      currentHunk += 1;
      oldLine = Number(header[1]);
      newLine = Number(header[2]);

      continue;
    }

    if (currentHunk !== hunkIndex) {
      continue;
    }

    if (line.startsWith("\\ No newline at end of file")) {
      continue;
    }

    if (line.startsWith(" ")) {
      if (oldLine === oldTarget) {
        return newLine;
      }

      oldLine += 1;
      newLine += 1;

      continue;
    }

    if (line.startsWith("-")) {
      const deletionStart = oldLine;
      const additionStart = newLine;

      let deletions = 0;
      let additions = 0;

      while (
        index < lines.length
        && lines[index].startsWith("-")
        && !lines[index].startsWith("---")
      ) {
        deletions += 1;
        index += 1;
      }

      while (
        index < lines.length
        && lines[index].startsWith("+")
        && !lines[index].startsWith("+++")
      ) {
        additions += 1;
        index += 1;
      }

      index -= 1;

      if (
        oldTarget >= deletionStart
        && oldTarget < deletionStart + deletions
      ) {
        const offset = Math.min(
          oldTarget - deletionStart,
          Math.max(additions - 1, 0),
        );

        return additionStart + offset;
      }

      oldLine += deletions;
      newLine += additions;

      continue;
    }

    if (
      line.startsWith("+")
      && !line.startsWith("+++")
    ) {
      newLine += 1;
    }
  }

  return null;
}

function selectedLine(
  file: {
    patch: string;
    hunks?: readonly {
      oldRange?: readonly [number, number];
      newRange?: readonly [number, number];
    }[];
  },
  hunkIndex: number | null,
  currentLine: {
    side: "old" | "new";
    line: number;
  } | null,
): number {
  if (currentLine?.side === "new") {
    return currentLine.line;
  }

  if (
    currentLine?.side === "old"
    && hunkIndex !== null
  ) {
    const mapped = resolveNewLine(
      file.patch,
      hunkIndex,
      currentLine.line,
    );

    if (mapped !== null) {
      return mapped;
    }
  }

  if (hunkIndex !== null) {
    const hunk = file.hunks?.[hunkIndex];

    if (hunk?.newRange) {
      return hunk.newRange[0];
    }

    if (hunk?.oldRange) {
      return hunk.oldRange[0];
    }
  }

  return currentLine?.line ?? 1;
}

function openRemote(
  server: string,
  file: string,
  line: number,
): {
  ok: boolean;
  detail?: string;
} {
  const open = Bun.spawnSync(
    [
      "nvim",
      "--server",
      server,
      "--remote",
      file,
    ],
    {
      stdout: "pipe",
      stderr: "pipe",
    },
  );

  if (open.exitCode !== 0) {
    return {
      ok: false,
      detail: open.stderr.toString().trim(),
    };
  }

  const move = Bun.spawnSync(
    [
      "nvim",
      "--server",
      server,
      "--remote-expr",
      `cursor(${Math.max(1, line)}, 1)`,
    ],
    {
      stdout: "pipe",
      stderr: "pipe",
    },
  );

  if (move.exitCode !== 0) {
    return {
      ok: false,
      detail: move.stderr.toString().trim(),
    };
  }

  return { ok: true };
}

export default function (hunk: HunkExtensionAPI) {
  hunk.registerCommand(
    {
      id: "open",
      title: "Open selected file in Neovim",
    },
    (ctx) => {
      const file = ctx.selection.file;

      if (!file) {
        ctx.notify(
          "No file selected.",
          "warning",
        );
        return;
      }

      const repository = gitOutput(
        ctx.cwd,
        ["rev-parse", "--show-toplevel"],
      );

      const gitDirectory = gitOutput(
        ctx.cwd,
        ["rev-parse", "--absolute-git-dir"],
      );

      if (!repository || !gitDirectory) {
        ctx.notify(
          "Could not resolve the Git repository.",
          "error",
        );
        return;
      }

      const target = resolve(
        repository,
        file.path,
      );

      if (!existsSync(target)) {
        ctx.notify(
          `Cannot edit ${file.path}: file does not exist on disk.`,
          "warning",
        );
        return;
      }

      const registry = join(
        gitDirectory,
        "nvim-server",
      );

      if (!existsSync(registry)) {
        ctx.notify(
          "No Neovim instance is registered for this repository.",
          "warning",
        );
        return;
      }

      const server = readFileSync(
        registry,
        "utf8",
      ).trim();

      if (server === "") {
        ctx.notify(
          "The Neovim server registry is empty.",
          "warning",
        );
        return;
      }

      const line = selectedLine(
        file,
        ctx.selection.hunkIndex,
        ctx.selection.currentLine,
      );

      const result = openRemote(
        server,
        target,
        line,
      );

      if (!result.ok) {
        ctx.notify(
          result.detail
            ? `Failed to open Neovim: ${result.detail}`
            : "Failed to open Neovim.",
          "error",
        );
      }
    },
  );
}
