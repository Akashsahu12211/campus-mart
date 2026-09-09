import fs from 'fs';
import path from 'path';

describe('api auth flow', () => {
  const apiFilePath = path.join(__dirname, 'api.js');

  it('loginStudent points to the unified auth login endpoint', () => {
    const source = fs.readFileSync(apiFilePath, 'utf8');

    expect(source).toContain("api.post('/auth/login', data)");
    expect(source).not.toContain("api.post('/students/login', data)");
  });

  it('registerStudent points to the unified auth register endpoint', () => {
    const source = fs.readFileSync(apiFilePath, 'utf8');

    expect(source).toContain("api.post('/auth/register', data)");
    expect(source).not.toContain("api.post('/students/register', data)");
  });

  it('refreshes sessions through the auth refresh endpoint', () => {
    const source = fs.readFileSync(apiFilePath, 'utf8');

    expect(source).toContain(".post('/auth/refresh', { refreshToken }, {");
    expect(source).toContain('persistAuthSession(res.data)');
  });

  it('supports single-device and all-device logout endpoints', () => {
    const source = fs.readFileSync(apiFilePath, 'utf8');

    expect(source).toContain("await api.post('/auth/logout-all');");
    expect(source).toContain("await api.post('/auth/logout', refreshToken ? { refreshToken } : {});");
    expect(source).toContain('REFRESH_TOKEN_KEY');
  });
});
