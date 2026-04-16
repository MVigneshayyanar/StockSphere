import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maxbillup/utils/language_provider.dart' as lang_provider;
import 'package:maxbillup/utils/translation_helper.dart';

/// Example page showing how to use the multi-language system
class TranslationExamplePage extends StatelessWidget {
  const TranslationExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Method 1: Get language provider
    final lang = Provider.of<lang_provider.LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        // Use translation in AppBar
        title: Text(context.tr('settings')),
        actions: [
          // Show current language
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                lang.currentLanguageName,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Example 1: Using Provider.of
          Card(
            child: ListTile(
              title: Text(context.tr('sales')),
              subtitle: Text(context.tr('new_sale')),
              trailing: const Icon(Icons.arrow_forward),
            ),
          ),
          const SizedBox(height: 16),

          // Example 2: Using TranslatedText widget
          const Card(
            child: ListTile(
              title: TranslatedText('products'),
              subtitle: TranslatedText('add_product'),
              trailing: Icon(Icons.add),
            ),
          ),
          const SizedBox(height: 16),

          // Example 3: Using context.tr() extension
          Card(
            child: ListTile(
              title: Text(context.tr('reports')),
              subtitle: Text(context.tr('daily_report')),
              trailing: const Icon(Icons.analytics),
            ),
          ),
          const SizedBox(height: 16),

          // Example 4: Buttons with translations
          ElevatedButton(
            onPressed: () {},
            child: Text(context.tr('save')),
          ),
          const SizedBox(height: 8),

          OutlinedButton(
            onPressed: () {},
            child: Text(context.tr('cancel')),
          ),
          const SizedBox(height: 24),

          // Example 5: Show all available languages
          Text(
            context.tr('available_languages'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),

          ...lang.languages.entries.map((entry) {
            final isSelected = lang.currentLanguageCode == entry.key;
            return ListTile(
              title: Text(entry.value['name']!),
              subtitle: Text(entry.value['native']!),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: () async {
                // Change language
                await lang.changeLanguage(entry.key);

                // Show confirmation
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${context.tr('language_changed_to')}: ${entry.value['name']}',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            );
          }),

          const SizedBox(height: 24),

          // Example 6: Common phrases in current language
          Text(
            context.tr('common_translations'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),

          _buildTranslationDemo(context, 'welcome'),
          _buildTranslationDemo(context, 'thank_you'),
          _buildTranslationDemo(context, 'payment_successful'),
          _buildTranslationDemo(context, 'product_added'),
        ],
      ),
    );
  }

  Widget _buildTranslationDemo(BuildContext context, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$key:',
              style: const TextStyle(
                fontFamily: 'MiSans',
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              context.tr(key),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
