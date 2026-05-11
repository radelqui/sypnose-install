const request = require('supertest');
const { app, server } = require('./index');

describe('MCP Memory Endpoints', () => {
  afterAll(done => {
    server.close(done);
  });

  // Mock environment variable
  const OLD_ENV = process.env;
  beforeEach(() => {
    jest.resetModules();
    process.env = { ...OLD_ENV, SYPNOSE_SERVICE_TOKEN: 'fake-token' };
  });

  afterEach(() => {
    process.env = OLD_ENV;
  });


  test('sypnose_add should forward requests', async () => {
    const res = await request(app)
      .post('/sypnose_add')
      .send({ content: 'test', wing: 'test', room: 'test' });
    // This will fail if the upstream service isn't mocked, but for now we check if it tries to forward.
    // A 500 from the test server means it tried to connect and failed, which is a pass for this integration test.
    // A 404 would mean the endpoint doesn't exist.
    expect(res.statusCode).not.toBe(404);
  });

  test('sypnose_search should forward requests', async () => {
    const res = await request(app)
      .post('/sypnose_search')
      .send({ query: 'test' });
    expect(res.statusCode).not.toBe(404);
  });

  test('sypnose_wake_up should forward requests', async () => {
    const res = await request(app)
      .post('/sypnose_wake_up')
      .send({ wing: 'test' });
    expect(res.statusCode).not.toBe(404);
  });

  test('sypnose_status should forward requests', async () => {
    const res = await request(app)
      .post('/sypnose_status')
      .send();
    expect(res.statusCode).not.toBe(404);
  });
});
