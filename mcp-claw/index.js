const express = require('express');
const axios = require('axios');
const app = express();
const port = 18811; // Or any other free port

app.use(express.json());

const CLAW_SERVERS = {
    '67': 'https://claw.sypnose.cloud/dispatch',
    '217': 'https://claw217.sypnose.cloud/dispatch'
};

// Health check endpoint for the MCP server itself
app.get('/health', (req, res) => {
    res.status(200).send('MCP Claw Server is running');
});

// Tool execution endpoint
app.post('/execute', async (req, res) => {
    const { tool, arguments } = req.body;

    switch (tool) {
        case 'claw_health':
            res.json({ success: true, result: 'MCP Claw Server is healthy.' });
            break;
        
        // Stubs for other tools
        case 'claw_dispatch':
            res.status(501).json({ success: false, error: 'Not implemented' });
            break;
        case 'claw_status':
            res.status(501).json({ success: false, error: 'Not implemented' });
            break;
        case 'claw_cancel':
            res.status(501).json({ success: false, error: 'Not implemented' });
            break;

        default:
            res.status(400).json({ success: false, error: 'Unknown tool' });
    }
});

if (require.main === module) {
    app.listen(port, () => {
        console.log(`MCP Claw Server listening at http://localhost:${port}`);
    });
}

module.exports = app;
