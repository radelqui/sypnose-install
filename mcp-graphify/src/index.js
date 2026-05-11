
const express = require('express');
const { MCPServer } = require('@modelcontextprotocol/sdk');
const { exec } = require('child_process');

const app = express();
const port = 18795; 

const graphifyTools = require('./tools/graphify');

const server = new MCPServer({
  tools: [
    graphifyTools.graphify_extract,
    graphifyTools.graphify_query,
    graphifyTools.graphify_path,
    graphifyTools.graphify_explain,
    graphifyTools.graphify_list_graphs
  ]
});

app.use('/mcp', server.router);

app.listen(port, () => {
  console.log(`MCP Graphify server listening at http://localhost:${port}`);
});
