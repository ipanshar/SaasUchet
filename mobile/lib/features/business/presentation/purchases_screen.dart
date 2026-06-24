part of 'business_shell.dart';

class _PurchasesScreen extends StatelessWidget {
  const _PurchasesScreen({
    required this.accessToken,
    required this.businessGateway,
    required this.companyId,
    required this.products,
    required this.clients,
    this.canWrite = true,
  });

  final String accessToken;
  final BusinessGateway businessGateway;
  final String companyId;
  final List<_Product> products;
  final List<_Client> clients;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    return _DocumentsListScreen(
      accessToken: accessToken,
      businessGateway: businessGateway,
      companyId: companyId,
      documentType: 'purchase_receipt',
      title: 'Закупки',
      accentColor: const Color(0xFF2563EB),
      counterpartyLabel: 'Поставщик',
      products: products,
      clients: clients,
      canWrite: canWrite,
    );
  }
}
