import 'package:flutter/material.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/utils/MyStyles.dart';


class _FeeInstallment {
  final String label;
  final double amount;
  final String dueDate;
  final bool isPaid;
  final String? paidDate;

  const _FeeInstallment({
    required this.label,
    required this.amount,
    required this.dueDate,
    required this.isPaid,
    this.paidDate,
  });
}

const _kTotalFee = 24000.0;
const _kPaidFee = 16000.0;

const _kInstallments = [
  _FeeInstallment(
    label: 'Term 1 Fee',
    amount: 8000,
    dueDate: '10 Apr 2026',
    isPaid: true,
    paidDate: '08 Apr 2026',
  ),
  _FeeInstallment(
    label: 'Term 2 Fee',
    amount: 8000,
    dueDate: '10 Jul 2026',
    isPaid: true,
    paidDate: '09 Jul 2026',
  ),
  _FeeInstallment(
    label: 'Term 3 Fee',
    amount: 8000,
    dueDate: '10 Oct 2026',
    isPaid: false,
  ),
];


class FeeStatusScreen extends StatelessWidget {
  const FeeStatusScreen({super.key});

  double get _pendingFee => _kTotalFee - _kPaidFee;
  double get _progress => _kPaidFee / _kTotalFee;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.appBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppTheme.black_Color,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Fee Status',
            style: MyStyles.boldTxt(AppTheme.black_Color, 17)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 20),

            _buildProgressCard(),
            const SizedBox(height: 20),

            Text('Payment Schedule',
                style: MyStyles.boldTxt(AppTheme.black_Color, 15)),
            const SizedBox(height: 12),
            ..._kInstallments.map((i) => _InstallmentCard(item: i)),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'For fee payment or queries, please contact the school office.',
                      style: MyStyles.regularTxt(
                          Colors.orange.shade800, 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.btnColor, const Color(0xFF0077B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.btnColor.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aarav Sharma',
                      style: MyStyles.boldTxt(Colors.white, 15)),
                  Text('Class 5A  •  Green Valley School',
                      style: MyStyles.regularTxt(
                          Colors.white.withOpacity(0.8), 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _feeBox('Total Fee', '₹${_kTotalFee.toInt()}'),
              _divider(),
              _feeBox('Paid', '₹${_kPaidFee.toInt()}',
                  valueColor: const Color(0xFF69F0AE)),
              _divider(),
              _feeBox('Pending', '₹${_pendingFee.toInt()}',
                  valueColor: const Color(0xFFFF8A80)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feeBox(String label, String value, {Color? valueColor}) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: MyStyles.boldTxt(valueColor ?? Colors.white, 18)),
          const SizedBox(height: 2),
          Text(label,
              style: MyStyles.regularTxt(
                  Colors.white.withOpacity(0.75), 11)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withOpacity(0.25),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payment Progress',
                  style: MyStyles.boldTxt(AppTheme.black_Color, 14)),
              Text('${(_progress * 100).toInt()}% Paid',
                  style: MyStyles.semiBoldTxt(AppTheme.btnColor, 13)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppTheme.btnColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _progressLegend(
                  '₹${_kPaidFee.toInt()} Paid', Colors.green),
              _progressLegend(
                  '₹${_pendingFee.toInt()} Remaining', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressLegend(String label, Color color) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: MyStyles.regularTxt(AppTheme.graySubTitleColor, 11)),
      ],
    );
  }
}


class _InstallmentCard extends StatelessWidget {
  final _FeeInstallment item;
  const _InstallmentCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isPaid
              ? Colors.green.shade200
              : Colors.orange.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 6),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 72,
              color: item.isPaid ? Colors.green : Colors.orange,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: item.isPaid
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.isPaid
                            ? Icons.check_circle_rounded
                            : Icons.pending_rounded,
                        color: item.isPaid ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label,
                              style: MyStyles.boldTxt(
                                  AppTheme.black_Color, 13)),
                          const SizedBox(height: 3),
                          Text(
                            item.isPaid
                                ? 'Paid on ${item.paidDate}'
                                : 'Due: ${item.dueDate}',
                            style: MyStyles.regularTxt(
                                AppTheme.graySubTitleColor, 11),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${item.amount.toInt()}',
                          style: MyStyles.boldTxt(
                              AppTheme.black_Color, 15),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.isPaid
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.isPaid ? 'Paid' : 'Pending',
                            style: MyStyles.mediumTxt(
                                item.isPaid
                                    ? Colors.green
                                    : Colors.orange,
                                10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
