// Merges Kira settings into the global opencode JSON/JSONC config.
// Usage: node merge-config.mjs <configPath> <port>
// - parses config with comments stripped (JSONC)
// - sets permission.allow and mcp["chrome-devtools"]
// - <configPath>.backup.<timestamp> always written first
// - nested mcp entries are preserved

import fs from "node:fs";

const [configPath, portArg] = process.argv.slice(2);
if (!configPath || !portArg) {
  console.error("usage: node merge-config.mjs <configPath> <port>");
  process.exit(1);
}
const port = Number(portArg);

let raw = "";
try { raw = fs.readFileSync(configPath, "utf8"); } catch { raw = ""; }

// Always back up the original (even if empty/nonexistent content)
try {
  fs.copyFileSync(configPath, `${configPath}.backup.${Date.now()}`);
} catch {
  fs.writeFileSync(`${configPath}.backup.${Date.now()}`, "");
}

// JSONC-aware parse: strip block comments, line comments, and trailing commas.
// Good enough for typical hand-edited opencode configs; warns on failure.
function parseJsonc(text) {
  if (!text.trim()) return {};
  const noBlockComments = text.replace(/\/\*[\s\S]*?\*\//g, "");
  const noLineComments = noBlockComments.split("\n").map((line) => {
    let out = "", inStr = false;
    for (let i = 0; i < line.length; i++) {
      const c = line[i];
      if (inStr) {
        out += c;
        if (c === "\\") { out += line[i + 1] ?? ""; i++; }
        else if (c === '"') inStr = false;
      } else if (c === '"') { inStr = true; out += c; }
      else if (c === "/" && line[i + 1] === "/") break;
      else out += c;
    }
    return out;
  }).join("\n");
  const noTrailing = noLineComments.replace(/,(\s*[}\]])/g, "$1");
  return JSON.parse(noTrailing);
}

let config;
try {
  config = parseJsonc(raw);
} catch (e) {
  console.error(`Could not parse ${configPath} (${e.message}). Rename comments or merge manually from install/templates/opencode.jsonc.part`);
  process.exit(2);
}

if (typeof config.mcp !== "object" || config.mcp === null) config.mcp = {};

config.permission = "allow";
config.mcp["chrome-devtools"] = {
  type: "local",
  command: ["npx", "-y", "chrome-devtools-mcp@latest", "--browserUrl", `http://127.0.0.1:${port}`],
};

fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + "\n");
console.log(`merged kira settings into ${configPath}`);
