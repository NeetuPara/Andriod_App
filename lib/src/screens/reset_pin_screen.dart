import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/glass_container.dart';

class ResetPinScreen extends StatefulWidget {
  const ResetPinScreen({super.key});

  @override
  State<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends State<ResetPinScreen> {
  String _newPin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _message = "Enter your new 4-digit security PIN";

  void _handleKeyPress(String key) {
    setState(() {
      if (!_isConfirming) {
        if (_newPin.length < 4) _newPin += key;
      } else {
        if (_confirmPin.length < 4) _confirmPin += key;
      }
    });

    if (!_isConfirming && _newPin.length == 4) {
      Future.delayed(const Duration(milliseconds: 300), () {
        setState(() {
          _isConfirming = true;
          _message = "Confirm your new 4-digit security PIN";
        });
      });
    } else if (_isConfirming && _confirmPin.length == 4) {
      _validateAndSave();
    }
  }

  void _handleBackspace() {
    setState(() {
      if (!_isConfirming) {
        if (_newPin.isNotEmpty) _newPin = _newPin.substring(0, _newPin.length - 1);
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
           _isConfirming = false;
           _message = "Enter your new 4-digit security PIN";
        }
      }
    });
  }

  Future<void> _validateAndSave() async {
    if (_newPin == _confirmPin) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_pin', _newPin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PIN reset successful")),
        );
        Navigator.pop(context);
      }
    } else {
      setState(() {
        _confirmPin = '';
        _message = "PINs do not match. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundDark = Color(0xFF101b22);
    const primaryColor = Color(0xFF0d93f2);

    return Scaffold(
      backgroundColor: backgroundDark,
      body: Stack(
        children: [
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
                child: Column(
                  children: [
                    _buildHeader(),
                    const Spacer(),
                    _buildLockIcon(primaryColor),
                    const SizedBox(height: 32),
                    _buildMessage(),
                    const SizedBox(height: 48),
                    _buildPinDots(primaryColor),
                    const Spacer(),
                    _buildKeypad(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white60),
          ),
          Text(
            "Reset Security PIN",
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockIcon(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.security, size: 48, color: primaryColor),
    );
  }

  Widget _buildMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        _message,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: Colors.white70,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildPinDots(Color primaryColor) {
    String activePin = _isConfirming ? _confirmPin : _newPin;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        bool isFilled = index < activePin.length;
        return Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? primaryColor : Colors.transparent,
            border: Border.all(color: isFilled ? primaryColor : Colors.white24, width: 2),
            boxShadow: isFilled ? [BoxShadow(color: primaryColor.withValues(alpha: 0.5), blurRadius: 10)] : null,
          ),
        );
      }),
    );
  }

  Widget _buildKeypad() {
    return Container(
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
          const SizedBox(),
          _buildKey("0"),
          _buildActionKey(Icons.backspace, onTap: _handleBackspace),
        ],
      ),
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
          child: Center(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey(IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Center(
        child: Icon(icon, color: Colors.white38, size: 28),
      ),
    );
  }
}
