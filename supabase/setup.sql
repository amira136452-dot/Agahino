-- آگهینو: راه‌اندازی پایگاه داده در Supabase
-- این فایل را فقط یک بار در بخش SQL Editor پروژه Supabase اجرا کنید.
-- هرگز کلید service_role را در سایت یا GitHub قرار ندهید.

create extension if not exists pgcrypto;

create table if not exists public.ads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 2 and 70),
  category text not null,
  price bigint check (price is null or price >= 0),
  city text not null,
  description text not null default '' check (char_length(description) <= 500),
  image_path text,
  status text not null default 'published'
    check (status in ('draft', 'published', 'sold', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ads_status_created_at_idx
  on public.ads (status, created_at desc);
create index if not exists ads_city_idx on public.ads (city);
create index if not exists ads_category_idx on public.ads (category);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists ads_set_updated_at on public.ads;
create trigger ads_set_updated_at
before update on public.ads
for each row execute function public.set_updated_at();

alter table public.ads enable row level security;

drop policy if exists "Anyone can view published ads" on public.ads;
create policy "Anyone can view published ads"
on public.ads for select
using (status = 'published' or auth.uid() = user_id);

drop policy if exists "Users can create their own ads" on public.ads;
create policy "Users can create their own ads"
on public.ads for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can update their own ads" on public.ads;
create policy "Users can update their own ads"
on public.ads for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own ads" on public.ads;
create policy "Users can delete their own ads"
on public.ads for delete
to authenticated
using (auth.uid() = user_id);

-- فضای عمومی تصاویر آگهی
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ad-images', 'ad-images', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
set public = true,
    file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists "Public can view ad images" on storage.objects;
create policy "Public can view ad images"
on storage.objects for select
using (bucket_id = 'ad-images');

drop policy if exists "Users upload images to their own folder" on storage.objects;
create policy "Users upload images to their own folder"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'ad-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users update images in their own folder" on storage.objects;
create policy "Users update images in their own folder"
on storage.objects for update
to authenticated
using (
  bucket_id = 'ad-images'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'ad-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users delete images in their own folder" on storage.objects;
create policy "Users delete images in their own folder"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'ad-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- نکته: این فایل فقط ساختار امن پایگاه داده و فضای تصویر را آماده می‌کند.
-- اتصال سایت به Supabase و افزودن ورود/ثبت‌نام کاربران، مرحله بعدی است.
