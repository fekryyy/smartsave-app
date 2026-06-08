import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';

class DownloadService {
  final ApiClient _apiClient = ApiClient();

  Future<void> downloadAndShare(String endpoint, String filename) async {
    try {
      final bytes = await _apiClient.getBytes(endpoint);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'SmartSave Export');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> exportPDF({String period = 'monthly', String type = 'transactions'}) async {
    await downloadAndShare('${ApiConstants.exportPdf}?period=$period&type=$type', 'smartsave-$type-$period.pdf');
  }

  Future<void> exportCSV({String period = 'monthly', String type = 'transactions'}) async {
    await downloadAndShare('${ApiConstants.exportCsv}?period=$period&type=$type', 'smartsave-$type-$period.csv');
  }

  Future<void> exportExcel({String period = 'monthly'}) async {
    await downloadAndShare('${ApiConstants.exportExcel}?period=$period', 'smartsave-report-$period.xlsx');
  }
}
