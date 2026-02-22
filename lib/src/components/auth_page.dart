import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class AuthPage extends StatefulWidget {
  final VoidCallback onLogin;

  const AuthPage({super.key, required this.onLogin});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _handleSubmit() {
    // In a real app, this would call Supabase auth
    widget.onLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo/Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFbef264),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFbef264).withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(LucideIcons.bot,
                  size: 48, color: Color(0xFF4d7c0f)),
            )
                .animate()
                .rotate(begin: 0, end: -0.016, duration: 0.ms) // -6 degrees
                .moveY(begin: 20, end: 0, duration: 600.ms, curve: Curves.easeOut)
                .fadeIn(duration: 600.ms),
            const SizedBox(height: 16),
            Text(
              'AI Chat',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                    letterSpacing: -0.5,
                  ),
            )
                .animate()
                .moveY(begin: 20, end: 0, duration: 600.ms, delay: 100.ms, curve: Curves.easeOut)
                .fadeIn(duration: 600.ms, delay: 100.ms),
            const SizedBox(height: 8),
            Text(
              'Your intelligent companion for files and images',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            )
                .animate()
                .moveY(begin: 20, end: 0, duration: 600.ms, delay: 200.ms, curve: Curves.easeOut)
                .fadeIn(duration: 600.ms, delay: 200.ms),
            const SizedBox(height: 32),

            // Form
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isLogin ? 'Welcome Back' : 'Create Account',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827), // gray-900
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        label: 'Email Address',
                        icon: LucideIcons.mail,
                        controller: _emailController,
                        hint: 'name@example.com',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Password',
                        icon: LucideIcons.lock,
                        controller: _passwordController,
                        hint: '••••••••',
                        obscureText: true,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06b6d4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          shadowColor: const Color(0xFF06b6d4).withValues(alpha: 0.3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLogin ? 'Sign In' : 'Get Started',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(LucideIcons.arrowRight, size: 20),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                              child: Divider(color: Colors.grey[200], thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR CONTINUE WITH',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          Expanded(
                              child: Divider(color: Colors.grey[200], thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(LucideIcons.github, size: 20),
                        label: const Text('GitHub'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151), // gray-700
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey[200]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
                .animate()
                .moveY(begin: 20, end: 0, duration: 600.ms, delay: 300.ms, curve: Curves.easeOut)
                .fadeIn(duration: 600.ms, delay: 300.ms),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isLogin ? "Don't have an account?" : "Already have an account?",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                    });
                  },
                  child: Text(
                    _isLogin ? 'Sign Up' : 'Log In',
                    style: const TextStyle(
                      color: Color(0xFF0891b2),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
                .animate()
                .fadeIn(duration: 600.ms, delay: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(icon, color: Colors.grey[400], size: 18),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.5),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF06b6d4), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
