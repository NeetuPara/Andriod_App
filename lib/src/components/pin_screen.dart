import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'glass_container.dart';
import '../screens/reset_pin_screen.dart';

class PinScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const PinScreen({super.key, required this.onAuthenticated});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String? _storedPin;
  bool _isSetupMode = false;
  String _confirmPin = '';
  String _message = 'Enter PIN';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkStoredPin();
  }

  Future<void> _checkStoredPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final pin = prefs.getString('user_pin');
      setState(() {
        _storedPin = pin;
        _isLoading = false;
        if (_storedPin == null) {
          _isSetupMode = true;
          _message = 'Set your 4-digit PIN';
        } else {
          _message = 'Enter your security PIN';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading PIN: $e')),
        );
      }
    }
  }

  // ... (existing helper methods) ...

  void _handleKeyPress(String key) {
    if (_pin.length < 4) {
      setState(() {
        _pin += key;
      });
    }
  }

  void _handleBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _validatePin() async {
    if (_pin.length < 4) return;

    try {
      if (_isSetupMode) {
        if (_confirmPin.isEmpty) {
          setState(() {
            _confirmPin = _pin;
            _pin = '';
            _message = 'Confirm your 4-digit PIN';
          });
        } else {
          if (_pin == _confirmPin) {
            final prefs = await SharedPreferences.getInstance();
            if (!mounted) return;
            await prefs.setString('user_pin', _pin);
            if (!mounted) return;
            widget.onAuthenticated();
          } else {
            setState(() {
              _pin = '';
              _confirmPin = '';
              _message = 'PINs do not match. Try again.';
            });
          }
        }
      } else {
        if (_pin == _storedPin) {
          widget.onAuthenticated();
        } else {
          setState(() {
            _pin = '';
            _message = 'Incorrect PIN. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PIN: $e')),
        );
        setState(() {
           _pin = '';
           _confirmPin = '';
           _message = 'Error occurred. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF101b22),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    const primaryColor = Color(0xFF0d93f2);
    const backgroundDark = Color(0xFF101b22);

    return Stack(
      children: [
        // Radial Gradient Background
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  const Color(0xFF002a3a),
                  backgroundDark,
                  backgroundDark,
                ],
              ),
            ),
          ),
        ),
        
        SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 40),
                      
                      // Header Icon
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_person,
                          size: 48,
                          color: primaryColor,
                        ),
                      ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                      
                      const SizedBox(height: 24),
                      
                      Text(
                        _isSetupMode && _confirmPin.isEmpty ? "Direct Access" : "Welcome Back",
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          _message,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // PIN Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          bool isFilled = index < _pin.length;
                          return Container(
                            width: 14,
                            height: 14,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFilled ? primaryColor : Colors.transparent,
                              border: Border.all(
                                color: isFilled ? primaryColor : Colors.white24,
                                width: 2,
                              ),
                              boxShadow: isFilled ? [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
                              ] : null,
                            ),
                          ).animate(target: isFilled ? 1 : 0).scale(duration: 200.ms);
                        }),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Keypad
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 3,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 30,
                          childAspectRatio: 1.0,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (var i = 1; i <= 9; i++) _buildKey(i.toString()),
                            _buildActionKey(Icons.mic, color: primaryColor),
                            _buildKey("0"),
                            _buildActionKey(Icons.backspace, color: Colors.white38, onTap: _handleBackspace),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Forgot/Reset Access
                      if (!_isSetupMode)
                         TextButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ResetPinScreen()),
                            );
                            _checkStoredPin(); // Reload PIN after return
                          },
                          child: Text(
                            "Forgot PIN?",
                            style: GoogleFonts.inter(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 20),
                      
                      // Validation Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _pin.length == 4 ? _validatePin : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.white10,
                              disabledForegroundColor: Colors.white24,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                               _isSetupMode 
                                ? (_confirmPin.isEmpty ? "NEXT" : "CONFIRM")
                                : "UNLOCK",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
  }

  Widget _buildKey(String value) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleKeyPress(value),
        borderRadius: BorderRadius.circular(50),
        child: GlassContainer(
          borderRadius: BorderRadius.circular(50),
          opacity: 0.05,
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          child: Center(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey(IconData icon, {Color? color, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Center(
          child: Icon(
            icon,
            size: 28,
            color: color ?? Colors.white,
          ),
        ),
      ),
    );
  }
}
