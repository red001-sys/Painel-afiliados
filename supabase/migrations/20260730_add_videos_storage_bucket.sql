-- Bucket público pra hospedar os arquivos de vídeo enviados pelo admin,
-- permitindo download direto (sem redirecionar pra um serviço externo)

insert into storage.buckets (id, name, public)
values ('videos', 'videos', true)
on conflict (id) do nothing;

-- Qualquer pessoa (mesmo sem login) pode ler/baixar, já que o bucket é público
drop policy if exists "videos_bucket_read" on storage.objects;
create policy "videos_bucket_read"
  on storage.objects for select
  to public
  using (bucket_id = 'videos');

-- Só admin pode enviar, atualizar ou apagar arquivos
drop policy if exists "videos_bucket_admin_insert" on storage.objects;
create policy "videos_bucket_admin_insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'videos' and public.is_admin());

drop policy if exists "videos_bucket_admin_update" on storage.objects;
create policy "videos_bucket_admin_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'videos' and public.is_admin());

drop policy if exists "videos_bucket_admin_delete" on storage.objects;
create policy "videos_bucket_admin_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'videos' and public.is_admin());
