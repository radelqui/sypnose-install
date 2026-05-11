const express = require('express');
const axios = require('axios');

const app = express();
app.use(express.json());

const SERVICE_TOKEN = process.env.SYPNOSE_SERVICE_TOKEN;
const BASE_URL = 'https://memory.sypnose.cloud';

const forwardRequest = async (req, res, endpoint) => {
  if (!SERVICE_TOKEN) {
    return res.status(500).json({ error: 'SYPNOSE_SERVICE_TOKEN not set' });
  }

  try {
    const response = await axios.post(`${BASE_URL}/${endpoint}`, req.body, {
      headers: {
        'Authorization': `Bearer ${SERVICE_TOKEN}`,
        'Content-Type': 'application/json'
      }
    });
    res.status(response.status).json(response.data);
  } catch (error) {
    const status = error.response ? error.response.status : 500;
    const data = error.response ? error.response.data : { error: 'Internal server error' };
    res.status(status).json(data);
  }
};

app.post('/sypnose_add', (req, res) => forwardRequest(req, res, 'sypnose_add'));
app.post('/sypnose_search', (req, res) => forwardRequest(req, res, 'sypnose_search'));
app.post('/sypnose_wake_up', (req, res) => forwardRequest(req, res, 'sypnose_wake_up'));
app.post('/sypnose_status', (req, res) => forwardRequest(req, res, 'sypnose_status'));

const PORT = process.env.PORT || 18800;

const server = app.listen(PORT, () => {
  console.log(`MCP Memory server listening on port ${PORT}`);
});

module.exports = { app, server };
