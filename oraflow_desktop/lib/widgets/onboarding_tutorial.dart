import 'dart:async';
import 'package:flutter/material.dart';

class OnboardingTutorial extends StatefulWidget {
  final VoidCallback onTutorialComplete;

  const OnboardingTutorial({
    Key? key,
    required this.onTutorialComplete,
  }) : super(key: key);

  @override
  State<OnboardingTutorial> createState() => _OnboardingTutorialState();
}

class _OnboardingTutorialState extends State<OnboardingTutorial> {
  int _currentStep = 0;
  bool _isAnimating = false;
  bool _isCompleted = false;

  final List<TutorialStep> _tutorialSteps = [
    TutorialStep(
      title: 'Welcome to OraFlow!',
      content: 'Your intelligent Flutter development assistant. Let\'s get you started with the basics.',
      image: 'assets/images/tutorial_welcome.png',
      buttonText: 'Next',
    ),
    TutorialStep(
      title: 'Project Setup',
      content: 'First, select your Flutter project using the "Select Project" button. This tells OraFlow which codebase to monitor and analyze.',
      image: 'assets/images/tutorial_project.png',
      buttonText: 'Next',
    ),
    TutorialStep(
      title: 'Start Monitoring',
      content: 'Click "Start Monitoring" to begin tracking your code for errors, performance issues, and optimization opportunities.',
      image: 'assets/images/tutorial_monitoring.png',
      buttonText: 'Next',
    ),
    TutorialStep(
      title: 'Error Detection & AI Fixes',
      content: 'When errors occur, OraFlow will automatically detect them and consult our AI to generate fixes. You\'ll see error badges and can preview fixes before applying them.',
      image: 'assets/images/tutorial_errors.png',
      buttonText: 'Next',
    ),
    TutorialStep(
      title: 'Knowledge Graph',
      content: 'Explore your project\'s structure using the Knowledge Graph. Click the scatter plot icon to see file relationships and identify potential issues.',
      image: 'assets/images/tutorial_graph.png',
      buttonText: 'Next',
    ),
    TutorialStep(
      title: 'Interactive Terminal',
      content: 'Use the built-in terminal for advanced commands. Type "help" to see available commands for monitoring, debugging, and optimization.',
      image: 'assets/images/tutorial_terminal.png',
      buttonText: 'Next',
    ),
    TutorialStep(
      title: 'Resource Management',
      content: 'OraFlow automatically manages system resources to prevent conflicts. The Resource Guard ensures optimal performance during development.',
      image: 'assets/images/tutorial_resources.png',
      buttonText: 'Next',
    ),
    TutorialStep(
      title: 'You\'re Ready!',
      content: 'OraFlow is now monitoring your project. As you code, it will help catch errors early, suggest optimizations, and provide intelligent assistance.',
      image: 'assets/images/tutorial_complete.png',
      buttonText: 'Start Coding',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Auto-advance through tutorial steps for demo purposes
    _startAutoAdvance();
  }

  void _startAutoAdvance() {
    Timer.periodic(const Duration(seconds: 8), (timer) {
      if (_currentStep < _tutorialSteps.length - 1 && !_isAnimating) {
        _nextStep();
      } else {
        timer.cancel();
        _completeTutorial();
      }
    });
  }

  void _nextStep() {
    setState(() {
      _isAnimating = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _currentStep++;
        _isAnimating = false;
      });
    });
  }

  void _previousStep() {
    if (_currentStep > 0 && !_isAnimating) {
      setState(() {
        _isAnimating = true;
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        setState(() {
          _currentStep--;
          _isAnimating = false;
        });
      });
    }
  }

  void _skipTutorial() {
    setState(() {
      _isCompleted = true;
    });
    widget.onTutorialComplete();
  }

  void _completeTutorial() {
    setState(() {
      _isCompleted = true;
    });
    widget.onTutorialComplete();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCompleted) {
      return const SizedBox.shrink();
    }

    final currentStep = _tutorialSteps[_currentStep];
    final isLastStep = _currentStep == _tutorialSteps.length - 1;
    final isFirstStep = _currentStep == 0;

    return Container(
      color: Colors.black54,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          width: _isAnimating ? 0 : MediaQuery.of(context).size.width * 0.8,
          height: _isAnimating ? 0 : MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: const Color(0xFF0B0E14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00F5FF).withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00F5FF).withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Close button
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  onPressed: _skipTutorial,
                  icon: const Icon(Icons.close, color: Colors.white54),
                  tooltip: 'Skip tutorial',
                ),
              ),

              // Content area
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Progress indicator
                    Row(
                      children: [
                        Text(
                          'Step ${_currentStep + 1} of ${_tutorialSteps.length}',
                          style: const TextStyle(
                            color: Color(0xFF00F5FF),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // Progress dots
                        Row(
                          children: List.generate(_tutorialSteps.length, (index) {
                            return Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: index == _currentStep 
                                    ? const Color(0xFF00F5FF) 
                                    : Colors.white38,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Image placeholder
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1a1d23),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00F5FF).withOpacity(0.3)),
                      ),
                      child: Center(
                        child: Text(
                          currentStep.image.split('/').last,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      currentStep.title,
                      style: const TextStyle(
                        color: Color(0xFF00F5FF),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Content
                    Text(
                      currentStep.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const Spacer(),

                    // Navigation buttons
                    Row(
                      children: [
                        if (!isFirstStep)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _previousStep,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF00F5FF)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                'Previous',
                                style: TextStyle(
                                  color: Color(0xFF00F5FF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        
                        const SizedBox(width: 16),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLastStep ? _completeTutorial : _nextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00F5FF),
                              foregroundColor: const Color(0xFF0B0E14),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              currentStep.buttonText,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Skip link
                    if (!isLastStep)
                      TextButton(
                        onPressed: _skipTutorial,
                        child: const Text(
                          'Skip Tutorial',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TutorialStep {
  final String title;
  final String content;
  final String image;
  final String buttonText;

  TutorialStep({
    required this.title,
    required this.content,
    required this.image,
    required this.buttonText,
  });
}

class HelpSystem extends StatelessWidget {
  const HelpSystem({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1a1d23),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF15181E),
              border: Border(
                bottom: BorderSide(color: const Color(0xFF00F5FF).withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.help_outline, size: 20, color: Color(0xFF00F5FF)),
                const SizedBox(width: 8),
                const Text(
                  'Help & Support',
                  style: TextStyle(
                    color: Color(0xFF00F5FF),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    // Close help
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close, color: Colors.white54),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Help content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Quick Start Section
                _buildHelpSection(
                  context,
                  'Quick Start',
                  [
                    '1. Select your Flutter project using "Select Project"',
                    '2. Click "Start Monitoring" to begin tracking',
                    '3. Code as usual - OraFlow will monitor automatically',
                    '4. Review error notifications and AI suggestions',
                    '5. Use the Knowledge Graph to explore your codebase',
                  ],
                ),

                const SizedBox(height: 16),

                // Commands Section
                _buildHelpSection(
                  context,
                  'Terminal Commands',
                  [
                    'help - Show available commands',
                    'status - Display system status',
                    'monitor - Toggle monitoring on/off',
                    'reload - Trigger hot reload',
                    'restart - Trigger full restart',
                    'project - Show project information',
                    'history - View command history',
                    'optimize - Optimize performance',
                  ],
                ),

                const SizedBox(height: 16),

                // Troubleshooting Section
                _buildHelpSection(
                  context,
                  'Troubleshooting',
                  [
                    'No errors detected? Ensure monitoring is active',
                    'AI fixes not appearing? Check internet connection',
                    'High resource usage? Try the optimize command',
                    'VS Code integration issues? Restart both applications',
                    'Still having issues? Check the logs in the terminal',
                  ],
                ),

                const SizedBox(height: 16),

                // Tips Section
                _buildHelpSection(
                  context,
                  'Pro Tips',
                  [
                    'Use the Knowledge Graph to understand code relationships',
                    'Check the Status Bar for real-time system information',
                    'Review the Activity Log for detailed event history',
                    'Use the File Inspector for detailed code analysis',
                    'Enable debug mode for detailed error tracking',
                  ],
                ),

                const SizedBox(height: 16),

                // Support Section
                Card(
                  color: const Color(0xFF11141A),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Need More Help?',
                          style: TextStyle(
                            color: Color(0xFF00F5FF),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Visit our documentation or contact support:',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  // Open documentation
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Documentation would open here')),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF00F5FF)),
                                ),
                                child: const Text(
                                  'Documentation',
                                  style: TextStyle(color: Color(0xFF00F5FF)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  // Contact support
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Support contact would open here')),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF00F5FF)),
                                ),
                                child: const Text(
                                  'Contact Support',
                                  style: TextStyle(color: Color(0xFF00F5FF)),
                                ),
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
        ],
      ),
    );
  }

  Widget _buildHelpSection(BuildContext context, String title, List<String> items) {
    return Card(
      color: const Color(0xFF11141A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF00F5FF),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 6, right: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00F5FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class ContextualHelp extends StatelessWidget {
  final String context;
  final VoidCallback onDismiss;

  const ContextualHelp({
    Key? key,
    required this.context,
    required this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1d23),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00F5FF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: Color(0xFF00F5FF)),
              const SizedBox(width: 8),
              Text(
                'Tip: $context',
                style: const TextStyle(
                  color: Color(0xFF00F5FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 16, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getHelpText(context),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _getHelpText(String context) {
    switch (context) {
      case 'monitoring':
        return 'Monitoring is active. OraFlow will automatically detect errors and suggest fixes as you code.';
      case 'errors':
        return 'Click on error badges to see detailed information and preview AI-generated fixes.';
      case 'knowledge_graph':
        return 'Use the Knowledge Graph to visualize your project structure and identify potential issues.';
      case 'terminal':
        return 'Type "help" in the terminal for a list of available commands and their usage.';
      case 'resources':
        return 'Resource Guard is monitoring system performance. Use "optimize" command if performance is slow.';
      default:
        return 'Need more help? Click the help icon in the top navigation for detailed guides and support.';
    }
  }
}
