const request = require('supertest');
const { app, server } = require('./server');

afterAll((done) => {
  server.close(done);
});

describe('MCP-A2A Server', () => {
  it('should return an error if no tool is specified', async () => {
    const res = await request(app)
      .post('/')
      .send({ args: {} });
    expect(res.statusCode).toEqual(400);
    expect(res.body.error).toBe('Tool not specified');
  });

  it('should return an error for an unknown tool', async () => {
    const res = await request(app)
      .post('/')
      .send({ tool: 'unknown_tool', args: {} });
    expect(res.statusCode).toEqual(400);
    expect(res.body.error).toBe('Unknown tool: unknown_tool');
  });

  it('should handle a2a_send tool', async () => {
    const args = { to: 'user1', msg: 'Hello', key: '123' };
    const res = await request(app)
      .post('/')
      .send({ tool: 'a2a_send', args });
    expect(res.statusCode).toEqual(200);
    expect(res.body.result.status).toBe('sent');
  });
 
  it('should handle a2a_inbox tool', async () => {
    const args = { for: 'user1', all: false };
    const res = await request(app)
      .post('/')
      .send({ tool: 'a2a_inbox', args });
    expect(res.statusCode).toEqual(200);
    expect(res.body.result).toBeInstanceOf(Array);
  });

  it('should handle a2a_reply tool', async () => {
    const args = { id: 'msg_123', msg: 'Reply' };
    const res = await request(app)
      .post('/')
      .send({ tool: 'a2a_reply', args });
    expect(res.statusCode).toEqual(200);
    expect(res.body.result.status).toBe('replied');
  });

  it('should handle a2a_ack tool', async () => {
    const args = { key: '123' };
    const res = await request(app)
      .post('/')
      .send({ tool: 'a2a_ack', args });
    expect(res.statusCode).toEqual(200);
    expect(res.body.result.status).toBe('acknowledged');
  });
});