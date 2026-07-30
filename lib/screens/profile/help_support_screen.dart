import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _supportEmail = 'redstarsuporteof@gmail.com';
  static const _supportWhatsapp = '5585998271418';
  static const _supportPhone = '+55 85 99827-1418';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajuda & Suporte'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
              title: const Text('Falar no WhatsApp'),
              subtitle: const Text(_supportPhone),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openWhatsapp(context),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_rounded, color: Color(0xFFEA4335)),
              title: const Text('E-mail'),
              subtitle: const Text(_supportEmail),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openEmail(context),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_rounded, color: Color(0xFF2196F3)),
              title: const Text('Telefone'),
              subtitle: const Text(_supportPhone),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openPhone(context),
            ),
          ),
          SizedBox(height: AppTheme.spacingLG),
          Text(
            'Perguntas frequentes',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          const _FaqTile(
            question: 'Quando recebo minha comissão?',
            answer:
                'As comissões são apuradas conforme os relatórios de vendas sincronizados com a CJ Affiliate e pagas via a chave PIX cadastrada em "Dados Bancários".',
          ),
          const _FaqTile(
            question: 'Como recebo novos links de produtos?',
            answer:
                'Os links são cadastrados manualmente pelo administrador e aparecem automaticamente em "Meus Links".',
          ),
          const _FaqTile(
            question: 'Posso alterar meu SID?',
            answer:
                'Não. O SID é vinculado à sua conta na CJ Affiliate e não pode ser alterado pelo painel.',
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsapp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/$_supportWhatsapp');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp')),
      );
    }
  }

  Future<void> _openEmail(BuildContext context) async {
    final uri = Uri(scheme: 'mailto', path: _supportEmail);
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o app de email')),
      );
    }
  }

  Future<void> _openPhone(BuildContext context) async {
    final uri = Uri.parse('tel:$_supportWhatsapp');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o discador')),
      );
    }
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedAlignment: Alignment.centerLeft,
        children: [
          Text(
            answer,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
