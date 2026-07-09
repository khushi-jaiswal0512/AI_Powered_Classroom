import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HallOfFameScreen extends StatefulWidget {
  const HallOfFameScreen({super.key});

  @override
  State<HallOfFameScreen> createState() => _HallOfFameScreenState();
}

class _HallOfFameScreenState extends State<HallOfFameScreen> with SingleTickerProviderStateMixin {
  final List<Map<String, String>> prominentFigures = [
    // Scientists
    {"name": "K. Radhakrishnan", "role": "Scientist", "contribution": "Former ISRO Chairman, led Mangalyaan"},
    {"name": "Mylswamy Annadurai", "role": "Scientist", "contribution": "Moon Man of India, led Chandrayaan-1"},
    {"name": "C. V. Raman", "role": "Scientist", "contribution": "Nobel Laureate, discovered the Raman Effect"},
    {"name": "A. P. J. Abdul Kalam", "role": "Scientist", "contribution": "Missile Man of India, 11th President"},
    {"name": "Homi J. Bhabha", "role": "Scientist", "contribution": "Father of the Indian nuclear program"},
    {"name": "Vikram Sarabhai", "role": "Scientist", "contribution": "Father of the Indian space program"},
    // Mathematicians
    {"name": "Srinivasa Ramanujan", "role": "Mathematician", "contribution": "Infinite series and number theory genius"},
    {"name": "Aryabhata", "role": "Mathematician", "contribution": "Invented zero, authored Aryabhatiya"},
    {"name": "Brahmagupta", "role": "Mathematician", "contribution": "Rules for zero, Brahmaguptan identity"},
    // Litterateurs
    {"name": "Rabindranath Tagore", "role": "Litterateur", "contribution": "Nobel Laureate, composed Gitanjali"},
    {"name": "Munshi Premchand", "role": "Litterateur", "contribution": "Pioneer of modern Hindi literature"},
    {"name": "R. K. Narayan", "role": "Litterateur", "contribution": "Creator of the fictional town Malgudi"},
  ];

  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    // Auto scroll logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients) {
        // Continuous, smooth scroll
        _scrollController.animateTo(
          _scrollController.offset + 2.0, 
          duration: const Duration(milliseconds: 50),
          curve: Curves.linear,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Hall of Fame', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)], // Premium space theme
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SizedBox(
            height: 480,
            // Uses ListView.builder with an infinite count
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                // Critical Validation: Guaranteed modulo to map to EXACT dataset length
                // This ensures all 12 people render exactly once before repeating, skipping nobody.
                final realIndex = index % prominentFigures.length;
                final figure = prominentFigures[realIndex];

                return _buildCard(figure, realIndex)
                    .animate()
                    .fadeIn(duration: 800.ms, delay: (100 * realIndex).ms)
                    .slideY(begin: 0.1, end: 0, duration: 800.ms, curve: Curves.easeOutQuart);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, String> figure, int realIndex) {
    return Container(
      width: 320,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Image.asset(
                        'assets/images/${figure['name']}.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.person, size: 80, color: Colors.white38),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          figure['name']!,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          figure['role']!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4AC29A),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.0,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          figure['contribution']!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
     // Subtle floating motion vertically
     .moveY(begin: -6, end: 6, duration: 3.seconds, delay: (realIndex * 200).ms, curve: Curves.easeInOutSine);
  }
}
