const request = require('supertest');
const app = require('../index');

describe('MCP Claw API', () => {

    it('should return 200 from /health', async () => {
        const res = await request(app).get('/health');
        expect(res.statusCode).toEqual(200);
        expect(res.text).toBe('MCP Claw Server is running');
    });

    it('should return a health message from claw_health tool', async () => {
        const res = await request(app)
            .post('/execute')
            .send({
                tool: 'claw_health',
                arguments: {}
            });
        expect(res.statusCode).toEqual(200);
        expect(res.body).toEqual({ success: true, result: 'MCP Claw Server is healthy.' });
    });
});
