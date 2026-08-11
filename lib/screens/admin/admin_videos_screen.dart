import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/video.dart';
import '../../providers/video_provider.dart';
import '../../services/video_thumbnail_generator.dart';
import '../../widgets/copyright_footer.dart';
import '../../widgets/video_preview.dart';
import '../../widgets/video_thumbnail.dart';

class AdminVideosScreen extends ConsumerStatefulWidget {
  const AdminVideosScreen({super.key});

  @override
  ConsumerState<AdminVideosScreen> createState() => _AdminVideosScreenState();
}

class _AdminVideosScreenState extends ConsumerState<AdminVideosScreen> {
  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(videosProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Vídeos disponibilizados para os vendedores baixarem',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _showVideoDialog(context, ref),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: videosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (videos) {
              if (videos.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_library_outlined, size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum vídeo cadastrado',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(videosProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: videos.length + 1,
                  itemBuilder: (context, index) {
                    if (index == videos.length) {
                      return const CopyrightFooter();
                    }
                    return _VideoTile(
                      video: videos[index],
                      onEdit: () => _showVideoDialog(context, ref, video: videos[index]),
                      onDelete: () => _deleteVideo(context, ref, videos[index]),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showVideoDialog(BuildContext context, WidgetRef ref, {Video? video}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _VideoDialogBody(video: video, isEdit: video != null, ref: ref),
    );
  }

  void _deleteVideo(BuildContext context, WidgetRef ref, Video video) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir vídeo'),
        content: Text('Deseja excluir "${video.titulo}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await ref.read(videoRepositoryProvider).delete(video.id);
        ref.invalidate(videosProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.video, required this.onEdit, required this.onDelete});

  final Video video;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static String _downloadUrl(String url) {
    if (url.contains('/storage/v1/object/public/')) {
      if (url.contains('download')) return url;
      return url.contains('?') ? '$url&download' : '$url?download';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => VideoPreview.show(context, video.videoUrl, video.titulo),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Stack(
                children: [
                  VideoThumbnail(video: video, size: 72),
                  const Positioned.fill(
                    child: Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 28,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.titulo,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (video.descricao != null && video.descricao!.isNotEmpty)
                      Text(
                        video.descricao!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: (video.ativo ? colorScheme.primary : Colors.orange)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        video.ativo ? 'Ativo' : 'Inativo',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: video.ativo ? colorScheme.primary : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Baixar',
                onPressed: () async {
                  final launched = await launchUrl(
                    Uri.parse(_downloadUrl(video.videoUrl)),
                    mode: LaunchMode.externalApplication,
                  );
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Não foi possível baixar o vídeo')),
                    );
                  }
                },
                icon: const Icon(Icons.download_rounded, size: 20),
              ),
              PopupMenuButton<String>(
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoDialogBody extends StatefulWidget {
  const _VideoDialogBody({required this.video, required this.isEdit, required this.ref});

  final Video? video;
  final bool isEdit;
  final WidgetRef ref;

  @override
  State<_VideoDialogBody> createState() => _VideoDialogBodyState();
}

class _VideoDialogBodyState extends State<_VideoDialogBody> {
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _thumbCtrl;
  bool _ativo = true;
  bool _isUploading = false;
  String? _uploadedFileName;
  bool _isUploadingThumb = false;

  @override
  void initState() {
    super.initState();
    _tituloCtrl = TextEditingController(text: widget.video?.titulo ?? '');
    _descCtrl = TextEditingController(text: widget.video?.descricao ?? '');
    _urlCtrl = TextEditingController(text: widget.video?.videoUrl ?? '');
    _thumbCtrl = TextEditingController(text: widget.video?.thumbnailUrl ?? '');
    _ativo = widget.video?.ativo ?? true;
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    _thumbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isEdit ? 'Editar Vídeo' : 'Novo Vídeo',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: AppTheme.spacingLG),
            TextField(
              controller: _tituloCtrl,
              decoration: const InputDecoration(labelText: 'Título *'),
            ),
            SizedBox(height: AppTheme.spacingMD),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Descrição'),
              maxLines: 2,
            ),
            SizedBox(height: AppTheme.spacingMD),
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _pickAndUploadVideo,
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(
                _isUploading
                    ? 'Enviando...'
                    : (_uploadedFileName ?? 'Enviar arquivo de vídeo'),
              ),
            ),
            SizedBox(height: AppTheme.spacingSM),
            Text(
              'Ou cole um link direto (ex: um arquivo que você já hospeda em outro lugar seu):',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
            SizedBox(height: AppTheme.spacingSM),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Link do vídeo *',
                hintText: 'Preenchido automaticamente após o envio',
              ),
            ),
            SizedBox(height: AppTheme.spacingMD),
            OutlinedButton.icon(
              onPressed: _isUploadingThumb ? null : _pickAndUploadThumbnail,
              icon: _isUploadingThumb
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_rounded),
              label: Text(_isUploadingThumb ? 'Enviando...' : 'Enviar capa (imagem)'),
            ),
            SizedBox(height: AppTheme.spacingSM),
            TextField(
              controller: _thumbCtrl,
              decoration: const InputDecoration(
                labelText: 'URL da capa (opcional)',
                hintText: 'Preenchido automaticamente após o envio',
              ),
            ),
            SizedBox(height: AppTheme.spacingMD),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ativo'),
              value: _ativo,
              onChanged: (v) => setState(() => _ativo = v),
              activeColor: colorScheme.primary,
            ),
            SizedBox(height: AppTheme.spacingXL),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                child: Text(widget.isEdit ? 'Salvar' : 'Cadastrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadThumbnail() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível ler a imagem selecionada'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isUploadingThumb = true);

    try {
      final ext = file.name.split('.').last.toLowerCase();
      final url = await widget.ref.read(videoRepositoryProvider).uploadThumbnail(
            file.bytes!,
            file.name,
            contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
          );
      setState(() => _thumbCtrl.text = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar capa: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingThumb = false);
    }
  }

  Future<void> _pickAndUploadVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível ler o arquivo selecionado'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // Basic guardrail: Supabase's default per-file upload limit is 50MB
    // on most plans. Fail fast with a clear message instead of a cryptic
    // storage error after a long upload.
    const maxBytes = 50 * 1024 * 1024;
    if (file.size > maxBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Arquivo muito grande (${(file.size / (1024 * 1024)).toStringAsFixed(1)}MB). '
              'O limite padrão do Supabase Storage é 50MB — comprima o vídeo ou aumente o limite do bucket no painel do Supabase.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Gera a capa automaticamente a partir do próprio vídeo, uma única vez,
      // no momento do upload. Se a geração falhar por qualquer motivo, o
      // upload do vídeo continua normalmente — o botão manual de capa segue
      // disponível como alternativa.
      final thumbBytes = await generateVideoThumbnail(file.bytes!);

      final url = await widget.ref.read(videoRepositoryProvider).uploadVideo(
            file.bytes!,
            file.name,
          );

      String? thumbUrl;
      if (thumbBytes != null && _thumbCtrl.text.trim().isEmpty) {
        try {
          thumbUrl = await widget.ref.read(videoRepositoryProvider).uploadThumbnail(
                thumbBytes,
                'auto_${file.name}.jpg',
                contentType: 'image/jpeg',
              );
        } catch (_) {
          thumbUrl = null;
        }
      }

      if (!mounted) return;
      setState(() {
        _urlCtrl.text = url;
        _uploadedFileName = file.name;
        if (thumbUrl != null) _thumbCtrl.text = thumbUrl;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar vídeo: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _save() async {
    if (_tituloCtrl.text.trim().isEmpty || _urlCtrl.text.trim().isEmpty) return;

    final repo = widget.ref.read(videoRepositoryProvider);
    final newVideo = Video(
      id: widget.video?.id ?? '',
      titulo: _tituloCtrl.text.trim(),
      descricao: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      videoUrl: _urlCtrl.text.trim(),
      thumbnailUrl: _thumbCtrl.text.trim().isEmpty ? null : _thumbCtrl.text.trim(),
      displayOrder: widget.video?.displayOrder ?? 0,
      ativo: _ativo,
      createdAt: widget.video?.createdAt ?? DateTime.now(),
    );

    try {
      if (widget.isEdit) {
        await repo.update(newVideo);
      } else {
        await repo.create(newVideo);
      }
      if (mounted) Navigator.pop(context);
      widget.ref.invalidate(videosProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar vídeo: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
