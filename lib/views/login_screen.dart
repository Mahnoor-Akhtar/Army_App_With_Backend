import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'splash_screen.dart'; // Import to reuse TopographicPainter
import '../viewmodels/login_viewmodel.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _obscurePassword = true;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final loginVM = context.read<LoginViewModel>();
    final error = await loginVM.login(username, password);

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    widget.onLoginSuccess();
  }


  bool get _forcedDarkTheme => true;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = _forcedDarkTheme; // Force dark theme on login screen as requested by user

    // Theme-specific colors
    final bgColor = isDark ? const Color(0xFF03140A) : const Color(0xFFE8F5EE);
    final spotlightColor = isDark ? const Color(0xFF0C5A32).withValues(alpha: 0.35) : const Color(0xFF0C5A32).withValues(alpha: 0.08);
    final textThemeColor = isDark ? Colors.white : const Color(0xFF042011);
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF0C5A32).withValues(alpha: 0.85);
    final goldSeparator = isDark ? const Color(0xFFFFD700) : const Color(0xFF9E7715);
    final footerColor = isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF0C5A32).withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. Dynamic Topographic background
          CustomPaint(
            size: Size(size.width, size.height),
            painter: TopographicPainter(
              animationValue: 0.25,
            ),
          ),

          // 2. Spotlight gradient from top center
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.4,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [
                    spotlightColor,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),



          // 4. Main Form
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Column(
                  children: [
                    const SizedBox(height: 25),
                    // "117 SP REGT." header
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: isDark
                            ? [
                                const Color(0xFFFFF2C2),
                                const Color(0xFFE9C54F),
                                const Color(0xFFFFFFFF),
                              ]
                            : [
                                const Color(0xFF04381C),
                                const Color(0xFF0C5A32),
                                const Color(0xFF04381C),
                              ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(bounds),
                      child: Text(
                        '117 SP REGT.',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: textThemeColor,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Gold/Bronze separator line
                    Container(
                      width: double.infinity,
                      height: 1.2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            goldSeparator,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            // Circular Army Crest Emblem with glow
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? const Color(0xFF00FF66).withValues(alpha: 0.12)
                                        : const Color(0xFF0C5A32).withValues(alpha: 0.08),
                                    blurRadius: 35,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/army_crest.jpeg',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.shield,
                                      color: Color(0xFFD4AF37),
                                      size: 80,
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),

                            // "ZARB-UL-HADEED" Gold Title
                            SizedBox(
                              width: double.infinity,
                              child: ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [
                                    Color(0xFFFFF2C2),
                                    Color(0xFFD4AF37),
                                    Color(0xFF8A640F),
                                    Color(0xFFFFF2C2),
                                  ],
                                  stops: [0.0, 0.35, 0.75, 1.0],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ).createShader(bounds),
                                child: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'ZARB-UL-HADEED',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 2.0,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Subtitle
                            Text(
                              'Regt Parade State',
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 14,
                                letterSpacing: 0.5,
                                fontWeight: isDark ? FontWeight.normal : FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 25),

                            // Separator line
                            Container(
                              width: double.infinity,
                              height: 1.2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    goldSeparator,
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 35),

                            // Form Inputs
                            GlowingTextField(
                              hintText: 'Username/Email',
                              prefixIcon: Icons.person_outline,
                              isDarkMode: isDark,
                              controller: _usernameController,
                            ),
                            const SizedBox(height: 20),
                            GlowingTextField(
                              hintText: 'Password',
                              prefixIcon: Icons.lock_outline,
                              isObscure: _obscurePassword,
                              isDarkMode: isDark,
                              controller: _passwordController,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF0C5A32).withValues(alpha: 0.6),
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 35),

                            // Login Button
                            Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [
                                          const Color(0xFF0A5832),
                                          const Color(0xFF053E21),
                                        ]
                                      : [
                                          const Color(0xFF0C5A32),
                                          const Color(0xFF084123),
                                        ],
                                ),
                                border: Border.all(
                                  color: (isDark ? const Color(0xFFD4AF37) : const Color(0xFFB58A1B)).withValues(alpha: 0.8),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _handleLogin,
                                child: const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    color: Color(0xFFFFF0B3),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),

                    // Footer
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Column(
                        children: [
                          Text(
                            'Version 1.0',
                            style: TextStyle(
                              color: footerColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Powered by Supabase',
                            style: TextStyle(
                              color: footerColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Glowing Input Field Widget
class GlowingTextField extends StatefulWidget {
  final String hintText;
  final IconData prefixIcon;
  final bool isObscure;
  final Widget? suffixIcon;
  final bool isDarkMode;
  final TextEditingController? controller;

  const GlowingTextField({
    super.key,
    required this.hintText,
    required this.prefixIcon,
    required this.isDarkMode,
    this.isObscure = false,
    this.suffixIcon,
    this.controller,
  });

  @override
  State<GlowingTextField> createState() => _GlowingTextFieldState();
}

class _GlowingTextFieldState extends State<GlowingTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    // Theme values
    final inputColor = isDark ? Colors.white : const Color(0xFF042011);
    final hintColor = isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF0C5A32).withValues(alpha: 0.45);
    final fillColor = isDark ? const Color(0xFF0A2214).withValues(alpha: 0.7) : Colors.white;
    final enabledBorderColor = isDark ? const Color(0xFF00FF66).withValues(alpha: 0.25) : const Color(0xFF0C5A32).withValues(alpha: 0.35);
    final focusedBorderColor = isDark ? const Color(0xFF00FF66) : const Color(0xFF0C5A32);
    final glowColor = isDark ? const Color(0xFF00FF66).withValues(alpha: 0.18) : const Color(0xFF0C5A32).withValues(alpha: 0.18);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.isObscure,
        style: TextStyle(color: inputColor, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(widget.prefixIcon, color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF0C5A32).withValues(alpha: 0.65), size: 20),
          suffixIcon: widget.suffixIcon,
          hintText: widget.hintText,
          hintStyle: TextStyle(color: hintColor, fontSize: 15),
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: enabledBorderColor,
              width: 1.0,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: focusedBorderColor,
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
