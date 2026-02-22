import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../services/database_service.dart';
import '../services/logger.dart';

class SettingsModal extends StatefulWidget {
  final VoidCallback onThemeChanged; // Trigger app rebuild for font/theme

  const SettingsModal({super.key, required this.onThemeChanged});

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  final TextEditingController _systemPromptController = TextEditingController();
  double _temperature = 0.7;
  bool _isDarkMode = true;
  double _fontSize = 14.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await DatabaseService().getSettings();
    setState(() {
      _systemPromptController.text = settings['systemPrompt'] ?? '';
      _temperature = (settings['temperature'] as num).toDouble();
      _isDarkMode = settings['isDarkMode'] ?? true;
      _fontSize = (settings['fontSize'] as num).toDouble();
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    await DatabaseService().saveSettings({
      'systemPrompt': _systemPromptController.text,
      'temperature': _temperature,
      'isDarkMode': _isDarkMode,
      'fontSize': _fontSize,
    });
    widget.onThemeChanged();
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1c1c1e),
        title: Text("Clear All History?", style: GoogleFonts.inter(color: Colors.white)),
        content: Text("This action cannot be undone.", style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService().clearAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("History cleared. App will restart.")),
        );
        // In a real app we might restart or clear state, for now notify parent?
        // Actually DatabaseService.clearAllData nukes sessions, so next load will be empty.
        widget.onThemeChanged(); // This will trigger a reload in App
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: const Color(0xFF1c1c1e),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildSectionHeader("🧠 AI Brain"),
                      _buildSystemPrompt(),
                      const SizedBox(height: 20),
                      _buildTemperatureSlider(),
                      const Divider(color: Colors.white12, height: 40),
                      
                      _buildSectionHeader("🎨 Appearance"),
                      _buildFontSizeSlider(),
                      const SizedBox(height: 20),
                      _buildThemeToggle(),
                      const Divider(color: Colors.white12, height: 40),
                      
                      _buildSectionHeader("🔒 Data & Privacy"),
                      _buildClearHistoryButton(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Settings", style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.inter(color: const Color(0xFF468F82), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1), // Teal
      ),
    );
  }

  Widget _buildSystemPrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("System Prompt", style: GoogleFonts.inter(color: Colors.white, fontSize: 15)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: TextField(
            controller: _systemPromptController,
            maxLines: 4,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: "Define how the AI should behave...",
              hintStyle: TextStyle(color: Colors.white24),
            ),
            onChanged: (_) => _saveSettings(),
          ),
        ),
      ],
    );
  }

  Widget _buildTemperatureSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Creativity (Temperature)", style: GoogleFonts.inter(color: Colors.white, fontSize: 15)),
            Text(_temperature.toStringAsFixed(1), style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
          ],
        ),
        Slider(
          value: _temperature,
          min: 0.0,
          max: 1.0,
          activeColor: const Color(0xFF468F82), // Teal
          inactiveColor: Colors.white10,
          onChanged: (val) {
            setState(() => _temperature = val);
            _saveSettings();
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Precise", style: GoogleFonts.inter(color: Colors.white24, fontSize: 10)),
              Text("Creative", style: GoogleFonts.inter(color: Colors.white24, fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFontSizeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Font Size", style: GoogleFonts.inter(color: Colors.white, fontSize: 15)),
            Text("${_fontSize.toInt()}px", style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
          ],
        ),
        Slider(
          value: _fontSize,
          min: 12.0,
          max: 24.0,
          divisions: 6,
          activeColor: const Color(0xFFBAC7B2), // Sage Green
          inactiveColor: Colors.white10,
          onChanged: (val) {
            setState(() => _fontSize = val);
            _saveSettings();
          },
        ),
      ],
    );
  }

  Widget _buildThemeToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Aurora Background", style: GoogleFonts.inter(color: Colors.white, fontSize: 15)),
        Switch(
          value: _isDarkMode, // We misuse isDarkMode as "Show Aurora" for now
          activeColor: const Color(0xFF468F82), // Teal
          onChanged: (val) {
            setState(() => _isDarkMode = val);
            _saveSettings();
          },
        ),
      ],
    );
  }

  Widget _buildClearHistoryButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.withOpacity(0.1),
          foregroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: Colors.red.withOpacity(0.3)),
        ),
        onPressed: _clearHistory,
        child: Text("Clear All Chat History", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
