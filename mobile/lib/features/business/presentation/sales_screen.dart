part of 'business_shell.dart';

class _SalesScreen extends StatelessWidget {
  const _SalesScreen({
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
      documentType: 'sale_issue',
      title: 'Продажи',
      accentColor: const Color(0xFF16A34A),
      counterpartyLabel: 'Клиент',
      products: products,
      clients: clients,
    );
  }
}
