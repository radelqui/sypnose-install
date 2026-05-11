if (require.main === module) {
  const server = new McpServer({
    tools: [kb_save, kb_read, kb_search, kb_list],
    port: 18793,
  });

  server.start();
  console.log('MCP-KB server started on port 18793');
}