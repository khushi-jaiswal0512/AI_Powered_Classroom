# 🐛 Backend Bug Report — AI Classroom API
**Project:** AI Classroom  
**Backend:** Java Spring Boot  
**Deployed at:** https://ai-classroom-backend-5.onrender.com  
**Reported by:** Frontend Integration Team  
**Date:** 2026-04-16  
**Priority:** 🔴 HIGH

---

## Summary
During frontend integration testing, **two critical bugs** were identified in the backend API. Both bugs were confirmed through direct HTTP testing (not UI-level) and produce incorrect HTTP status codes that break the Flutter frontend's error handling and user experience.

---

## Bug #1 — `POST /api/auth/login` Returns `500` Instead of `401` for Non-Existent / Bad Credentials

### Severity
🔴 **Critical** — Blocks all login functionality for unregistered or deleted accounts.

### Endpoint
```
POST /api/auth/login
```

### Reproduction Steps
1. Send a `POST` request to `/api/auth/login` with credentials of a user who does **not exist** in the database:
```json
{
  "email": "nonexistent@example.com",
  "password": "AnyPassword@123"
}
```
2. Observe the HTTP response.

### Actual Behavior ❌
```json
HTTP 500 Internal Server Error

{
  "timestamp": "2026-04-15T22:53:24.997+00:00",
  "status": 500,
  "error": "Internal Server Error",
  "path": "/api/auth/login"
}
```

### Expected Behavior ✅
```json
HTTP 401 Unauthorized

{
  "success": false,
  "error": "Invalid email or password"
}
```

### Root Cause Analysis
The `UserDetailsService.loadUserByUsername()` method throws a `UsernameNotFoundException` when the email is not found in the database. This exception is **not being caught** by the global exception handler, causing Spring Boot's default error handler to return a generic `500 Internal Server Error`.

The same crash occurs when:
- A user exists but has a **corrupted password hash** in the database
- The database connection **drops mid-query** during authentication
- The **Render PostgreSQL database is wiped** (Render free-tier wipes data on inactivity), leaving previously registered users with no records

### Affected Scenario (Confirmed)
The test account `test.ai@example.com` was previously registered and working. After the Render free-tier database was reset (data wipe), the account no longer exists in the database. Every login attempt for this account now returns `500` instead of `401`.

> **Note:** A freshly registered account (`testuser99@example.com`) logs in successfully with `200 OK` and a valid JWT token — confirming the authentication code itself works, but the missing-user case is unhandled.

### Recommended Fix

**Option A — Throw `BadCredentialsException` instead of `UsernameNotFoundException`:**  
In your `CustomUserDetailsService.java` or auth service:
```java
// ❌ Current (broken)
User user = userRepository.findByEmail(email)
    .orElseThrow(() -> new UsernameNotFoundException("User not found"));

// ✅ Fix — Spring Security maps this to 401 automatically
User user = userRepository.findByEmail(email)
    .orElseThrow(() -> new BadCredentialsException("Invalid email or password"));
```

**Option B — Add a Global Exception Handler for auth errors:**  
In your `GlobalExceptionHandler.java`:
```java
@ExceptionHandler({BadCredentialsException.class, UsernameNotFoundException.class})
@ResponseStatus(HttpStatus.UNAUTHORIZED)
public ResponseEntity<Map<String, Object>> handleAuthException(Exception e) {
    return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of(
        "success", false,
        "error", "Invalid email or password"
    ));
}
```

**Option C — Validate in the AuthController before calling authenticate:**
```java
// In AuthController.java login() method
if (!userRepository.existsByEmail(request.getEmail())) {
    return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
        .body(Map.of("success", false, "error", "Invalid email or password"));
}
```

> ✅ **Recommended to apply Option B** (global handler) as it covers all auth exceptions centrally.

---

## Bug #2 — `GET /api/video/all` Returns `403 Forbidden` (Should Be Public)

### Severity
🟡 **Medium** — Breaks the video listing page for unauthenticated users.

### Endpoint
```
GET /api/video/all
```

### Reproduction Steps
1. Send an unauthenticated `GET` request to `/api/video/all` **without** an `Authorization` header:
```bash
curl https://ai-classroom-backend-5.onrender.com/api/video/all
```

### Actual Behavior ❌
```
HTTP 403 Forbidden
```

### Expected Behavior ✅
```json
HTTP 200 OK

[
  {
    "id": 1,
    "title": "Physics Lecture 1",
    "url": "https://s3.amazonaws.com/...",
    ...
  }
]
```

### Root Cause Analysis
Per the API documentation, `/api/video/all` is explicitly marked as:

> **Auth:** ❌ Public (or authenticated — no role restriction)

However, the Spring Security configuration is **not permitting** this route for unauthenticated requests. The likely cause is that the `SecurityFilterChain` is missing the `permitAll()` rule for this endpoint.

### Recommended Fix
In your `SecurityConfig.java`, ensure `/api/video/all` is added to the public whitelist:

```java
// In SecurityConfig.java — configure() or securityFilterChain() method

http.authorizeHttpRequests(auth -> auth
    // ✅ Public endpoints
    .requestMatchers(HttpMethod.POST, "/api/auth/register").permitAll()
    .requestMatchers(HttpMethod.POST, "/api/auth/login").permitAll()
    .requestMatchers(HttpMethod.GET, "/api/video/all").permitAll()       // ← ADD THIS
    .requestMatchers(HttpMethod.GET, "/api/class/live").permitAll()      // ← VERIFY THIS
    .requestMatchers(HttpMethod.GET, "/api/class/attendance/**").permitAll() // ← VERIFY THIS

    // 🔒 Everything else requires authentication
    .anyRequest().authenticated()
);
```

---

## Summary Table

| # | Endpoint | Method | Issue | Current Status | Expected Status | Priority |
|---|---|---|---|---|---|---|
| 1 | `/api/auth/login` | POST | `UsernameNotFoundException` not handled → returns 500 | `500 Internal Server Error` | `401 Unauthorized` | 🔴 Critical |
| 2 | `/api/video/all` | GET | Public route blocked by Spring Security | `403 Forbidden` | `200 OK` | 🟡 Medium |

---

## Impact on Frontend

| Bug | Frontend Impact |
|---|---|
| Bug #1 (500 on login) | Flutter app cannot distinguish between "server crashed" vs "wrong password". The `DioException` is caught, but since both scenarios return `500`, there is no way to show a proper "Invalid credentials" message. The user sees a generic error instead of actionable feedback. |
| Bug #2 (403 on video list) | The video listing screen fails to load for non-logged-in users and shows a "Could not load videos" error. Also breaks any pre-auth browsing of available content. |

---

## Environment

| Property | Value |
|---|---|
| Backend Platform | Render (Free Tier) |
| Framework | Java Spring Boot |
| Database | PostgreSQL (Render managed) |
| Auth | JWT Bearer Tokens (Spring Security) |
| Frontend | Flutter Web (Dart + Riverpod + Dio) |
| Base URL | `https://ai-classroom-backend-5.onrender.com/api` |

---

## Additional Note: Render Free-Tier Database Persistence

> [!WARNING]
> Render's free-tier PostgreSQL database instances are **deleted after 90 days of inactivity** and may also be wiped during plan changes. This means all registered users are permanently lost when a database wipe occurs.

**Recommended actions for the backend team:**
1. Export a **database snapshot/dump** regularly.
2. Create a **database seeder / data initialization script** (`data.sql` or `CommandLineRunner`) that re-creates essential test accounts on startup:
```java
@Bean
CommandLineRunner seedDatabase(UserRepository repo, PasswordEncoder encoder) {
    return args -> {
        if (!repo.existsByEmail("admin@classroom.com")) {
            repo.save(new User("Admin", "admin@classroom.com", 
                               encoder.encode("Admin@123"), Role.TEACHER));
        }
    };
}
```
3. Consider upgrading to **Render's paid PostgreSQL** tier for persistent data in production.
