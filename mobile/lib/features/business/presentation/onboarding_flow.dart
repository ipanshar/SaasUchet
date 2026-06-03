part of 'business_shell.dart';

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({
    super.key,
    required this.onComplete,
  });

  final VoidCallback onComplete;

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  int _currentIndex = 0;

  final List<_OnboardingSlide> _slides = const [
    _OnboardingSlide(
      icon: Icons.trending_up_rounded,
      title: 'Управляйте продажами',
      description:
          'Полный контроль над продажами, заказами и складом в одном приложении.',
      color: Color(0xFF00A86B),
    ),
    _OnboardingSlide(
      icon: Icons.groups_rounded,
      title: 'CRM и клиенты',
      description:
          'Управляйте клиентами, сделками и задачами. Увеличивайте продажи.',
      color: Color(0xFF3B82F6),
    ),
    _OnboardingSlide(
      icon: Icons.bar_chart_rounded,
      title: 'Аналитика в реальном времени',
      description:
          'Следите за показателями бизнеса и принимайте решения на основе данных.',
      color: Color(0xFF22C55E),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentIndex];
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF3FBF7),
              Color(0xFFF5FAFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: slide.color,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x2200A86B),
                              blurRadius: 28,
                              offset: Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Icon(
                          slide.icon,
                          size: 88,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        slide.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF102A23),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        slide.description,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF52606D),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _slides.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: index == _currentIndex ? 28 : 8,
                            decoration: BoxDecoration(
                              color: index == _currentIndex
                                  ? const Color(0xFF00A86B)
                                  : const Color(0xFFD9E2EC),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_currentIndex < _slides.length - 1) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentIndex += 1;
                        });
                      },
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Далее'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: widget.onComplete,
                      child: const Text('Пропустить'),
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.onComplete,
                      child: const Text('Начать работу'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
