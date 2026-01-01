# Security Model

## Authentication Flow

### 1. Sign In (Apple Sign In)

```
iOS App                          Backend                      Database
   |                                |                             |
   |-- POST /auth/apple-signin ---->|                             |
   |   {apple_user_id, email, name} |                             |
   |                                |-- Query by apple_user_id -->|
   |                                |<-- User object or None ------|
   |                                |                             |
   |                                |-- Create/Update User ------->|
   |                                |<-- User with DB id ----------|
   |                                |                             |
   |                                | Generate JWT:               |
   |                                | {sub: apple_user_id}        |
   |                                | Signed with SECRET_KEY      |
   |                                |                             |
   |<-- JWT Token ------------------|                             |
   |                                                              |
   | Save token to Keychain                                       |
```

**Key Points:**
- JWT token contains `apple_user_id` in the `sub` claim (NOT database ID)
- Token is cryptographically signed with `JWT_SECRET_KEY`
- Frontend cannot forge tokens without the secret key
- Database ID can change during migrations, `apple_user_id` is stable

### 2. Authenticated Requests

```
iOS App                          Backend                      Database
   |                                |                             |
   |-- GET /auth/me ---------------->|                             |
   |   Header: Authorization:       |                             |
   |   Bearer <JWT Token>           |                             |
   |                                |                             |
   |                                | 1. Validate JWT signature   |
   |                                | 2. Extract apple_user_id    |
   |                                |    from 'sub' claim         |
   |                                |                             |
   |                                |-- Query by apple_user_id -->|
   |                                |<-- User object --------------|
   |                                |                             |
   |<-- User data ------------------|                             |
```

**Key Points:**
- Frontend sends ONLY the JWT token
- Backend validates signature (prevents tampering)
- Backend extracts `apple_user_id` from token
- Backend looks up user in database (source of truth)
- ALL user data comes from database, NEVER from frontend

## Security Guarantees

### ✅ What This Prevents

1. **Forged Identity**: Frontend cannot pretend to be another user
   - JWT signature validation ensures token wasn't modified
   - Frontend doesn't have SECRET_KEY to sign forged tokens

2. **User ID Manipulation**: Frontend cannot change user_id
   - All endpoints use `current_user = Depends(get_current_user)`
   - User object comes from JWT token lookup, not from request data
   - No endpoints accept `user_id` from request body/params

3. **Data Tampering**: Frontend cannot modify user data directly
   - All updates go through validated endpoints
   - Database is single source of truth
   - Backend validates all changes

4. **Migration Issues**: Database ID changes don't break auth
   - Token contains stable `apple_user_id`, not database `id`
   - Old tokens continue working after DB migrations

### ❌ What Endpoints MUST NOT Do

**NEVER** accept user identity from request data:

```python
# ❌ WRONG - Vulnerable to user ID spoofing
@router.post("/kingdoms/{kingdom_id}/claim")
def claim_kingdom(kingdom_id: str, user_id: int, db: Session):  # ❌ NO!
    kingdom = get_kingdom(db, kingdom_id)
    kingdom.ruler_id = user_id  # ❌ Frontend could send any user_id!
    
# ✅ CORRECT - User identity from JWT token only
@router.post("/kingdoms/{kingdom_id}/claim")
def claim_kingdom(
    kingdom_id: str,
    current_user: User = Depends(get_current_user),  # ✅ From token
    db: Session = Depends(get_db)
):
    kingdom = get_kingdom(db, kingdom_id)
    kingdom.ruler_id = current_user.id  # ✅ From authenticated token
```

## JWT Token Structure

### Token Payload
```json
{
  "sub": "000123.abc456def789.1234",  // apple_user_id (stable identifier)
  "exp": 1234567890                   // expiration timestamp
}
```

**Why `apple_user_id` in token?**
- Stable: Never changes, even if database is migrated
- Unique: One per Apple user
- Trusted: Comes from Apple Sign In
- Lookup: Backend can always find user in DB

**Why NOT `user.id` in token?**
- Can change: Database migrations may change IDs (UUID → integer)
- Breaks old tokens: Users would need to re-authenticate after migrations
- Unnecessary: We look up user in DB anyway

## Configuration

### Required Environment Variables

```bash
# CRITICAL: Set a strong secret key in production!
JWT_SECRET_KEY="<strong-random-string>"

# Generate with:
openssl rand -hex 32
```

**Docker Compose:**
```yaml
services:
  api:
    environment:
      JWT_SECRET_KEY: "${JWT_SECRET_KEY}"  # Load from .env file
```

**⚠️ Security Warning:**
- Default key in code is ONLY for development
- System warns if default key is detected
- ALWAYS set custom key in production
- Keep key secret - if leaked, attackers can forge tokens

## Code Review Checklist

When reviewing authentication code, verify:

- [ ] All protected endpoints use `current_user = Depends(get_current_user)`
- [ ] No endpoints accept `user_id` from request body/params/query
- [ ] JWT token contains `apple_user_id`, not database `id`
- [ ] Token validation checks signature before trusting claims
- [ ] Database lookup happens AFTER token validation
- [ ] All user data comes from database User object
- [ ] JWT_SECRET_KEY is set from environment variable
- [ ] Token expiration is set (default: 7 days)

## Testing Authentication

### Valid Token Test
```bash
# 1. Sign in and get token
curl -X POST http://localhost:8000/auth/apple-signin \
  -H "Content-Type: application/json" \
  -d '{"apple_user_id": "test123", "email": "test@example.com", "display_name": "Test User"}'

# Response: {"access_token": "eyJ...", "token_type": "bearer"}

# 2. Use token to access protected endpoint
curl http://localhost:8000/auth/me \
  -H "Authorization: Bearer eyJ..."

# Response: {"id": 1, "display_name": "Test User", ...}
```

### Invalid Token Test
```bash
# Forged/invalid token should fail
curl http://localhost:8000/auth/me \
  -H "Authorization: Bearer invalid-token-xyz"

# Response: 401 Unauthorized
```

### No Token Test
```bash
# Missing auth header should fail
curl http://localhost:8000/auth/me

# Response: 403 Forbidden
```

## Incident Response

If JWT_SECRET_KEY is compromised:

1. **Immediately** change JWT_SECRET_KEY in production
2. All existing tokens become invalid
3. All users must sign in again
4. Review access logs for suspicious activity
5. Rotate database credentials if needed

## References

- [JWT Best Practices](https://tools.ietf.org/html/rfc8725)
- [OAuth 2.0 Security](https://tools.ietf.org/html/rfc6749#section-10)
- [FastAPI Security](https://fastapi.tiangolo.com/tutorial/security/)



