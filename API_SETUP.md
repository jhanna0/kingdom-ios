# Kingdom API - Local Development Setup

## What Was Created

This setup creates a **completely isolated** local API server for testing your iOS app. Nothing in your existing code was modified.

### New Files Created:
- `/api/main.py` - FastAPI server
- `/api/requirements.txt` - Python dependencies
- `docker-compose.yml` - Docker configuration
- `.dockerignore` - Docker ignore rules
- `API_SETUP.md` - This file

### What Was NOT Modified:
- ✅ Your existing `/python` game code - untouched
- ✅ Your iOS app - untouched
- ✅ Any existing configuration files

---

## Quick Start

### 1. Start the API and Database

```bash
cd /Users/jad/Desktop/kingdom
docker-compose up -d
```

This starts:
- PostgreSQL database on `localhost:5432`
- FastAPI server on `localhost:8000`

### 2. Check It's Running

```bash
# Check status
docker-compose ps

# View logs
docker-compose logs -f api

# Test API
curl http://localhost:8000
```

### 3. Get Your Mac's IP Address

```bash
ipconfig getifaddr en0
```

Example output: `192.168.1.100`

### 4. Connect from Your iPhone

In your iOS app, use: `http://YOUR_MAC_IP:8000`

Example:
```swift
let apiURL = "http://192.168.1.100:8000"
```

**Important:** Your iPhone must be on the same WiFi network as your Mac!

---

## API Documentation

Once running, visit these URLs in your browser:

- **API Docs**: http://localhost:8000/docs (interactive Swagger UI)
- **Alternative Docs**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/health

---

## Available Endpoints

### Players
- `POST /players` - Create a player
- `GET /players/{player_id}` - Get player details
- `GET /players` - List all players
- `PUT /players/{player_id}` - Update player

### Kingdoms
- `POST /kingdoms` - Create a kingdom
- `GET /kingdoms/{kingdom_id}` - Get kingdom details
- `GET /kingdoms` - List all kingdoms

### Game Actions
- `POST /checkin` - Player check-in at a kingdom

### System
- `GET /` - API info
- `GET /health` - Health check
- `GET /test/db` - Test database connection

---

## Testing from iOS

Example Swift code:

```swift
import Foundation

struct KingdomAPI {
    // Replace with your Mac's IP address
    static let baseURL = "http://192.168.1.100:8000"
    
    static func createPlayer(id: String, name: String) async throws -> Player {
        let url = URL(string: "\(baseURL)/players")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["id": id, "name": name, "gold": 100, "level": 1]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Player.self, from: data)
    }
    
    static func getPlayer(id: String) async throws -> Player {
        let url = URL(string: "\(baseURL)/players/\(id)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Player.self, from: data)
    }
}
```

---

## Managing the Services

### Start
```bash
docker-compose up -d
```

### Stop
```bash
docker-compose down
```

### Stop and Delete All Data
```bash
docker-compose down -v
```

### View Logs
```bash
# All services
docker-compose logs -f

# Just API
docker-compose logs -f api

# Just database
docker-compose logs -f db
```

### Restart After Code Changes
```bash
# API auto-reloads, but if needed:
docker-compose restart api
```

---

## Accessing the Database Directly

If you want to connect to PostgreSQL directly:

```bash
# Connection details:
Host: localhost
Port: 5432
Database: kingdom
User: admin
Password: admin

# Using psql command line:
docker-compose exec db psql -U admin -d kingdom
```

---

## Troubleshooting

### Can't Connect from iPhone?

1. **Check same WiFi**: iPhone and Mac must be on same network
2. **Check Mac's IP**: Run `ipconfig getifaddr en0`
3. **Check firewall**: System Preferences → Security & Privacy → Firewall
4. **Test locally first**: `curl http://localhost:8000`

### Port Already in Use?

If port 8000 or 5432 is already in use:

```bash
# Check what's using the port
lsof -i :8000
lsof -i :5432

# Change ports in docker-compose.yml if needed
```

### Docker Not Installed?

```bash
# Install Docker Desktop for Mac
# Download from: https://www.docker.com/products/docker-desktop
```

---

## Clean Removal

If you want to remove everything I created:

```bash
# Stop and remove containers & volumes
docker-compose down -v

# Remove files
rm -rf /Users/jad/Desktop/kingdom/api
rm /Users/jad/Desktop/kingdom/docker-compose.yml
rm /Users/jad/Desktop/kingdom/.dockerignore
rm /Users/jad/Desktop/kingdom/API_SETUP.md
```

---

## Security Notes

⚠️ **This setup is for LOCAL TESTING ONLY**

- Simple passwords (admin/admin)
- CORS allows all origins
- No authentication
- No HTTPS
- Database exposed on localhost

**DO NOT use this configuration in production!**

---

## Next Steps

1. Test the API is working: `curl http://localhost:8000`
2. View the docs: http://localhost:8000/docs
3. Get your Mac's IP: `ipconfig getifaddr en0`
4. Update your iOS app to use `http://YOUR_IP:8000`
5. Start building! 🏰

---

## Questions?

The API is just a simple FastAPI server with in-memory storage. Check `/api/main.py` to see how it works or modify it for your needs.


