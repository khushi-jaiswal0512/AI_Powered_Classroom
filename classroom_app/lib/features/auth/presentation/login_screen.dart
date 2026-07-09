import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:classroom_app/core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────
//  Formula data model
// ─────────────────────────────────────────────────────────────
class _Formula {
  final String text;
  final double x; 
  final double y; 
  final double angle; 
  final double opacity;
  final double fontSize;
  final bool blurred;

  const _Formula({
    required this.text,
    required this.x,
    required this.y,
    required this.angle,
    required this.opacity,
    required this.fontSize,
    this.blurred = false,
  });
}

// ─────────────────────────────────────────────────────────────
//  Pre-generated formula layout
// ─────────────────────────────────────────────────────────────
List<_Formula> _buildFormulas() {
  const formulas = [
    'E = mc²', 'F = ma', 'V = IR', 'a² + b² = c²', '(x+y)² = x²+2xy+y²',
    '∫ f(x) dx', 'd/dx(x²) = 2x', 'lim sinx/x = 1', 'sin²θ + cos²θ = 1', 'tanθ = sinθ/cosθ',
    'π ≈ 3.14159', 'e^(iπ) + 1 = 0', 'λ = h/p', 'P = W/t', 'KE = ½mv²',
    '∇·E = ρ/ε₀', 'PV = nRT', 'ΔS ≥ 0', 'σ = F/A', 'T = 2π√(L/g)',
    'c = λf', 'Fg = Gm₁m₂/r²', 'Q = mcΔT', 'W = Fd·cosθ', 'n₁sinθ₁ = n₂sinθ₂',
    'v² = u² + 2as', 'E = hf', 'I = V/R', 'A = πr²', 'v = u + at',
  ];

  final rng = Random(7);
  final items = <_Formula>[];

  const cols = 6, rows = 5;
  int fi = 0;
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final baseX = c / cols;
      final baseY = r / rows;
      final jx = baseX + rng.nextDouble() * (1 / cols);
      final jy = baseY + rng.nextDouble() * (1 / rows);
      items.add(_Formula(
        text: formulas[fi % formulas.length],
        x: jx.clamp(0.01, 0.95),
        y: jy.clamp(0.01, 0.95),
        angle: (rng.nextDouble() - 0.5) * 0.8,
        opacity: 0.07 + rng.nextDouble() * 0.12,
        fontSize: 10 + rng.nextDouble() * 7,
        blurred: rng.nextBool() && rng.nextBool(),
      ));
      fi++;
    }
  }
  return items;
}

// ─────────────────────────────────────────────────────────────
//  LoginScreen
// ─────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // ✅ State variables for Shimmer
  Color? _shimmerColor; 
  String _shimmerKey = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  // ✅ FIXED: Bulletproof Shimmer Trigger
  void _triggerShimmer(Color color) {
    if (!mounted) return;
    setState(() {
      _shimmerColor = color;
      _shimmerKey = DateTime.now().millisecondsSinceEpoch.toString(); 
    });
    
    // Auto-remove the shimmer widget after it finishes animating
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _shimmerColor = null);
    });
  }

  void _handleLogin() async {
    FocusScope.of(context).unfocus();

    // 1. Initial Validation Check -> RED Shimmer if empty/wrong format
    if (!_formKey.currentState!.validate() || !_isValidEmail(_emailController.text.trim())) {
      _triggerShimmer(Colors.redAccent); // 🔴 Triggers Red Sweep
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ Please enter a valid email and password.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ));
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // 2. Show loading message
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('⏳ Verifying credentials...'),
      duration: Duration(seconds: 2),
    ));

    final authNotifier = ref.read(authProvider.notifier);
    bool success = await authNotifier.login(email, password);

    // 3. Handle Login Failure -> RED Shimmer
    if (!success && mounted) {
      _triggerShimmer(Colors.redAccent); // 🔴 Triggers Red Sweep
      
      final error = ref.read(authProvider).error ?? '';
      String userMsg = '❌ Login failed. Please check your credentials.';

      if (error.toLowerCase().contains('timeout') || error.toLowerCase().contains('connection')) {
        userMsg = '⏳ Server is waking up. Please press Login again.';
      } else if (error.contains('401') || error.contains('404')) {
        userMsg = '❌ Invalid email or password.';
      } else if (error.contains('500')) {
        userMsg = '🔴 Server error. Try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(userMsg),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ));
      return;
    }

    // 4. Handle Login Success -> SILVER Shimmer
    if (success && mounted) {
      _triggerShimmer(Colors.white); // ⚪ Triggers Silver/White Sweep
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Login Successful! Entering classroom...'),
        backgroundColor: Colors.green,
      ));
      
      // Delay navigation so the user can see the cool Silver Shimmer
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) context.go('/dashboard');
      });
    }
  }

  // ✅ FIXED: The Shimmer UI (Now with a solid base so it's actually visible!)
  Widget _buildShimmerOverlay(Color color, String keySuffix) {
    return IgnorePointer(
      key: ValueKey('shimmer_$keySuffix'),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        // MUST have an opacity tint, otherwise ShaderMask is invisible
        color: color.withOpacity(0.15), 
      )
      .animate()
      .fadeIn(duration: 100.ms)
      .shimmer(
        duration: 900.ms,
        color: color, // The bright sweeping line
        size: 3, // Thicker sweep
        angle: 45, // Diagonal sweep
      )
      .fadeOut(duration: 400.ms, delay: 800.ms),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.deepBlack,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _FuturisticBackground(),
          const _FormulaOverlay(),
          Column(
            children: [
              _AvatarBanner(isMobile: isMobile),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 18 : 24,
                      vertical: 24,
                    ),
                    child: _LoginCard(
                      formKey: _formKey,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      isLoading: authState.isLoading, 
                      onLogin: _handleLogin,
                      onRegister: () => context.push('/register'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // ✅ Shimmer Overlay at the very top of the stack
          if (_shimmerColor != null) 
            _buildShimmerOverlay(_shimmerColor!, _shimmerKey),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Formula overlay 
// ─────────────────────────────────────────────────────────────
class _FormulaOverlay extends StatefulWidget {
  const _FormulaOverlay();

  @override
  State<_FormulaOverlay> createState() => _FormulaOverlayState();
}

class _FormulaOverlayState extends State<_FormulaOverlay>
    with TickerProviderStateMixin {
  final _formulas = _buildFormulas();
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    final rng = Random(13);
    _ctrls = List.generate(_formulas.length, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 3500 + rng.nextInt(3000)),
      )..repeat(reverse: true);
    });
    _anims = List.generate(
      _formulas.length,
      (i) => Tween<double>(begin: -7, end: 7).animate(
        CurvedAnimation(parent: _ctrls[i], curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      return Stack(
        children: List.generate(_formulas.length, (i) {
          final f = _formulas[i];
          return AnimatedBuilder(
            animation: _anims[i],
            builder: (_, __) => Positioned(
              left: f.x * w,
              top: f.y * h + _anims[i].value,
              child: Transform.rotate(
                angle: f.angle,
                child: f.blurred
                    ? ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                        child: _formulaText(f),
                      )
                    : _formulaText(f),
              ),
            ),
          );
        }),
      );
    });
  }

  Widget _formulaText(_Formula f) => Text(
        f.text,
        style: TextStyle(
          color: Colors.white.withOpacity(f.opacity),
          fontSize: f.fontSize,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w500,
          letterSpacing: 0.6,
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Full-width seamless avatar banner 
// ─────────────────────────────────────────────────────────────
class _AvatarBanner extends StatelessWidget {
  final bool isMobile;
  const _AvatarBanner({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final avatarSize = isMobile ? 52.0 : 64.0;
    final barHeight  = avatarSize + 52.0; 

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: double.infinity,
          height: barHeight,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            border: Border(
              bottom: BorderSide(
                color: AppColors.visionBlue.withOpacity(0.15),
                width: 1,
              ),
            ),
          ),
          child: Stack(
            children: [
              _InfiniteScrollingAvatars(avatarSize: avatarSize),
              Positioned(
                left: 0, right: 0, bottom: 0,
                height: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.deepBlack.withOpacity(0.35),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}

class _InfiniteScrollingAvatars extends StatefulWidget {
  final double avatarSize;
  const _InfiniteScrollingAvatars({required this.avatarSize});

  @override
  State<_InfiniteScrollingAvatars> createState() => _InfiniteScrollingAvatarsState();
}

class _InfiniteScrollingAvatarsState extends State<_InfiniteScrollingAvatars> {
  final _scroll = ScrollController();
  late Timer _timer;

  static const _all = [
    {'name': 'Srinivasa Ramanujan', 'image': 'assets/figures/ramanujan.jpg'},
    {'name': 'K. Radhakrishnan',    'image': 'assets/figures/radhakrishnan.jpg'},
    {'name': 'Mylswamy Annadurai',  'image': 'assets/figures/annadurai.jpg'},
    {'name': 'Rabindranath Tagore', 'image': 'assets/figures/tagore.jpg'},
    {'name': 'Munshi Premchand',    'image': 'assets/figures/premchand.jpg'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      final cur = _scroll.offset;
      if (cur >= max) {
        _scroll.jumpTo(0);
      } else {
        _scroll.jumpTo(cur + 0.7);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemBuilder: (context, i) {
        final fig = _all[i % _all.length];
        return _AvatarItem(
          name: fig['name']!,
          image: fig['image']!,
          size: widget.avatarSize,
          floatOffset: (i % _all.length) * 360.0,
        );
      },
    );
  }
}

class _AvatarItem extends StatefulWidget {
  final String name;
  final String image;
  final double size;
  final double floatOffset;

  const _AvatarItem({
    required this.name,
    required this.image,
    required this.size,
    this.floatOffset = 0,
  });

  @override
  State<_AvatarItem> createState() => _AvatarItemState();
}

class _AvatarItemState extends State<_AvatarItem> with SingleTickerProviderStateMixin {
  bool _hovering = false;
  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit:  (_) => setState(() => _hovering = false),
      child: AnimatedBuilder(
        animation: _floatAnim,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, _floatAnim.value),
          child: child,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width:  _hovering ? widget.size * 1.1 : widget.size,
                height: _hovering ? widget.size * 1.1 : widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _hovering
                        ? AppColors.visionBlue.withOpacity(0.9)
                        : AppColors.visionBlue.withOpacity(0.28),
                    width: _hovering ? 2.5 : 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.visionBlue.withOpacity(_hovering ? 0.6 : 0.18),
                      blurRadius: _hovering ? 24 : 10,
                      spreadRadius: _hovering ? 4 : 1,
                    ),
                  ],
                  image: DecorationImage(
                    image: AssetImage(widget.image),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                widget.name,
                style: TextStyle(
                  color: Colors.white.withOpacity(_hovering ? 0.95 : 0.58),
                  fontSize: 9,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Centered Login Card
// ─────────────────────────────────────────────────────────────
class _LoginCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  const _LoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onLogin,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.fromLTRB(36, 36, 36, 32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.048),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.visionBlue.withOpacity(0.28),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.visionBlue.withOpacity(0.08),
                blurRadius: 48,
                spreadRadius: 2,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.psychology_outlined,
                        size: 38, color: AppColors.visionBlue)
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(begin: const Offset(0.7, 0.7)),

                const SizedBox(height: 14),

                Text(
                  'AI Classroom',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                ).animate().fadeIn(delay: 150.ms).slideY(begin: -0.12),

                const SizedBox(height: 6),

                Text(
                  'The future of learning is here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.42),
                    fontSize: 12.5,
                    letterSpacing: 0.5,
                  ),
                ).animate().fadeIn(delay: 270.ms),

                const SizedBox(height: 36),

                _FuturisticTextField(
                  controller: emailController,
                  label: 'Email Address',
                  icon: Icons.alternate_email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(v)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 380.ms).slideX(begin: -0.08),

                const SizedBox(height: 18),

                _FuturisticTextField(
                  controller: passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  onFieldSubmitted: (_) => isLoading ? null : onLogin(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ).animate().fadeIn(delay: 520.ms).slideX(begin: 0.08),

                const SizedBox(height: 32),

                _GlowButton(
                  onPressed: isLoading ? null : onLogin,
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Enter Classroom',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                ).animate().fadeIn(delay: 680.ms).scale(
                    begin: const Offset(0.93, 0.93),
                    duration: 350.ms,
                    curve: Curves.easeOut),

                const SizedBox(height: 20),

                Center(
                  child: TextButton(
                    onPressed: onRegister,
                    child: Text(
                      'Create an account →',
                      style: TextStyle(
                        color: AppColors.visionBlue.withOpacity(0.72),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 840.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Futuristic text field with focus glow & Eye Toggle
// ─────────────────────────────────────────────────────────────
class _FuturisticTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  const _FuturisticTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  State<_FuturisticTextField> createState() => _FuturisticTextFieldState();
}

class _FuturisticTextFieldState extends State<_FuturisticTextField> {
  bool _focused = false;
  late bool _obscureText; 

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: AppColors.visionBlue.withOpacity(0.25),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: TextFormField(
          controller: widget.controller,
          obscureText: _obscureText, 
          keyboardType: widget.keyboardType,
          onFieldSubmitted: widget.onFieldSubmitted,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(
              color: _focused ? AppColors.visionBlue : Colors.white.withOpacity(0.36),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              widget.icon,
              color: _focused ? AppColors.visionBlue : Colors.white.withOpacity(0.36),
              size: 20,
            ),
            suffixIcon: widget.isPassword 
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    color: _focused ? AppColors.visionBlue : Colors.white.withOpacity(0.36),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                )
              : null,
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.visionBlue, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1.8),
            ),
          ),
          validator: widget.validator,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Gradient glow button
// ─────────────────────────────────────────────────────────────
class _GlowButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const _GlowButton({required this.onPressed, required this.child});

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return MouseRegion(
      onEnter: (_) {
        if (!disabled) setState(() => _hovering = true);
      },
      onExit: (_) {
        if (!disabled) setState(() => _hovering = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _hovering && !disabled
            ? (Matrix4.identity()..scale(1.025))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: disabled 
                ? [Colors.grey.shade800, Colors.grey.shade900]
                : [AppColors.visionBlue, AppColors.neonPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            if (!disabled)
              BoxShadow(
                color: AppColors.visionBlue.withOpacity(_hovering ? 0.7 : 0.4),
                blurRadius: _hovering ? 30 : 14,
                spreadRadius: _hovering ? 3 : 0,
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _FuturisticBackground extends StatelessWidget {
  const _FuturisticBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.futuristicGradient),
      child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.055)
      ..strokeWidth = 0.6;

    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
