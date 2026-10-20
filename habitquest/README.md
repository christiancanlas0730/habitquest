# HabitQuest Rebuild

Fresh Flutter client using the existing `lib/screens`, `lib/services`, `lib/models`, and `lib/widgets` structure. No Supabase project is configured by default.

## Local Supabase client configuration

Provide only a project URL and its public publishable (anon) key as Dart defines in a local launch profile or command line:

```powershell
flutter run -d chrome --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

The app displays a local setup screen when either value is absent. Never use a service-role key in a client build. Do not commit real project credentials. Phase 2 has not configured a live project.

The clean-install schema candidate is in `supabase_clean_project/supabase/migrations/`. It is documentation/source only in this phase and has not been applied. See `docs/phase-2-notes.md` for the integration boundary.
