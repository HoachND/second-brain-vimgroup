-- Categories table
create table if not exists categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamp default now()
);

-- Notes table
create table if not exists notes (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references categories(id),
  title text not NULL,
  content text,
  source text,
  created_at timestamp default now(),
  updated_at timestamp default now()
);

-- Tags table (many-to-many with notes)
create table if not exists tags (
  id uuid primary key default gen_random_uuid(),
  name text not null unique
);

create table if not exists note_tags (
  note_id uuid references notes(id) on delete cascade,
  tag_id uuid references tags(id) on delete cascade,
  primary key (note_id, tag_id)
);

-- Enable Row Level Security (RLS)
alter table categories enable row level security;
alter table notes enable row level security;
alter table tags enable row level security;
alter table note_tags enable row level security;

-- Policy: everyone can read
create policy "Everyone can read categories" on categories for select using (true);
create policy "Everyone can read notes" on notes for select using (true);
create policy "Everyone can read tags" on tags for select using (true);
create policy "Everyone can read note_tags" on note_tags for select using (true);

-- Policy: service role can insert/update/delete (handled via service_role key)
-- Client side uses anon key with upsert