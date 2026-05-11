const express = require('express');
const bodyParser = require('body-parser');
const storage = require('./storage');

const app = express();
const port = 18793; // As per Sypnose v7 audit

app.use(bodyParser.json());

// Initialize storage
storage.initState();

app.post('/boris_verify', (req, res) => {
  const { what_changed, how_verified, result } = req.body;
  if (!what_changed || !how_verified || !result) {
    return res.status(400).json({ error: 'Missing parameters' });
  }
  // TODO: Implement verification logic
  res.json({ status: 'verification registered' });
});

app.post('/boris_save_state', (req, res) => {
  const { progress, next_step } = req.body;
  if (!progress || !next_step) {
    return res.status(400).json({ error: 'Missing parameters' });
  }
  storage.saveState({ progress, next_step });
  res.json({ status: 'state saved' });
});

app.get('/boris_get_state', (req, res) => {
  const state = storage.getState();
  res.json(state);
});

app.post('/boris_register_done', (req, res) => {
  const { task_id } = req.body;
  if (!task_id) {
    return res.status(400).json({ error: 'Missing task_id' });
  }
  // TODO: Implement task registration
  res.json({ status: `task ${task_id} marked as done` });
});

app.post('/boris_register_failed', (req, res) => {
  const { task_id, reason } = req.body;
  if (!task_id || !reason) {
    return res.status(400).json({ error: 'Missing parameters' });
  }
  // TODO: Implement failure registration
  res.json({ status: `task ${task_id} marked as failed` });
});

if (process.env.NODE_ENV !== 'test') {
  app.listen(port, () => {
    console.log(`Boris MCP server listening at http://localhost:${port}`);
  });
}

module.exports = app; // For testing
