-- ============================================================
--  供養アーカイブ — Supabase Schema
--  Run this in the Supabase SQL Editor to set up the database
-- ============================================================

-- ── Extensions ──────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ── profiles ────────────────────────────────────────────────
-- Extended user profile, synced from auth.users via trigger
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  username      text,                        -- Twitter screen_name
  display_name  text,                        -- Twitter name
  avatar_url    text,                        -- Twitter profile image
  twitter_id    text unique,
  is_creator    boolean default false,       -- Manually set for verified VTubers
  created_at    timestamptz default now()
);

-- Auto-create profile on sign-up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, username, display_name, avatar_url, twitter_id)
  values (
    new.id,
    new.raw_user_meta_data ->> 'user_name',
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'avatar_url',
    new.raw_user_meta_data ->> 'provider_id'
  )
  on conflict (id) do update set
    username     = excluded.username,
    display_name = excluded.display_name,
    avatar_url   = excluded.avatar_url;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ── posts ────────────────────────────────────────────────────
create table if not exists public.posts (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid references public.profiles(id) on delete cascade not null,
  title         text not null check (char_length(title) between 1 and 100),
  category      text not null check (category in ('design','outfit','name','lore','bgm','other')),
  reason        text,
  description   text not null check (char_length(description) between 10 and 400),
  full_desc     text not null check (char_length(full_desc) between 10 and 2000),
  tags          text[] default '{}',
  image_url     text,
  vote_count    integer default 0,
  comment_count integer default 0,
  is_hof        boolean default false,       -- Hall of Fame
  is_revived    boolean default false,       -- Marked as revived by creator
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- Full-text search index (Japanese + English)
create index if not exists posts_fts_idx
  on public.posts using gin(
    to_tsvector('simple',
      coalesce(title,'') || ' ' ||
      coalesce(description,'') || ' ' ||
      coalesce(array_to_string(tags,' '),'')
    )
  );

create index if not exists posts_category_idx on public.posts(category);
create index if not exists posts_votes_idx    on public.posts(vote_count desc);
create index if not exists posts_created_idx  on public.posts(created_at desc);

-- ── votes ────────────────────────────────────────────────────
create table if not exists public.votes (
  id         uuid primary key default uuid_generate_v4(),
  post_id    uuid references public.posts(id) on delete cascade not null,
  user_id    uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique (post_id, user_id)
);

-- Keep vote_count in sync
create or replace function public.update_vote_count()
returns trigger language plpgsql security definer as $$
begin
  if TG_OP = 'INSERT' then
    update public.posts set vote_count = vote_count + 1 where id = NEW.post_id;
  elsif TG_OP = 'DELETE' then
    update public.posts set vote_count = greatest(0, vote_count - 1) where id = OLD.post_id;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_vote_insert on public.votes;
create trigger trg_vote_insert after insert on public.votes
  for each row execute procedure public.update_vote_count();

drop trigger if exists trg_vote_delete on public.votes;
create trigger trg_vote_delete after delete on public.votes
  for each row execute procedure public.update_vote_count();

-- ── comments ─────────────────────────────────────────────────
create table if not exists public.comments (
  id         uuid primary key default uuid_generate_v4(),
  post_id    uuid references public.posts(id) on delete cascade not null,
  user_id    uuid references public.profiles(id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 500),
  created_at timestamptz default now()
);

create index if not exists comments_post_idx on public.comments(post_id, created_at asc);

-- Keep comment_count in sync
create or replace function public.update_comment_count()
returns trigger language plpgsql security definer as $$
begin
  if TG_OP = 'INSERT' then
    update public.posts set comment_count = comment_count + 1 where id = NEW.post_id;
  elsif TG_OP = 'DELETE' then
    update public.posts set comment_count = greatest(0, comment_count - 1) where id = OLD.post_id;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_comment_insert on public.comments;
create trigger trg_comment_insert after insert on public.comments
  for each row execute procedure public.update_comment_count();

drop trigger if exists trg_comment_delete on public.comments;
create trigger trg_comment_delete after delete on public.comments
  for each row execute procedure public.update_comment_count();

-- ── updated_at auto-bump ──────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_posts_updated on public.posts;
create trigger trg_posts_updated before update on public.posts
  for each row execute procedure public.set_updated_at();

-- ── Storage bucket ───────────────────────────────────────────
-- Create via Supabase Dashboard → Storage → New Bucket
-- Bucket name: "post-images"  (public: true)
-- Or run:
-- insert into storage.buckets (id, name, public) values ('post-images', 'post-images', true);

-- ── Row Level Security ────────────────────────────────────────
alter table public.profiles  enable row level security;
alter table public.posts     enable row level security;
alter table public.votes     enable row level security;
alter table public.comments  enable row level security;

-- profiles: anyone can read; only own row can update
create policy "profiles: public read"
  on public.profiles for select using (true);

create policy "profiles: own update"
  on public.profiles for update using (auth.uid() = id);

-- posts: anyone can read; only owner can insert/update/delete
create policy "posts: public read"
  on public.posts for select using (true);

create policy "posts: auth insert"
  on public.posts for insert with check (auth.uid() = user_id);

create policy "posts: own update"
  on public.posts for update using (auth.uid() = user_id);

create policy "posts: own delete"
  on public.posts for delete using (auth.uid() = user_id);

-- votes: anyone can read; auth users can insert/delete own
create policy "votes: public read"
  on public.votes for select using (true);

create policy "votes: auth insert"
  on public.votes for insert with check (auth.uid() = user_id);

create policy "votes: own delete"
  on public.votes for delete using (auth.uid() = user_id);

-- comments: anyone can read; auth users can insert; own delete
create policy "comments: public read"
  on public.comments for select using (true);

create policy "comments: auth insert"
  on public.comments for insert with check (auth.uid() = user_id);

create policy "comments: own delete"
  on public.comments for delete using (auth.uid() = user_id);

-- Storage policies (post-images bucket)
create policy "images: public read"
  on storage.objects for select using (bucket_id = 'post-images');

create policy "images: auth upload"
  on storage.objects for insert
  with check (bucket_id = 'post-images' and auth.role() = 'authenticated');

create policy "images: own delete"
  on storage.objects for delete
  using (bucket_id = 'post-images' and owner = auth.uid()::text);
