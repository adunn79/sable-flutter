import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sable/core/theme/aureal_theme.dart';
import 'package:sable/core/identity/bond_engine.dart';
import 'package:sable/core/identity/emotional_state.dart';
import 'package:sable/core/ai/model_orchestrator.dart';

class DebugDashboard extends ConsumerStatefulWidget {
  const DebugDashboard({super.key});

  @override
  ConsumerState<DebugDashboard> createState() => _DebugDashboardState();
}

class _DebugDashboardState extends ConsumerState<DebugDashboard> {
  String _log = 'System Initialized...';

  void _logMessage(String message) {
    setState(() {
      _log = '$message\n\n$_log';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bondState = ref.watch(bondEngineProvider);
    final emotion = ref.watch(emotionalStateProvider);

    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      appBar: AppBar(
        title: const Text('AUREAL DEBUG CONSOLE'),
        backgroundColor: AurealColors.carbon,
      ),
      body: Row(
        children: [
          // Controls Panel
          Expanded(
            flex: 2,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('BOND ENGINE'),
                _buildStatusCard('Current Bond', bondState.name.toUpperCase(),
                    _getBondColor(bondState)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildActionButton('Trigger Respect Protocol', () {
                      ref
                          .read(bondEngineProvider.notifier)
                          .triggerRespectProtocol();
                      _logMessage('⚠️ Respect Protocol Triggered -> COOLED');
                    }),
                    _buildActionButton('Reset to Neutral', () {
                      ref.read(bondEngineProvider.notifier).resetToNeutral();
                      _logMessage('🔄 Reset to NEUTRAL');
                    }),
                    _buildActionButton('Restore Warmth', () {
                      ref.read(bondEngineProvider.notifier).restoreWarmth();
                      _logMessage('❤️ Warmth Restored -> WARM');
                    }),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('EMOTIONAL STATE'),
                _buildStatusCard(
                    'Current Emotion', emotion.name.toUpperCase(), Colors.blue),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: Emotion.values.map((e) {
                    return _buildActionButton(e.name.toUpperCase(), () {
                      ref.read(emotionalStateProvider.notifier).setEmotion(e);
                      _logMessage('🎭 Emotion set to ${e.name.toUpperCase()}');
                    });
                  }).toList(),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('MODEL ORCHESTRATOR'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildActionButton('Test Personality (Claude)', () async {
                      final response = await ref
                          .read(modelOrchestratorProvider.notifier)
                          .routeRequest(
                              prompt: 'Hello!',
                              taskType: AiTaskType.personality);
                      _logMessage(response);
                    }),
                    _buildActionButton('Test Agentic (Gemini)', () async {
                      final response = await ref
                          .read(modelOrchestratorProvider.notifier)
                          .routeRequest(
                              prompt: 'Check calendar',
                              taskType: AiTaskType.agentic);
                      _logMessage(response);
                    }),
                    _buildActionButton('Test Heavy Lifting (OpenAI)', () async {
                      final response = await ref
                          .read(modelOrchestratorProvider.notifier)
                          .routeRequest(
                              prompt: 'Analyze data',
                              taskType: AiTaskType.heavyLifting);
                      _logMessage(response);
                    }),
                  ],
                ),
              ],
            ),
          ),
          // Log Panel
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: AurealColors.hyperGold),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: AurealColors.hyperGold.withOpacity(0.2),
                    child: const Text(
                      'SYSTEM LOGS',
                      style: TextStyle(
                          color: AurealColors.hyperGold,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _log,
                        style: const TextStyle(
                            color: Colors.greenAccent, fontFamily: 'Courier'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
            color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AurealColors.carbon,
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          Text(value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AurealColors.carbon,
        foregroundColor: AurealColors.stardust,
        side: const BorderSide(color: Colors.grey),
      ),
      child: Text(label),
    );
  }

  Color _getBondColor(BondState state) {
    switch (state) {
      case BondState.warm:
        return Colors.orange;
      case BondState.neutral:
        return Colors.blue;
      case BondState.cooled:
        return Colors.cyan;
    }
  }
}
