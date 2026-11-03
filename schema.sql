-- Run once in Supabase SQL Editor. Use a NEW Supabase project for this event.
create extension if not exists pgcrypto;
create table public.admin_users (user_id uuid primary key references auth.users(id) on delete cascade);
create table public.quiz_state (id integer primary key default 1 check(id=1), phase text not null default 'lobby' check(phase in ('lobby','question','waiting','results')), current_question integer not null default 0 check(current_question between 0 and 5), updated_at timestamptz not null default now());
insert into public.quiz_state(id) values (1);
create table public.questions (id integer primary key check(id between 1 and 5), prompt text not null, options jsonb not null check(jsonb_typeof(options)='array' and jsonb_array_length(options)=4), correct_index integer not null check(correct_index between 0 and 3));
insert into public.questions values
(1,'What does HTTP 404 mean?','["Success","Not Found","Unauthorized","Server Error"]',1),
(2,'Which protocol secures websites?','["FTP","HTTP","HTTPS","SMTP"]',2),
(3,'What does API stand for?','["Application Programming Interface","Automated Process Integration","Application Process Input","Advanced Programming Internet"]',0),
(4,'Which status code means Internal Server Error?','["200","301","404","500"]',3),
(5,'Which database is used by Supabase?','["MongoDB","PostgreSQL","SQLite","Redis"]',1);
create table public.participants (id uuid primary key default gen_random_uuid(), name text not null check(char_length(name) between 1 and 60), token uuid not null unique default gen_random_uuid(), joined_at timestamptz not null default now());
create table public.answers (participant_id uuid not null references public.participants(id) on delete cascade, question_id integer not null references public.questions(id), choice_index integer not null check(choice_index between 0 and 3), is_correct boolean not null, submitted_at timestamptz not null default now(), primary key(participant_id,question_id));
create index on public.answers(question_id);
-- No table may be read or modified directly by browsers.
alter table public.admin_users enable row level security;
alter table public.quiz_state enable row level security;
alter table public.questions enable row level security;
alter table public.participants enable row level security;
alter table public.answers enable row level security;
revoke all on all tables in schema public from anon, authenticated;
-- SECURITY DEFINER functions expose only intended operations.
create or replace function public.is_quiz_admin() returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.admin_users where user_id = auth.uid()) $$;
create or replace function public.quiz_view() returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.quiz_state%rowtype; q jsonb; n integer;
begin
 select * into s from public.quiz_state where id=1;
 select count(*) into n from public.participants;
 if s.phase='question' then select jsonb_build_object('id',id,'prompt',prompt,'options',options) into q from public.questions where id=s.current_question; end if;
 return jsonb_build_object('phase',s.phase,'current_question',s.current_question,'question',q,'participants',n,'updated_at',s.updated_at);
end $$;
create or replace function public.join_quiz(p_name text) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.participants%rowtype;
begin
 if (select phase from public.quiz_state where id=1) <> 'lobby' then raise exception 'Joining is closed'; end if;
 if p_name is null or char_length(btrim(p_name)) not between 1 and 60 then raise exception 'Name must be 1-60 characters'; end if;
 insert into public.participants(name) values (btrim(p_name)) returning * into p;
 return jsonb_build_object('id',p.id,'name',p.name,'token',p.token);
end $$;
create or replace function public.submit_quiz_answer(p_token uuid,p_question_id integer,p_choice integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare p_id uuid; s public.quiz_state%rowtype; correct integer;
begin
 select id into p_id from public.participants where token=p_token;
 if p_id is null then raise exception 'Invalid participant'; end if;
 select * into s from public.quiz_state where id=1;
 if s.phase <> 'question' or s.current_question <> p_question_id then raise exception 'Question is not active'; end if;
 if p_choice not between 0 and 3 then raise exception 'Invalid choice'; end if;
 select correct_index into correct from public.questions where id=p_question_id;
 insert into public.answers(participant_id,question_id,choice_index,is_correct) values(p_id,p_question_id,p_choice,p_choice=correct);
 return jsonb_build_object('accepted',true);
exception when unique_violation then raise exception 'Answer already submitted';
end $$;
create or replace function public.my_quiz_answers(p_token uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare p_id uuid;
begin
 select id into p_id from public.participants where token=p_token;
 if p_id is null then raise exception 'Invalid participant'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('question_id',question_id,'choice_index',choice_index)) from public.answers where participant_id=p_id),'[]'::jsonb);
end $$;
create or replace function public.quiz_leaderboard() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if (select phase from public.quiz_state where id=1) <> 'results' and not public.is_quiz_admin() then raise exception 'Results not published'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('name',name,'score',score,'rank',rank) order by rank,name) from (select p.name, count(a.question_id) filter(where a.is_correct)::integer as score, rank() over(order by count(a.question_id) filter(where a.is_correct) desc) as rank from public.participants p left join public.answers a on a.participant_id=p.id group by p.id,p.name) t),'[]'::jsonb);
end $$;
create or replace function public.admin_quiz_action(p_action text) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.quiz_state%rowtype;
begin
 if not public.is_quiz_admin() then raise exception 'Not authorized'; end if;
 select * into s from public.quiz_state where id=1 for update;
 if p_action='next' and s.phase in ('lobby','waiting') and s.current_question < 5 then
   update public.quiz_state set phase='question',current_question=s.current_question+1,updated_at=now() where id=1;
 elsif p_action='close' and s.phase='question' then
   update public.quiz_state set phase='waiting',updated_at=now() where id=1;
 elsif p_action='publish' and s.current_question=5 and s.phase='waiting' then
   update public.quiz_state set phase='results',updated_at=now() where id=1;
 elsif p_action='reset' then
   delete from public.answers; delete from public.participants;
   update public.quiz_state set phase='lobby',current_question=0,updated_at=now() where id=1;
 else raise exception 'Invalid action for current state'; end if;
 return public.quiz_view();
end $$;
-- PostgreSQL grants EXECUTE to PUBLIC on new functions by default; remove it.
revoke execute on all functions in schema public from public;
-- Grant only narrowly scoped RPC calls.
grant usage on schema public to anon,authenticated;
grant execute on function public.quiz_view() to anon,authenticated;
grant execute on function public.join_quiz(text) to anon,authenticated;
grant execute on function public.submit_quiz_answer(uuid,integer,integer) to anon,authenticated;
grant execute on function public.my_quiz_answers(uuid) to anon,authenticated;
grant execute on function public.quiz_leaderboard() to anon,authenticated;
grant execute on function public.is_quiz_admin() to authenticated;
grant execute on function public.admin_quiz_action(text) to authenticated;
-- Never expose the secret participant token or the correct_index in public queries.
-- Realtime broadcast via public state changes: quiz_state contains no secrets.
grant select on public.quiz_state to anon,authenticated;
create policy "state readable" on public.quiz_state for select to anon,authenticated using (true);
alter publication supabase_realtime add table public.quiz_state;
-- Admin setup AFTER creating an email/password user in Authentication > Users:
-- insert into public.admin_users(user_id) select id from auth.users where email='YOUR_ADMIN_EMAIL@example.com';
