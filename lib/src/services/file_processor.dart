import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class FileProcessor {
  static final FileProcessor _instance = FileProcessor._internal();

  factory FileProcessor() {
    return _instance;
  }

  FileProcessor._internal();

  Future<String> processFile(String filePath, String fileType) async {
    try {
      if (fileType == 'image') {
        // OCR skipped as requested. VLM will handle images directly in the prompt.
        return "[Image Attached: ${filePath.split('\\').last}]";
      } else if (fileType == 'document') {
        return await _extractPdfText(filePath);
      }
    } catch (e) {
      return "[Error processing file: $e]";
    }
    return '';
  }

  Future<String> _extractPdfText(String path) async {
    final file = File(path);
    if (!await file.exists()) return "File not found";

    try {
      // Create a new PDF document.
      final PdfDocument document = PdfDocument(inputBytes: await file.readAsBytes());
      
      // Extract the text from all the pages.
      String text = PdfTextExtractor(document).extractText();

      // Dispose the document.
      document.dispose();
      
      // Safety Truncation for LLM Context (approx 25k chars ~ 6-8k tokens)
      if (text.length > 25000) {
        text = "${text.substring(0, 25000)}\n\n[TRUNCATED DUE TO LENGTH - FIRST 25,000 CHARACTERS SHOWN]";
      }
      
      return "[DOCUMENT START: ${path.split('\\').last}]\n$text\n[DOCUMENT END]";
    } catch (e) {
      return "Failed to extract PDF text: $e";
    }
  }
}
