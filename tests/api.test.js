import request from 'supertest';
import app from '../src/server.js';

describe('API', () => {
  it('GET /health -> 200', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  it('POST /users -> 201 with valid payload', async () => {
    const res = await request(app)
      .post('/users')
      .send({ email: 'a@b.com', name: 'Emanuel' });
    expect(res.status).toBe(201);
    expect(res.body.email).toBe('a@b.com');
  });

  it('POST /users -> 400 with invalid payload', async () => {
    const res = await request(app).post('/users').send({});
    expect(res.status).toBe(400);
  });
});
