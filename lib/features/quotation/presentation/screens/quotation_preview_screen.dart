import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:mda_crm/features/quotation/presentation/quotation_pdf_data.dart';

class QuotationPreviewScreen extends StatefulWidget {
  final QuotationPdfData data;

  const QuotationPreviewScreen({super.key, required this.data});

  @override
  State<QuotationPreviewScreen> createState() => _QuotationPreviewScreenState();
}

class _QuotationPreviewScreenState extends State<QuotationPreviewScreen> {
  late final Future<Uint8List> _pdfFuture;

  @override
  void initState() {
    super.initState();
    _pdfFuture = _buildPdf(widget.data);
  }

  // ── number helpers ────────────────────────────────────────────────────────────

  static String _fmt(double n) {
    final str = n.toStringAsFixed(2);
    final parts = str.split('.');
    var whole = parts[0];
    final dec = parts[1];
    if (whole.length <= 3) return '$whole.$dec';
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    var grps = '';
    while (rest.length > 2) {
      grps = ',${rest.substring(rest.length - 2)}$grps';
      rest = rest.substring(0, rest.length - 2);
    }
    return '$rest$grps,$last3.$dec';
  }

  static const _wOnes = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];
  static const _wTens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

  static String _n2w(int n) {
    if (n == 0) return '';
    if (n < 20) return _wOnes[n];
    if (n < 100) { final o = _wOnes[n % 10]; return o.isEmpty ? _wTens[n ~/ 10] : '${_wTens[n ~/ 10]} $o'; }
    if (n < 1000)     { final r = _n2w(n % 100);    return '${_wOnes[n ~/ 100]} Hundred${r.isEmpty ? '' : ' $r'}'; }
    if (n < 100000)   { final r = _n2w(n % 1000);   return '${_n2w(n ~/ 1000)} Thousand${r.isEmpty ? '' : ' $r'}'; }
    if (n < 10000000) { final r = _n2w(n % 100000); return '${_n2w(n ~/ 100000)} Lakh${r.isEmpty ? '' : ' $r'}'; }
    final r = _n2w(n % 10000000);
    return '${_n2w(n ~/ 10000000)} Crore${r.isEmpty ? '' : ' $r'}';
  }

  static String _amtWords(double amount) {
    final whole = amount.truncate();
    final paise = ((amount - whole) * 100).round();
    var w = _n2w(whole);
    if (w.isEmpty) w = 'Zero';
    w += ' Rupees';
    if (paise > 0) w += ' and ${_n2w(paise)} Paise';
    return w;
  }

  static String _stripHtml(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  // ── PDF builder ───────────────────────────────────────────────────────────────

  static Future<Uint8List> _buildPdf(QuotationPdfData d) async {
    final doc = pw.Document();

    pw.ImageProvider? logo;
    pw.ImageProvider? sign;
    if (d.logoBytes != null) logo = pw.MemoryImage(d.logoBytes!);
    if (d.signBytes != null) sign = pw.MemoryImage(d.signBytes!);

    final hasDisc = d.rows.any((r) => r.discount != '0.00' && r.discount != '0.00%');

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(34),
      build: (ctx) => [
        _header(d, logo),
        pw.SizedBox(height: 14),
        _infoBar(d),
        pw.SizedBox(height: 12),
        _billTo(d),
        pw.SizedBox(height: 10),
        _itemsTable(d, hasDisc),
        pw.SizedBox(height: 14),
        _totals(d),
        pw.SizedBox(height: 10),
        _termsAndTotal(d),
        pw.SizedBox(height: 18),
        _bankAndSign(d, sign),
      ],
    ));

    return doc.save();
  }

  static pw.Widget _header(QuotationPdfData d, pw.ImageProvider? logo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 64,
          height: 64,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            border: pw.Border.all(width: 1.5),
            color: PdfColors.white,
          ),
          child: logo != null
              ? pw.Image(logo, fit: pw.BoxFit.contain)
              : pw.Center(
                  child: pw.Text(
                    d.companyName.isNotEmpty ? d.companyName[0].toUpperCase() : 'Q',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(child: _headerText(d)),
      ],
    );
  }

  static pw.Widget _headerText(QuotationPdfData d) {
    final stripped = _stripHtml(d.headerHtml);
    if (stripped.isEmpty) {
      return pw.Text(
        d.companyName.toUpperCase(),
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      );
    }
    final lines = stripped.split('\n').where((l) => l.trim().isNotEmpty).take(6).toList();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++)
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: i == 0 ? 3 : 1),
            child: pw.Text(
              lines[i].trim(),
              style: pw.TextStyle(
                fontSize: i == 0 ? 16 : 8,
                fontWeight: i == 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }

  static pw.Widget _infoBar(QuotationPdfData d) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border(
          top: pw.BorderSide(width: 1.5),
          bottom: pw.BorderSide(width: 1.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          if (d.showQuotationNo)
            pw.RichText(
              text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Quotation No.: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.TextSpan(text: d.quotationNo, style: const pw.TextStyle(fontSize: 9)),
              ]),
            )
          else
            pw.SizedBox(),
          pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: 'Quotation Date: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.TextSpan(text: d.date, style: const pw.TextStyle(fontSize: 9)),
            ]),
          ),
          pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: 'Expiry Date: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.TextSpan(text: d.expiryDate, style: const pw.TextStyle(fontSize: 9)),
            ]),
          ),
        ],
      ),
    );
  }

  static pw.Widget _billTo(QuotationPdfData d) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('BILL TO', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(d.customerName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text('Place of Supply: ${d.placeOfSupply}', style: const pw.TextStyle(fontSize: 8)),
        if (d.customerPhone.isNotEmpty)
          pw.Text('Contact Number: ${d.customerPhone}', style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  static pw.Widget _itemsTable(QuotationPdfData d, bool hasDisc) {
    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(),
      1: const pw.FixedColumnWidth(58),
      2: const pw.FixedColumnWidth(58),
    };
    if (hasDisc) {
      colWidths[3] = const pw.FixedColumnWidth(60);
      colWidths[4] = const pw.FixedColumnWidth(68);
    } else {
      colWidths[3] = const pw.FixedColumnWidth(68);
    }

    pw.Widget th(String t, {pw.Alignment align = pw.Alignment.centerLeft}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      child: pw.Align(alignment: align, child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
    );

    pw.Widget td(String t) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(t, style: const pw.TextStyle(fontSize: 8))),
    );

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(width: 1.5), bottom: pw.BorderSide(width: 1.5)),
      ),
      children: [
        th('ITEMS'),
        th('QTY.', align: pw.Alignment.centerRight),
        th('RATE', align: pw.Alignment.centerRight),
        if (hasDisc) th('DISCOUNT', align: pw.Alignment.centerRight),
        th('AMOUNT', align: pw.Alignment.centerRight),
      ],
    );

    final dataRows = d.rows.map((r) {
      final showDisc = r.discount != '0.00' && r.discount != '0.00%';
      return pw.TableRow(
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
        ),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(r.name.toUpperCase(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                if (r.description.isNotEmpty)
                  pw.Text(r.description, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
              ],
            ),
          ),
          td('${_fmt(r.qty)} ${r.unit}'),
          td(_fmt(r.rate)),
          if (hasDisc) td(showDisc ? r.discount : ''),
          td(_fmt(r.amount)),
        ],
      );
    }).toList();

    return pw.Table(columnWidths: colWidths, children: [headerRow, ...dataRows]);
  }

  static pw.Widget _totals(QuotationPdfData d) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 220,
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 1.5)),
          ),
          child: pw.Column(
            children: [
              if (d.overallDiscAmt > 0) ...[
                _totRow('NET TOTAL', _fmt(d.netTotal), bold: true),
                _totRow('Discount', _fmt(d.overallDiscAmt)),
              ],
              _totRow('SUB TOTAL', _fmt(d.subTotal), bold: true),
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 2),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                ),
                child: pw.Column(children: _gstRows(d.gstFigure)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static List<pw.Widget> _gstRows(String gstFigure) {
    if (gstFigure.contains('^')) {
      final gp = gstFigure.split('^');
      if (gp.length == 6) {
        return [
          _totRow('${gp[0]} (${gp[2]}%)', _fmt(double.tryParse(gp[1]) ?? 0)),
          _totRow('${gp[3]} (${gp[5]}%)', _fmt(double.tryParse(gp[4]) ?? 0)),
        ];
      } else if (gp.length == 3) {
        return [_totRow('${gp[0]} (${gp[2]}%)', '₹ ${_fmt(double.tryParse(gp[1]) ?? 0)}')];
      }
    } else if (gstFigure == 'IncGst') {
      return [pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: pw.Text('All prices are inclusive of taxes.', style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic)),
      )];
    } else {
      return [pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: pw.Text('GST will be charged extra as applicable.', style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic)),
      )];
    }
    return [];
  }

  static pw.Widget _totRow(String label, String value, {bool bold = false}) {
    final style = bold
        ? pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)
        : const pw.TextStyle(fontSize: 8);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label, style: style), pw.Text(value, style: style)],
      ),
    );
  }

  static pw.Widget _termsAndTotal(QuotationPdfData d) {
    const defaultTerms = 'TERMS AND CONDITIONS\n'
        '1. Goods once sold will not be taken back or exchange\n'
        '2. Price validity 15 days from quotation.\n'
        '3. Delivery time 15 days\n'
        '4. Local freight extra.\n'
        '5. Gst extra as applicable.';

    final termsText = _stripHtml(d.termsHtml.isNotEmpty ? d.termsHtml : defaultTerms);
    final termsLines = termsText.split('\n').where((l) => l.trim().isNotEmpty).toList();

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 50,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: termsLines.map((l) => pw.Text(l.trim(), style: const pw.TextStyle(fontSize: 8))).toList(),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          flex: 47,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 5),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(width: 1.5), bottom: pw.BorderSide(width: 1.5)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Amount', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs. ${_fmt(d.totalAmt)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Total Amount (in words)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      _amtWords(d.totalAmt),
                      style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
                      textAlign: pw.TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _bankAndSign(QuotationPdfData d, pw.ImageProvider? sign) {
    final bankText = _stripHtml(d.bankHtml);
    final bankLines = bankText.split('\n').where((l) => l.trim().isNotEmpty).toList();

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 60,
          child: bankLines.isNotEmpty
              ? pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: bankLines.map((l) => pw.Text(l.trim(), style: const pw.TextStyle(fontSize: 8))).toList(),
                )
              : pw.SizedBox(),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          flex: 35,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(height: 40),
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 5),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(width: 0.8)),
                ),
                child: pw.Column(
                  children: [
                    if (sign != null) ...[
                      pw.Image(sign, height: 40, fit: pw.BoxFit.contain),
                      pw.SizedBox(height: 4),
                    ],
                    pw.Text(
                      'Authorised Signatory For',
                      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Text(
                      d.companyName.toUpperCase(),
                      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Flutter widget ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quotation No. ${widget.data.quotationNo}'),
        backgroundColor: const Color(0xFF0257E6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<Uint8List>(
        future: _pdfFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating PDF…'),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          }
          return PdfPreview(
            build: (_) async => snapshot.data!,
            canChangePageFormat: false,
            canDebug: false,
            pdfFileName: 'Quotation_${widget.data.quotationNo}.pdf',
            allowSharing: true,
            allowPrinting: true,
            initialPageFormat: PdfPageFormat.a4,
          );
        },
      ),
    );
  }
}
