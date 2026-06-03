import '../../../../core/network/date_converters.dart';
import 'research_report_source.dart';

/// A research report ingested from one of the broker sources
/// (Samuel, Mandiri, Kiwoom, RK, Revalue).
class ResearchReport {
  final String id;
  final ResearchReportSource? source;
  final String title;
  final DateTime date;
  final String author;
  final List<String> tickers;
  final String markdownBody;
  final String? pdfUrl;

  const ResearchReport({
    required this.id,
    required this.source,
    required this.title,
    required this.date,
    required this.author,
    required this.tickers,
    required this.markdownBody,
    this.pdfUrl,
  });

  factory ResearchReport.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] ?? json['published_at'] ?? json['created_at'];
    DateTime parsedDate;
    if (rawDate is String) {
      parsedDate = const FlexibleDateTimeConverter().fromJson(rawDate) ??
          DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    final rawTickers = json['tickers'] ?? json['symbols'];
    final tickers = <String>[];
    if (rawTickers is List) {
      for (final t in rawTickers) {
        if (t != null) tickers.add(t.toString());
      }
    } else if (rawTickers is String && rawTickers.isNotEmpty) {
      tickers.addAll(rawTickers.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty));
    }

    final rawPdf = json['pdf_url'] ?? json['pdfUrl'] ?? json['pdf'];
    String? pdf;
    if (rawPdf is String && rawPdf.isNotEmpty) pdf = rawPdf;

    return ResearchReport(
      id: json['id']?.toString() ?? '',
      source: ResearchReportSource.tryParse(json['source']?.toString()),
      title: json['title']?.toString() ?? '',
      date: parsedDate,
      author: json['author']?.toString() ?? '',
      tickers: tickers,
      markdownBody: json['markdown_body']?.toString() ??
          json['body']?.toString() ??
          json['markdown']?.toString() ??
          json['content']?.toString() ??
          '',
      pdfUrl: pdf,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source?.apiValue,
        'title': title,
        'date': const FlexibleDateTimeConverter().toJson(date),
        'author': author,
        'tickers': tickers,
        'markdown_body': markdownBody,
        'pdf_url': pdfUrl,
      };
}
