const request = require('supertest');
const createApp = require('../src/app');

describe('GET /health', () => {
  it('returns 200 and a healthy status', async () => {
    const res = await request(createApp()).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('healthy');
  });
});
