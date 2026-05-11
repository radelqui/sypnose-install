const axios = require('axios');

const API_URL = 'https://kb.sypnose.cloud/api/a2a';
const SERVICE_TOKEN = process.env.SYPNOSE_SERVICE_TOKEN; // This needs to be set in the environment

const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Authorization': `Bearer ${SERVICE_TOKEN}`
  }
});

async function send(to, msg, key) {
  // Mock implementation - replace with actual API call
  console.log(`Sending message to ${to}: ${msg}`);
  return { status: 'sent', messageId: `msg_${Date.now()}` };
}

async function inbox(forUser, all) {
  // Mock implementation
  console.log(`Fetching inbox for ${forUser}`);
  return [{ id: 'msg_123', from: 'test-user', message: 'Hello!' }];
}

async function reply(id, msg) {
  // Mock implementation
  console.log(`Replying to message ${id} with: ${msg}`);
  return { status: 'replied', replyId: `reply_${Date.now()}` };
}

async function ack(key, all) {
  // Mock implementation
  console.log(`Acknowledging message with key ${key}`);
  return { status: 'acknowledged' };
}

module.exports = {
  send,
  inbox,
  reply,
  ack
};