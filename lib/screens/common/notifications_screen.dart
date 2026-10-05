import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../widgets/infurnus_app_bar.dart';
import '../../core/theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final notifs = appState.notifications;

    return Scaffold(
      backgroundColor: InfurnusTheme.bgWhite,
      appBar: const InfurnusAppBar(title: 'Notifications'),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: notifs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = notifs[index];

            return InkWell(
              onTap: () => appState.markNotificationRead(item.id),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: item.isRead ? Colors.white : InfurnusTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: item.isRead ? const Color(0xFFE2E8F0) : InfurnusTheme.primaryGreen,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: InfurnusTheme.textDark,
                              fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(item.timestamp, style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(item.body, style: const TextStyle(color: InfurnusTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
