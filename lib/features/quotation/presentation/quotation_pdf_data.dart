import 'dart:typed_data';

class QuotationPdfData {
  final String quotationNo;
  final String date;
  final String expiryDate;
  final String customerName;
  final String placeOfSupply;
  final String customerPhone;
  final String companyName;
  final Uint8List? logoBytes;
  final Uint8List? signBytes;
  final String headerHtml;
  final String termsHtml;
  final String bankHtml;
  final bool showQuotationNo;
  final List<QuotationRowData> rows;
  final double subTotal;
  final String gstFigure;
  final double netTotal;
  final double overallDiscAmt;
  final double totalAmt;

  const QuotationPdfData({
    required this.quotationNo,
    required this.date,
    required this.expiryDate,
    required this.customerName,
    required this.placeOfSupply,
    required this.customerPhone,
    required this.companyName,
    this.logoBytes,
    this.signBytes,
    required this.headerHtml,
    required this.termsHtml,
    required this.bankHtml,
    required this.showQuotationNo,
    required this.rows,
    required this.subTotal,
    required this.gstFigure,
    required this.netTotal,
    required this.overallDiscAmt,
    required this.totalAmt,
  });
}

class QuotationRowData {
  final String name;
  final String description;
  final double qty;
  final String unit;
  final double rate;
  final String discount;
  final double amount;

  const QuotationRowData({
    required this.name,
    required this.description,
    required this.qty,
    required this.unit,
    required this.rate,
    required this.discount,
    required this.amount,
  });
}
