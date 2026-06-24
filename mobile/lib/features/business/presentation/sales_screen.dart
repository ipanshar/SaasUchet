part of 'business_shell.dart';

class _SalesScreen extends StatelessWidget {
  const _SalesScreen({
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
      documentType: 'sale_issue',
      title: 'Продажи',
      accentColor: const Color(0xFF16A34A),
      counterpartyLabel: 'Клиент',
      products: products,
      clients: clients,
      canWrite: canWrite,
    );
  }
}
