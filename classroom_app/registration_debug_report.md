# 🔍 Registration Debug Report — AI Classroom

**Date:** 2026-04-17  
**Tested via:** Hoppscotch (live HTTP requests to Render backend)

---

## ✅ Postman Test Results (Live API)

All three suspected issues have been ruled out by live API testing.

| Test | Endpoint | Status | Result |
|------|----------|--------|--------|
| Register new user | `POST /api/auth/register` | **200 OK** | ✅ User saved with `"success": true` |
| Login new user | `POST /api/auth/login` | **200 OK** | ✅ JWT token returned |
| Login default user | `POST /api/auth/login` | **200 OK** | ✅ Works fine |
| Duplicate register | `POST /api/auth/register` | **400** | ✅ Correct — DB unique constraint enforced |

---

## ❌ Your 3 Suspected Issues — All Ruled Out

### 1. ❌ Password not encoded?
**Not the issue.** The newly registered user (`debugtest123@example.com`) successfully logged in with `Test@123` and received a **valid JWT token**. Password encoding (BCrypt) is working correctly.

### 2. ❌ Register API not being hit from frontend?
**Not the issue for direct API calls.** The `/api/auth/register` endpoint IS reachable and responds with `200 OK`. However, there IS a frontend bug — see below.

### 3. ❌ User not saved in DB?
**Not the issue.** A duplicate registration attempt returns `400 Bad Request` with PostgreSQL's unique constraint error, **proving the user IS persisted in the database**.

---

## 🔴 REAL ROOT CAUSE: Frontend 15-Second Timeout + Render Cold Start

### The Actual Problem

The Render free-tier backend takes **~189 seconds (3+ minutes)** to wake up from cold start.

Your Flutter app hardcodes a **15-second timeout** for the register call:

```dart
// api_service.dart — line 65
Future<Response> register(Map<String, dynamic> data) async {
  return await _dio.post('/auth/register', data: data).timeout(const Duration(seconds: 15));
                                                               // ↑ ONLY 15 SECONDS!
}
```

**What happens:**
1. User opens app → server is sleeping (cold start)
2. User fills out register form and taps "Register"
3. Flutter waits 15 seconds → `TimeoutException` fired
4. Register shows "Registration failed" snackbar ❌
5. **But the request DID reach the backend** (after 3 min the server woke up and processed it — or it's lost)

Meanwhile, compare with the **login** function — it has a retry mechanism and user-friendly "Waking up server..." cold start handling:

```dart
// auth_provider.dart — line 107
on TimeoutException catch (e) {
  state = state.copyWith(isLoading: false, error: 'timeout: Waking up server...');
  return false;
}
```

But the **register** function has **no cold-start handling at all**. It just fails silently with a generic error.

---

## ✅ Fixes Required

### Fix 1 — Increase Register Timeout (api_service.dart)

```dart
// BEFORE (line 65)
return await _dio.post('/auth/register', data: data).timeout(const Duration(seconds: 15));

// AFTER — Give the cold start plenty of time
return await _dio.post('/auth/register', data: data).timeout(const Duration(seconds: 180));
```

> [!IMPORTANT]
> 180 seconds matches the actual cold start time observed (189 seconds). Alternatively, use 120 seconds as a conservative minimum.

---

### Fix 2 — Add Cold Start UX Handling in auth_provider.dart

The `register()` method catches `DioException` but not `TimeoutException`. Add it:

```dart
Future<bool> register(String name, String email, String password, String role) async {
  state = state.copyWith(isLoading: true, error: null);
  try {
    await _apiService.register({
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    });
    state = state.copyWith(isLoading: false);
    return true;
  } on TimeoutException catch (_) {          // ← ADD THIS
    state = state.copyWith(
      isLoading: false,
      error: 'timeout: Server is starting up...',
    );
    return false;
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionTimeout ||   // ← ADD THIS
        e.type == DioExceptionType.receiveTimeout) {
      state = state.copyWith(
        isLoading: false,
        error: 'timeout: Server is starting up...',
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? e.message ?? 'Registration failed',
      );
    }
    return false;
  } catch (e) {
    state = state.copyWith(
      isLoading: false,
      error: 'An unexpected error occurred',
    );
    return false;
  }
}
```

---

### Fix 3 — Show Cold Start Dialog on Register Screen

In `register_screen.dart`, detect the cold start error and show the same "waking up" UX as login:

```dart
void _handleRegister() async {
  if (_formKey.currentState!.validate()) {
    final success = await ref.read(authProvider.notifier).register(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
          _selectedRole.toUpperCase(),
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful! Please login.'), backgroundColor: AppColors.success),
      );
      context.pop();
    } else if (mounted) {
      final error = ref.read(authProvider).error;
      // ↓ ADD: Handle cold start timeout just like login screen
      if (error != null && error.startsWith('timeout:')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⏳ Server is waking up. Please wait a moment and try again.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Registration failed'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
```

---

## 📋 Why Backend Logs Showed Nothing

Register requests were **not reaching the backend in time** — the Flutter app was disconnecting (timeout) 15 seconds in, while the cold start took 3 minutes. From the backend's perspective, by the time Render woke up, the client was already gone. This is why you saw nothing in backend Render logs.

After the server has warmed up (any request forces it to stay up for ~15 minutes), subsequent register requests work fine — which is consistent with "default users can log in but newly registered users cannot": default users are seeded via `CommandLineRunner` and don't need registration at all. New users registering hit a cold server.

---

## Summary of Actions

| Action | File | Priority |
|--------|------|----------|
| Increase timeout to 120–180s | `lib/data/services/api_service.dart` line 65 | 🔴 Critical |
| Handle `TimeoutException` in register | `lib/features/auth/providers/auth_provider.dart` | 🔴 Critical |
| Show cold-start snackbar in register UI | `lib/features/auth/presentation/register_screen.dart` | 🟡 Medium |
