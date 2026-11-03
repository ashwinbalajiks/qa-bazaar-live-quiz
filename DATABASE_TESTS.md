# Database Testing Guide

## After Running Migration SQL

### Test 1: Verify Questions Updated
```sql
-- Run this in Supabase SQL Editor
SELECT id, prompt, correct_index FROM public.questions ORDER BY id;
```

**Expected Results:**
```
id  prompt                                    correct_index
1   Why can't you buy groceries...             2
2   In Malaysia, what does "tapau" mean?      1
3   What does "Feierabend" mean?              2
4   What is "teh tarik"?                       3
5   What is true about the weather...          1
```

### Test 2: Verify Options Are Correct
```sql
-- Check Q1 options
SELECT options FROM public.questions WHERE id = 1;
```

**Expected Output:**
```
["Supermarkets also need a day to recharge", "Germans only shop when it rains", "Sunday is a legal rest day, so most shops are closed", "All the cashiers are at the beer garden"]
```

### Test 3: Verify Function Exists
```sql
-- Check quiz_all_questions function
SELECT proname, prosrc FROM pg_proc 
WHERE proname = 'quiz_all_questions' 
AND prokind = 'f';
```

**Expected:** One row with function definition

### Test 4: Test Function Access Control (Phase Checking)
```sql
-- Should succeed - admin testing
SELECT * FROM public.quiz_all_questions();
```

**Expected:** JSON array with all 5 questions including correct_index

### Test 5: Verify Question Structure
```sql
-- Call the function and check structure
SELECT public.quiz_all_questions() -> 0 as first_question;
```

**Expected JSON Structure:**
```json
{
  "id": 1,
  "prompt": "Why can't you buy groceries...",
  "options": ["Option1", "Option2", "Option3", "Option4"],
  "correct_index": 2
}
```

### Test 6: Count Questions
```sql
SELECT COUNT(*) as total_questions FROM public.questions;
```

**Expected:** 5

### Test 7: Verify Participant Data Preserved
```sql
-- If you had existing participants before migration
SELECT COUNT(*) as participant_count FROM public.participants;
SELECT COUNT(*) as answer_count FROM public.answers;
```

**Expected:** Previous counts preserved (no data loss)

## Function Security Tests

### Test Before Results Published
```sql
-- Simulate quiz in 'question' phase
UPDATE public.quiz_state SET phase = 'question', current_question = 1 WHERE id = 1;

-- Try to call function (should fail for non-admin anon users)
-- This will only work in admin context during testing
SELECT public.quiz_all_questions();
```

**Expected (as participant):** Error like "Results not published"

### Test After Results Published
```sql
-- Simulate results phase
UPDATE public.quiz_state SET phase = 'results' WHERE id = 1;

-- Try to call function (should succeed)
SELECT public.quiz_all_questions();
```

**Expected:** Full JSON with all questions and correct answers

## Cleanup Commands (if needed)

### Reset Quiz State to Lobby
```sql
UPDATE public.quiz_state 
SET phase = 'lobby', current_question = 0, updated_at = NOW()
WHERE id = 1;
```

### Clear All Participants and Answers
```sql
DELETE FROM public.answers;
DELETE FROM public.participants;
```

### Restore Original Questions (Rollback)
```sql
-- ONLY if you need to revert to original questions
UPDATE public.questions SET 
  prompt = 'What does HTTP 404 mean?',
  options = '["Success","Not Found","Unauthorized","Server Error"]'::jsonb,
  correct_index = 1
WHERE id = 1;

UPDATE public.questions SET 
  prompt = 'Which protocol secures websites?',
  options = '["FTP","HTTP","HTTPS","SMTP"]'::jsonb,
  correct_index = 2
WHERE id = 2;

UPDATE public.questions SET 
  prompt = 'What does API stand for?',
  options = '["Application Programming Interface","Automated Process Integration","Application Process Input","Advanced Programming Internet"]'::jsonb,
  correct_index = 0
WHERE id = 3;

UPDATE public.questions SET 
  prompt = 'Which status code means Internal Server Error?',
  options = '["200","301","404","500"]'::jsonb,
  correct_index = 3
WHERE id = 4;

UPDATE public.questions SET 
  prompt = 'Which database is used by Supabase?',
  options = '["MongoDB","PostgreSQL","SQLite","Redis"]'::jsonb,
  correct_index = 1
WHERE id = 5;
```

## Performance Checks

### Check Index on Answers
```sql
SELECT * FROM pg_stat_user_indexes 
WHERE relname = 'answers';
```

**Expected:** Should show an index on question_id for fast lookups

### Check Quiz State
```sql
SELECT * FROM public.quiz_state WHERE id = 1;
```

**Expected:** Single row with current phase and question number

## Integration Test Checklist

- [ ] Migration runs without errors
- [ ] All 5 new questions present in database
- [ ] quiz_all_questions() function callable
- [ ] Function returns JSON with correct structure
- [ ] Participant/answer data preserved
- [ ] Quiz state still tracks current phase
- [ ] Quiz reset clears data properly
- [ ] Scoring still calculates correctly (check is_correct boolean)

## Quick Migration Verification Script

Run all tests in sequence:

```sql
-- 1. Count questions
SELECT COUNT(*) as question_count FROM public.questions;

-- 2. Verify new questions are there
SELECT id, prompt FROM public.questions;

-- 3. Check function exists
SELECT 1 FROM pg_proc WHERE proname = 'quiz_all_questions';

-- 4. Test function (as admin)
SELECT json_array_length(public.quiz_all_questions()) as question_count_from_function;

-- 5. Check options format
SELECT options FROM public.questions WHERE id = 1;

-- 6. Verify correct indices
SELECT id, correct_index FROM public.questions;
```

**Expected:**
- question_count: 5
- 5 rows with new question prompts
- 1 row (function exists)
- question_count_from_function: 5
- Options as JSON array with 4 items
- All correct_index values between 0-3

---

✅ If all tests pass, migration is successful!
