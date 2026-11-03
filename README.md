# Live Event Quiz MVP

## 1. Create Supabase project
- Create a new project at https://supabase.com/dashboard.
- SQL Editor > New query > paste and run `schema.sql`.
- Authentication > Users > Add user > create host email/password (confirm email as needed).
- SQL Editor > run `insert into public.admin_users(user_id) select id from auth.users where email='HOST_EMAIL_HERE';` replacing email.
- Project Settings > API Keys: copy project URL and **publishable/anon** key. NEVER use the service_role or secret key in the frontend.
- For a private event, disable public email signups in Authentication settings; manually created host user remains usable.

## 2. Run locally
```bash
npm install
cp .env.example .env
# Edit .env with your project URL and publishable/anon key
npm run dev
```
Visit http://localhost:5173/admin for host and http://localhost:5173/ for participants.

## 3. Cloudflare Pages deployment
- Push code to a GitHub repository. Do NOT commit `.env`.
- Cloudflare Dashboard > Workers & Pages > Create > Pages > Connect to Git.
- Framework: Vite; Build command: `npm run build`; Output directory: `dist`.
- Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` as build environment variables.
- Deploy. Share the resulting `https://<your-site>.pages.dev/` with participants.
- Host goes to `https://<your-site>.pages.dev/admin`.
- If directly opening `/admin` fails on your Pages setup, add a `_redirects` file in the `public` directory with `/* /index.html 200`, then redeploy.

## 4. Event flow
1. Participants enter name before start.
2. Host clicks Start question 1.
3. Participant submits one choice; cannot change it.
4. Host clicks Close question, then Publish question 2. Repeat through question 5.
5. Host clicks Publish final results; leaderboard becomes visible to everyone.

## 5. Smoke test
- Use separate browsers/devices: one admin and two participants.
- Confirm all participants receive the same question and that next is controlled by admin.
- Check a second answer is rejected, results are hidden until published, and scores are correct.
- Test refresh/reconnect and a 50-100 user rehearsal if possible.

## Limitations / production hardening
- Name-only joins allow duplicate display names and participants can impersonate names. Browser-local tokens are not user accounts.
- A participant who clears browser storage loses access to their existing identity.
- Public anonymous RPCs can be abused without CAPTCHA, per-IP rate limiting or an Edge Function gateway. Use for a trusted event, not a hostile public launch.
- Score ties share rank (no speed scoring).
- State updates use Realtime with a 10-second polling fallback. A realtime notification may be delayed or missed.
- Reset is destructive and deletes all participants and answers.
- The event has one session; changing questions requires SQL edits before the event.
