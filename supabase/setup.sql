-- آگهینو: راه‌اندازی امن و تکرارپذیر پایگاه داده در Supabase
-- این فایل برای پروژه تازه است؛ روی پروژه فعال فقط در صورت نیاز و با بررسی قبلی اجرا شود.
-- هرگز کلید service_role یا secret را در سایت یا GitHub قرار ندهید.

create extension if not exists pgcrypto;

create table if not exists public.ads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 120),
  category text not null,
  price numeric(14,2),
  city text not null,
  description text not null default '',
  image_path text,
  image_url text,
  status text not null default 'published'
    check (status in ('draft', 'published', 'sold', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ads_status_created_at_idx
  on public.ads (status, created_at desc);
create index if not exists ads_user_id_created_at_idx
  on public.ads (user_id, created_at desc);

create or replace function public.set_ads_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists ads_set_updated_at on public.ads;
create trigger ads_set_updated_at
before update on public.ads
for each row execute function public.set_ads_updated_at();

alter table public.ads enable row level security;

drop policy if exists "Anyone can view published ads" on public.ads;
create policy "Anyone can view published ads"
on public.ads for select
using (status = 'published' or (select auth.uid()) = user_id);

drop policy if exists "Users can create their own ads" on public.ads;
drop policy if exists "Users can insert their own ads" on public.ads;
create policy "Users can insert their own ads"
on public.ads for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own ads" on public.ads;
create policy "Users can update their own ads"
on public.ads for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own ads" on public.ads;
create policy "Users can delete their own ads"
on public.ads for delete to authenticated
using ((select auth.uid()) = user_id);

-- فضای عمومی تصاویر؛ مشاهده عمومی، مدیریت فقط در پوشه اختصاصی هر کاربر.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ad-images', 'ad-images', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can view ad images" on storage.objects;
create policy "Public can view ad images"
on storage.objects for select
using (bucket_id = 'ad-images');

drop policy if exists "Users upload images to their own folder" on storage.objects;
drop policy if exists "Users can upload their own ad images" on storage.objects;
create policy "Users can upload their own ad images"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'ad-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users update images in their own folder" on storage.objects;
drop policy if exists "Users can update their own ad images" on storage.objects;
create policy "Users can update their own ad images"
on storage.objects for update to authenticated
using (
  bucket_id = 'ad-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'ad-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users delete images in their own folder" on storage.objects;
drop policy if exists "Users can delete their own ad images" on storage.objects;
create policy "Users can delete their own ad images"
on storage.objects for delete to authenticated
using (
  bucket_id = 'ad-images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- این فایل زیرساخت پایگاه داده و ذخیره تصویر را آماده می‌کند.
-- اتصال Auth و فرم‌های سایت در index.html مدیریت می‌شوند.
