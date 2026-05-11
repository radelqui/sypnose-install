const express = require('express');
const a2a = require('./a2a');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 18795;

app.post('/', async (req, res) => {
  const { tool, args } = req.body;

  if (!tool) {
    return res.status(400).json({ error: 'Tool not specified' });
  }

  try {
    let result;
    switch (tool) {
      case 'a2a_send':
        result = await a2a.send(args.to, args.msg, args.key);
        break;
      case 'a2-inbox':
        result = await a2a.inbox(args.for, args.all);
        break;
      case 'a2a_reply':
        result = await a2a.reply(args.id, args.msg);
        break;
      case 'a2a_ack':
        result = await a2a.ack(args.key, args.all);
        break;
      default:
        return res.status(400).json({ error: `Unknown tool: ${tool}` });
    }
    res.json({ result });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

const server = app.listen(PORT, () => {
  console.log(`MCP-A2A server listening on port ${PORT}`);
});

module.exports = { app, server };