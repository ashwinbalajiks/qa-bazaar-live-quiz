# Deployment Guide

## Quick Start

### 1. Apply Database Changes (Supabase)
```sql
-- Copy the entire content of migration_update_questions.sql
-- Open https://supabase.com/dashboard
-- Go to SQL Editor
-- Create a new query
-- Paste the migration SQL
-- Click "Run"
-- Verify no errors
```

### 2. Deploy Frontend
```bash
# Build is already done: npm run build
# The dist/ folder contains production-ready files
# Upload dist/ to your hosting service (Vercel, Netlify, etc.)
```

## What the Migration Does

### Updates Questions
- Replaces all 5 questions with new cultural trivia questions
- Updates correct answer indices
- No data loss - just replaces question content

### Adds New Function
- `quiz_all_questions()` - Returns all questions with correct answers
- Only accessible when phase = 'results' OR user is admin
- Prevents premature answer disclosure

## Rollback (if needed)

If you need to revert to original questions:

```sql
UPDATE public.questions SET 
  prompt = 'What does HTTP 404 mean?',
  options = '["Success","Not Found","Unauthorized","Server Error"]'::jsonb,
  correct_index = 1
WHERE id = 1;

-- ... repeat for other questions
```

## Verification

### After Migration
1. Open Supabase Dashboard → SQL Editor
2. Run: `SELECT id, prompt, correct_index FROM public.questions;`
3. Verify 5 rows exist with correct questions

### After Frontend Deploy
1. Open quiz participant page
2. Sign in as admin
3. Start quiz and go through questions
4. Click "Publish final results"
5. Verify:
   - Leaderboard appears first
   - All 5 questions appear below
   - Green highlighting on correct answers
   - Red highlighting on user's wrong answers (if any)

## Troubleshooting

### "Function quiz_all_questions does not exist"
- Ensure migration SQL was run completely
- Check for SQL errors during execution
- Verify function exists: SELECT * FROM pg_proc WHERE proname = 'quiz_all_questions';

### Questions not displaying
- Check build with: npm run build
- Verify dist/ files are deployed
- Clear browser cache (Ctrl+Shift+Del)
- Check browser console for errors (F12)

### Answers showing too early
- Verify migration function has access control
- Check quiz_state.phase is actually 'results'
- Confirm refresh() is fetching questions correctly

## Performance Notes

- Build size: ~130KB gzipped (same as before)
- No additional API calls during quiz play
- Questions only fetched once in results phase
- Uses existing Supabase realtime connection
