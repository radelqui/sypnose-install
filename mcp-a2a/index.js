const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

const MCP_MANIFEST = {
    name: 'sypnose-a2a',
    description: 'Sypnose Agent-to-Agent Communication MCP',
    tools: [
        {
            name: 'a2a_send',
            description: 'Send a message to another agent',
            parameters: {
                type: 'object',
                properties: {
                    to: { type: 'string', description: 'Recipient agent ID' },
                    msg: { type: 'string', description: 'Message content' },
                    key: { type: 'string', description: 'Idempotency key' },
                },
                required: ['to', 'msg'],
            },
        },
        {
            name: 'a2a_inbox',
            description: 'Retrieve messages for a specific agent',
            parameters: {
                type: 'object',
                properties: {
                    for: { type: 'string', description: 'Agent ID to fetch messages for' },
                    all: { type: 'boolean', description: 'Fetch all messages, including read ones' },
                },
                required: ['for'],
            },
        },
        {
            name: 'a2a_reply',
            description: 'Reply to a specific message',
            parameters: {
                type: 'object',
                properties: {
                    id: { type: 'string', description: 'Message ID to reply to' },
                    msg: { type: 'string', description: 'Reply message content' },
                },
                required: ['id', 'msg'],
            },
        },
        {
            name: 'a2a_ack',
            description: 'Acknowledge messages',
            parameters: {
                type: 'object',
                properties: {
                    key: { type: 'string', description: 'Acknowledge a specific message by key' },
                    all: { type: 'boolean', description: 'Acknowledge all messages' },
                },
            },
        },
    ],
};

app.get('/.well-known/mcp.json', (req, res) => {
    res.json(MCP_MANIFEST);
});

if (require.main === module) {
    app.listen(port, () => {
        console.log(`MCP server listening at http://localhost:${port}`);
    });
}

module.exports = app;
