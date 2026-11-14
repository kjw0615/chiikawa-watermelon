-- 먼작귀 데굴데굴 섬: 랭킹/계정 스키마 (Supabase SQL Editor 에 통째로 붙여넣고 Run 한 번)
-- 여러 번 실행해도 안전하도록(idempotent) 작성했다.

-- 1) 테이블 ---------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  nickname    text not null unique,
  updated_at  timestamptz not null default now(),
  constraint nickname_format check (nickname ~ '^[가-힣a-zA-Z0-9-]+$' and char_length(nickname) between 2 and 12)
);
-- 대소문자만 다른 중복 닉네임도 막는다
create unique index if not exists profiles_nickname_lower_idx on public.profiles (lower(nickname));

create table if not exists public.scores (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  best_score  int not null default 0 check (best_score >= 0),
  updated_at  timestamptz not null default now()
);
create index if not exists scores_best_idx on public.scores (best_score desc, updated_at);

-- 2) 가입 시 프로필/점수 행 자동 생성 (이메일 인증을 켜 둬도 동작) ----------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, nickname) values (new.id, new.raw_user_meta_data ->> 'nickname');
  insert into public.scores (user_id, best_score) values (new.id, 0);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 3) RLS: 읽기는 누구나, 쓰기는 직접 불가(점수는 RPC 로만) --------------------
alter table public.profiles enable row level security;
alter table public.scores   enable row level security;

drop policy if exists "profiles are public" on public.profiles;
create policy "profiles are public" on public.profiles for select to anon, authenticated using (true);

drop policy if exists "scores are public" on public.scores;
create policy "scores are public" on public.scores for select to anon, authenticated using (true);

-- insert/update/delete 정책이 없으므로 클라이언트가 테이블을 직접 고칠 수 없다.
revoke insert, update, delete on public.profiles from anon, authenticated;
revoke insert, update, delete on public.scores   from anon, authenticated;

-- 4) 점수 제출 RPC: 로그인한 본인만, 신기록일 때만 갱신 ---------------------
create or replace function public.submit_score(p_score int)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  result int;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  if p_score is null or p_score < 0 or p_score > 100000000 then
    raise exception 'invalid score';
  end if;
  insert into public.scores as s (user_id, best_score, updated_at)
  values (uid, p_score, now())
  on conflict (user_id) do update
    set best_score = greatest(s.best_score, excluded.best_score),
        updated_at = case when excluded.best_score > s.best_score then now() else s.updated_at end
  returning s.best_score into result;
  return result;
end;
$$;
revoke all on function public.submit_score(int) from public, anon;
grant execute on function public.submit_score(int) to authenticated;

-- 5) 랭킹 Top N (기본 10): 순위, 닉네임, 최고점수 --------------------------
create or replace function public.get_leaderboard(p_limit int default 10)
returns table (rank bigint, nickname text, best_score int)
language sql
stable
security definer
set search_path = public
as $$
  select rank() over (order by s.best_score desc), p.nickname, s.best_score
  from public.scores s
  join public.profiles p on p.id = s.user_id
  where s.best_score > 0
  order by s.best_score desc, s.updated_at asc
  limit least(greatest(coalesce(p_limit, 10), 1), 100);
$$;
grant execute on function public.get_leaderboard(int) to anon, authenticated;

-- 6) 닉네임 중복 확인(가입 전에 친절한 안내를 위해) --------------------------
create or replace function public.nickname_available(p_nick text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (select 1 from public.profiles where lower(nickname) = lower(p_nick));
$$;
grant execute on function public.nickname_available(text) to anon, authenticated;

-- 7) 권장 대시보드 설정(SQL 로는 못 바꿈) ------------------------------------
--  Authentication > Sign In / Providers > Email: "Confirm email" 은 테스트 동안 끄기 추천
--  Authentication > Policies(Password): 최소 길이 8, 필요 문자 "문자+숫자"

-- 8) 아이디(닉네임)로 로그인 ------------------------------------------------
-- 이메일을 공개하지 않기 위해 "비밀번호까지 맞았을 때만" 이메일을 돌려준다(닉네임만으로는 이메일을 알 수 없음).
-- 무차별 대입을 줄이기 위해 같은 닉네임이 5분 안에 10번 틀리면 잠시 막는다.
create table if not exists public.login_failures (
  nick text not null,
  at   timestamptz not null default now()
);
create index if not exists login_failures_idx on public.login_failures (nick, at);
alter table public.login_failures enable row level security;   -- 정책 없음 = 클라이언트 접근 불가
revoke all on public.login_failures from anon, authenticated;

create or replace function public.login_email(p_nick text, p_password text)
returns text
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  uid uuid;
  mail text;
  pw_ok boolean;
  fails int;
begin
  if p_nick is null or p_password is null then
    return null;
  end if;
  select count(*) into fails from public.login_failures
   where nick = lower(p_nick) and at > now() - interval '5 minutes';
  if fails >= 10 then
    return null;
  end if;
  select u.id, u.email, (u.encrypted_password = extensions.crypt(p_password, u.encrypted_password))
    into uid, mail, pw_ok
    from public.profiles p
    join auth.users u on u.id = p.id
   where lower(p.nickname) = lower(p_nick);
  if uid is null or pw_ok is not true then
    insert into public.login_failures (nick) values (lower(p_nick));
    delete from public.login_failures where at < now() - interval '1 day';
    return null;
  end if;
  return mail;
end;
$$;
revoke all on function public.login_email(text, text) from public;
grant execute on function public.login_email(text, text) to anon, authenticated;

-- 9) 비밀번호 재설정: 아이디(닉네임)와 이메일이 같은 회원일 때만 메일을 보내도록 확인 ----------
-- 5분 안에 같은 아이디로 5번 불일치하면 잠시 막는다(추측 시도 제한). login_failures 표는 8) 에서 만든다.
create or replace function public.reset_email_matches(p_nick text, p_email text)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  fails int;
  matched boolean;
begin
  if p_nick is null or p_email is null then
    return false;
  end if;
  select count(*) into fails from public.login_failures
   where nick = 'reset:' || lower(p_nick) and at > now() - interval '5 minutes';
  if fails >= 5 then
    return false;
  end if;
  select exists (
    select 1 from public.profiles p
    join auth.users u on u.id = p.id
    where lower(p.nickname) = lower(p_nick) and lower(u.email) = lower(p_email)
  ) into matched;
  if not matched then
    insert into public.login_failures (nick) values ('reset:' || lower(p_nick));
  end if;
  return matched;
end;
$$;
revoke all on function public.reset_email_matches(text, text) from public;
grant execute on function public.reset_email_matches(text, text) to anon, authenticated;
