import 'ai_assistant_tool.dart';
import 'compress_pdf_tool.dart';
import 'create_blank_pdf_tool.dart';
import 'esign_pdf_tool.dart';
import 'extract_text_tool.dart';
import 'images_to_pdf_tool.dart';
import 'merge_pdf_tool.dart';
import 'organize_pages_tool.dart';
import 'page_numbers_tool.dart';
import 'pdf_to_images_tool.dart';
import 'pdf_tool_model.dart';
import 'protect_pdf_tool.dart';
import 'split_pdf_tool.dart';
import 'unlock_pdf_tool.dart';
import 'watermark_tool.dart';

export 'pdf_tool_model.dart';

/// Master registry of all 14 standalone PDF tools, each isolated in its own file.
const List<PdfTool> registeredPdfTools = [
  CompressPdfTool(),
  MergePdfTool(),
  SplitPdfTool(),
  OrganizePagesTool(),
  ImagesToPdfTool(),
  PdfToImagesTool(),
  WatermarkTool(),
  PageNumbersTool(),
  ProtectPdfTool(),
  UnlockPdfTool(),
  EsignPdfTool(),
  AiAssistantTool(),
  CreateBlankPdfTool(),
  ExtractTextTool(),
];

/// Quick-access subset displayed on the Home Screen launchpad.
const List<PdfTool> popularPdfTools = [
  CompressPdfTool(),
  MergePdfTool(),
  SplitPdfTool(),
  ImagesToPdfTool(),
  WatermarkTool(),
  ProtectPdfTool(),
];
