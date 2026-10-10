// Exercise the real extension loader without making a model request.
export default function (pi) {
  pi.registerCommand("mypi-check", {
    handler: async (_args, ctx) => {
      // Built-in MCP connects in the background after session_start.
      const deadline = Date.now() + 30000;
      while (Date.now() < deadline) {
        const tools = pi.getAllTools().map((tool) => tool.name);
        if (tools.includes("mcp__chrome_devtools__list_pages")) break;
        await new Promise((resolve) => setTimeout(resolve, 100));
      }
      ctx.ui.setStatus("mypi-check", JSON.stringify({
        tools: pi.getAllTools().map((tool) => tool.name),
      }));
    },
  });
}
