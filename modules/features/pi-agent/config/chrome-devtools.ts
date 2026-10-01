import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  // The Nix wrapper supplies the packaged server and browser paths.
  const command = process.env.PI_CHROME_DEVTOOLS_MCP;
  if (!command) throw new Error("Launch Pi through the mypi wrapper");
  pi.registerMcpServer("chrome-devtools", {
    command,
    exposure: "codemode",
    description: "Inspect and automate a headless Chromium browser with Chrome DevTools.",
  });
}
