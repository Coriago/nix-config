import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";

const { default: register } = await import(pathToFileURL(process.argv[2]));
for (const key of [undefined, "", "test-key-not-a-secret"]) {
  if (key === undefined) delete process.env.CONTEXT7_API_KEY;
  else process.env.CONTEXT7_API_KEY = key;
  const registrations = [];
  register({ registerMcpServer: (name, config) => registrations.push({ name, config }) });
  assert.deepEqual(registrations, [{
    name: "context7",
    config: {
      url: "https://mcp.context7.com/mcp",
      exposure: "direct",
      ...(key ? { headers: { Authorization: `Bearer ${key}` } } : {}),
    },
  }]);
}
console.log("Context7 registration passed: anonymous access and optional runtime credentials.");
