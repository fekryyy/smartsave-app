import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/models/transaction_model.dart';
import '../data/models/goal_model.dart';

class ExportService {
  Future<String> exportToCSV(List<TransactionModel> transactions) async {
    final headers = ['Type', 'Amount', 'Category', 'Description', 'Date', 'Payment Method'];
    final rows = transactions.map((t) => [t.type, t.amount.toString(), t.category, t.description, t.date.toIso8601String(), t.paymentMethod]).toList();

    final csvData = [headers, ...rows];
    final csv = const ListToCsvConverter().convert(csvData);

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/smartsave_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);

    return file.path;
  }

  Future<void> shareFile(String filePath) async {
    await Share.shareXFiles([XFile(filePath)], text: 'SmartSave Export');
  }

  Future<String> exportGoalsToCSV(List<GoalModel> goals) async {
    final headers = ['Title', 'Target Amount', 'Current Amount', 'Progress', 'Status', 'Target Date'];
    final rows = goals.map((g) => [g.title, g.targetAmount.toString(), g.currentAmount.toString(), '${g.progress.toStringAsFixed(0)}%', g.status, g.targetDate?.toIso8601String() ?? '']).toList();

    final csvData = [headers, ...rows];
    final csv = const ListToCsvConverter().convert(csvData);

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/smartsave_goals_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);

    return file.path;
  }
}
