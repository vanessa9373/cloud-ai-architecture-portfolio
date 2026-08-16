const request = require('supertest');
const createApp = require('../src/app');

describe('widgets API', () => {
  let app;

  beforeEach(() => {
    app = createApp();
  });

  it('lists seeded widgets', async () => {
    const res = await request(app).get('/widgets');
    expect(res.status).toBe(200);
    expect(res.body.length).toBeGreaterThanOrEqual(2);
  });

  it('returns 404 for an unknown widget', async () => {
    const res = await request(app).get('/widgets/9999');
    expect(res.status).toBe(404);
  });

  it('creates a widget with valid input', async () => {
    const res = await request(app).post('/widgets').send({ name: 'Widget C', quantity: 5 });
    expect(res.status).toBe(201);
    expect(res.body.name).toBe('Widget C');
  });

  it('rejects a widget with a negative quantity', async () => {
    const res = await request(app).post('/widgets').send({ name: 'Bad Widget', quantity: -1 });
    expect(res.status).toBe(400);
  });

  it('deletes an existing widget', async () => {
    const del = await request(app).delete('/widgets/1');
    expect(del.status).toBe(204);
    const get = await request(app).get('/widgets/1');
    expect(get.status).toBe(404);
  });
});
