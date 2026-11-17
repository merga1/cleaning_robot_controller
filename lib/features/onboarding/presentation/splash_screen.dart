import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';

/// MOB-ONB-001: shows branding while the session and configuration restore.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next.isLoading) return;
      if (!mounted) return;
      if (next.isAuthenticated) {
        context.go('/dashboard');
      } else {
        context.go('/login');
      }
    });

    return const Scaffold(
      backgroundColor: AppColors.primaryNavy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cleaning_services_rounded,
                size: 80, color: AppColors.white),
            SizedBox(height: 20),
            Text(
              'CleanBot',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Restoring your session…',
              style: TextStyle(color: AppColors.paleBlue, fontSize: 14),
            ),
            SizedBox(height: 28),
            CircularProgressIndicator(color: AppColors.white),
          ],
        ),
      ),
    );
  }
}
