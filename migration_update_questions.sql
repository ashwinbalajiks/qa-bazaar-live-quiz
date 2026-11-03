-- Migration: Update questions and add results display support
-- Run this AFTER schema.sql in Supabase SQL Editor

-- Update the 5 questions with new content
UPDATE public.questions SET 
  prompt = 'Why can''t you buy groceries in Germany on a Sunday?',
  options = '["Supermarkets also need a day to recharge", "Germans only shop when it rains", "Sunday is a legal rest day, so most shops are closed", "All the cashiers are at the beer garden"]'::jsonb,
  correct_index = 2
WHERE id = 1;

UPDATE public.questions SET 
  prompt = 'In Malaysia, what does "tapau" mean?',
  options = '["A secret handshake", "Take-away food", "Sleeping after lunch", "Extra spicy, no regrets"]'::jsonb,
  correct_index = 1
WHERE id = 2;

UPDATE public.questions SET 
  prompt = 'What does "Feierabend" mean?',
  options = '["The yearly beer festival", "A fire drill", "The time after work, when the working day is over", "A bedtime story"]'::jsonb,
  correct_index = 2
WHERE id = 3;

UPDATE public.questions SET 
  prompt = 'What is "teh tarik"?',
  options = '["Tea thrown at your colleague", "Tea that has to be pulled by a team of four", "Cold tea in a plastic bag", "Tea poured between two cups to make it frothy"]'::jsonb,
  correct_index = 3
WHERE id = 4;

UPDATE public.questions SET 
  prompt = 'What is true about the weather in Malaysia?',
  options = '["It snows every December", "It is hot and humid all year round", "It is sunny 365 days with no rain", "People wear a winter jacket outside every morning"]'::jsonb,
  correct_index = 1
WHERE id = 5;

-- Add function to fetch all questions with their correct answers
-- Only callable when results are published or by admin
create or replace function public.quiz_all_questions() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if (select phase from public.quiz_state where id=1) <> 'results' and not public.is_quiz_admin() then raise exception 'Results not published'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',id,'prompt',prompt,'options',options,'correct_index',correct_index) order by id) from public.questions),'[]'::jsonb);
end $$;

-- Grant execute permission for the new function
grant execute on function public.quiz_all_questions() to anon,authenticated;
