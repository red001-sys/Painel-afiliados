-- Bucket público pra fotos de perfil dos vendedores. Sem isso, o upload de
-- foto no app falha com "Bucket not found" — o código já tentava usar
-- este bucket, mas ele nunca foi criado.

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Qualquer pessoa pode ver as fotos (bucket público, mostradas no app pra
-- todo mundo ver o perfil de quem quiser)
drop policy if exists "avatars_bucket_read" on storage.objects;
create policy "avatars_bucket_read"
  on storage.objects for select
  to public
  using (bucket_id = 'avatars');

-- Cada usuário só pode enviar/atualizar/apagar a PRÓPRIA foto — o nome do
-- arquivo é sempre "{auth.uid()}.ext" (é assim que o app faz upload), então
-- comparamos o início do nome do arquivo com o próprio uid.
drop policy if exists "avatars_bucket_own_insert" on storage.objects;
create policy "avatars_bucket_own_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and split_part(name, '.', 1) = auth.uid()::text
  );

drop policy if exists "avatars_bucket_own_update" on storage.objects;
create policy "avatars_bucket_own_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and split_part(name, '.', 1) = auth.uid()::text
  );

drop policy if exists "avatars_bucket_own_delete" on storage.objects;
create policy "avatars_bucket_own_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and split_part(name, '.', 1) = auth.uid()::text
  );
"