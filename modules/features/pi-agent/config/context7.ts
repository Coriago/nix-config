import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  // Anonymous access works at lower limits; credentials stay out of the Nix store.
  const apiKey = process.env.CONTEXT7_API_KEY;
  pi.registerMcpServer("context7", {
    url: "https://mcp.context7.com/mcp",
    exposure: "direct",
    ...(apiKey ? { headers: { Authorization: `Bearer ${apiKey}` } } : {}),
  });
}
