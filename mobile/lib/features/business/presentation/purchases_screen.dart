part of 'business_shell.dart';

class _PurchasesScreen extends StatelessWidget {
  const _PurchasesScreen({
    required this.accessToken,
    required this.businessGateway,
    required this.products,
    required this.clients,
  });

  final String accessToken;
  final BusinessGateway businessGateway;
  final List<_Product> products;
  final List<_Client> clients;

  @override
  Widget build(BuildContext context) {
    return _DocumentsListScreen(
      accessToken: accessToken,
      businessGateway: businessGateway,
      documentType: 'purchase_receipt',
      title: 'Закупки',
      accentColor: const Color(0xFF2563EB),
      counterpartyLabel: 'Поставщик',
      products: products,
      clients: clients,
    );
  }
}
