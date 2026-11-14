-- 아이디(닉네임) 로그인 추가분: 이미 schema.sql 을 실행한 프로젝트에서 이것만 Run 하면 된다(여러 번 실행해도 안전).

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
