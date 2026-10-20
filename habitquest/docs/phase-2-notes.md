# Phase 2 implementation notes

- The application reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` from Dart defines. Missing configuration shows an offline setup message and makes no Supabase request.
- `HabitService` implements `HabitRepository`; callers can depend on the CRUD/history contract while the production adapter continues to use the existing Supabase table, RPC, and payload names.
- `AuthService` accepts an optional Supabase client for construction in tests. No authentication bypass was added.
- The three `supabase_clean_project/supabase/migrations` files are copied as un-applied candidate SQL. Phase 2 did not connect to any project or apply migrations.
- The original project’s configured URL/key were not copied. Do not use remote service-role keys in the Flutter client.
