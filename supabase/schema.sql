-- آگهینو: ساختار اولیه پایگاه داده Supabase
-- این فایل را پس از ساخت پروژه Supabase در بخش SQL Editor اجرا کنید.
-- کلیدهای محرمانه را هرگز در GitHub یا فایل‌های سایت قرار ندهید.

create table if not exists public.ads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 120),
  category text not null,
  price numeric(14,2),
  city text not null,
  description text not null default '',
  image_path text,
  status text not null default 'published'
    check (status in ('draft', 'published', 'sold', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ads_status_created_at_idx
  on public.ads (status, created_at desc);
create index if not exists ads_user_id_created_at_idx
  on public.ads (user_id, created_at desc);

alter table public.ads enable row level security;

drop policy if exists "Anyone can view published ads" on public.ads;
create policy "Anyone can view published ads"
  on public.ads for select
  using (status = 'published' or auth.uid() = user_id);

drop policy if exists "Users can insert their own ads" on public.ads;
create policy "Users can insert their own ads"
  on public.ads for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own ads" on public.ads;
create policy "Users can update their own ads"
  on public.ads for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own ads" on public.ads;
create policy "Users can delete their own ads"
  on public.ads for delete to authenticated
  using (auth.uid() = user_id);

-- فضای ذخیره‌سازی عکس آگهی‌ها؛ خواندن عمومی، بارگذاری فقط در پوشه شناسه خود کاربر.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'ad-images',
  'ad-images',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can view ad images" on storage.objects;
create policy "Public can view ad images"
  on storage.objects for select
  using (bucket_id = 'ad-images');

drop policy if exists "Users can upload their own ad images" on storage.objects;
create policy "Users can upload their own ad images"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'ad-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users can update their own ad images" on storage.objects;
create policy "Users can update their own ad images"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'ad-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'ad-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users can delete their own ad images" on storage.objects;
create policy "Users can delete their own ad images"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'ad-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
