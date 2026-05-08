import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../theme/app_theme.dart';
import '../services/theme_provider.dart';
import '../services/api_service.dart';
import '../services/user_provider.dart';
import '../services/history_provider.dart';
import 'recipe_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? autoPrompt;
  const ChatScreen({super.key, this.autoPrompt});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  // Voice
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  late AnimationController _micPulseController;

  @override
  void initState() {
    super.initState();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _messages.add(const _ChatMessage(
      text: "Namaste! 👋 I'm SnapDiet AI.\n\nYou can:\n- **Ask nutrition questions**\n- **Say what you ate** (e.g. 'I just had two boiled eggs and toast')\n- **Request a recipe** (e.g. 'Give me a recipe using chicken and spinach')",
      isAi: true,
    ));

    _initSpeech();

    // Auto-send prompt if navigated from the advice sheet
    if (widget.autoPrompt != null && widget.autoPrompt!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.text = widget.autoPrompt!;
        _handleSend();
      });
    }
  }

  Future<void> _initSpeech() async {
    try {
      if (kIsWeb) {
        // speech_to_text works on Chrome via browser WebSpeech API
        _speechAvailable = await _speech.initialize(
          onError: (val) => debugPrint('Speech Error: $val'),
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') _stopListening();
          },
        ).timeout(const Duration(seconds: 2), onTimeout: () => false);
      } else {
        _speechAvailable = await _speech.initialize(
          onError: (_) => _stopListening(),
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') _stopListening();
          },
        );
      }
    } catch (e) {
      debugPrint("Speech initialization failed: $e");
      _speechAvailable = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) return;
    setState(() => _isListening = true);
    _micPulseController.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
          _stopListening();
        } else {
          _controller.text = result.recognizedWords;
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_IN',         // supports Indian accents
    );
  }

  void _stopListening() {
    _speech.stop();
    _micPulseController.stop();
    if (mounted) setState(() => _isListening = false);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isAi: false));
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final historyProvider = Provider.of<HistoryProvider>(context, listen: false);

      final response = await apiService.sendChatMessage(
        message: text,
        profile: {'name': userProvider.name, 'rank': userProvider.rank},
        history: historyProvider.history
            .map((e) => {'calories': e.calories, 'protein': e.protein, 'name': e.foodName})
            .toList(),
        goals: {
          'daily_calories': userProvider.calorieGoal,
          'protein_target': userProvider.proteinGoal,
        },
      );

      final recipes = (response['recipes'] as List<dynamic>?) ?? [];
      final loggedFoods = (response['logged_foods'] as List<dynamic>?) ?? [];

      setState(() {
        _messages.add(_ChatMessage(
          text: response['reply'] ?? '',
          isAi: true,
          suggestions: (response['recommendations'] as List<dynamic>?) ?? [],
          recipes: recipes,
          loggedFoods: loggedFoods,
        ));
        _isLoading = false;
      });
      _scrollToBottom();

      // If a recipe was returned, auto-open the recipe screen
      if (recipes.isNotEmpty && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecipeScreen(
                recipes: recipes,
                summary: response['reply'] ?? '',
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: "I'm having trouble connecting right now. Please try again later!",
          isAi: true,
        ));
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _micPulseController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg     = isDark ? AppTheme.darkBg      : AppTheme.lightBg;
    final surf   = isDark ? AppTheme.darkSurface  : AppTheme.lightSurface;
    final surf2  = isDark ? AppTheme.darkSurface2 : AppTheme.lightSurface2;
    final border = isDark ? AppTheme.darkBorder   : AppTheme.lightBorder;
    final accent = isDark ? AppTheme.primaryColor : AppTheme.primaryDark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted   = isDark ? AppTheme.darkTextMuted   : AppTheme.lightTextMuted;

    try {
      return Material(
        color: bg,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(surf, border, textPrimary, textMuted),
              Expanded(
                child: _messages.isEmpty 
                  ? Center(child: Text("Initializing chat...", style: TextStyle(color: textMuted)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: _messages.length,
                      itemBuilder: (ctx, i) => _buildMessage(_messages[i], ctx, surf, border, accent, textPrimary, textMuted),
                    ),
              ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('AI is thinking...', style: TextStyle(color: textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              _buildInputArea(surf, surf2, border, accent, textPrimary, textMuted),
            ],
          ),
        ),
      );
    } catch (e, stack) {
      debugPrint("ERROR rendering ChatScreen: $e\n$stack");
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "Something went wrong loading the chat interface. Error: $e",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildHeader(Color surf, Color border, Color textPrimary, Color textMuted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: surf,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SnapDiet AI',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('Online',
                      style: TextStyle(fontSize: 12, color: textMuted)),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Recipe quick action
          IconButton(
            icon: Icon(Icons.restaurant_menu_rounded, color: textMuted, size: 22),
            tooltip: 'Ask for a recipe',
            onPressed: () {
              _controller.text = 'Give me a healthy recipe with chicken and vegetables';
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(_ChatMessage msg, BuildContext context, Color surf, Color border, Color accent, Color textPrimary, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: msg.isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          // Bubble
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: msg.isAi
                  ? surf
                  : accent.withOpacity(0.2),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(msg.isAi ? 0 : 20),
                bottomRight: Radius.circular(msg.isAi ? 20 : 0),
              ),
              border: Border.all(
                color: msg.isAi
                    ? border
                    : accent.withOpacity(0.4),
              ),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                color: textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),

          // Logged foods confirmation
          if (msg.loggedFoods != null && msg.loggedFoods!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildLoggedFoodsChips(msg.loggedFoods!),
          ],

          // Recipes button
          if (msg.recipes != null && msg.recipes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecipeScreen(
                    recipes: msg.recipes!,
                    summary: msg.text,
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'View ${msg.recipes!.length} Recipe${msg.recipes!.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Recommendation chips
          if (msg.suggestions != null && msg.suggestions!.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 88,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: msg.suggestions!.length,
                itemBuilder: (ctx, idx) {
                  final rec = msg.suggestions![idx];
                  return Container(
                    width: 190,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Text(rec['emoji'] ?? '🍲', style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(rec['name'] ?? '',
                                  style: TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Text(rec['reason'] ?? '',
                                  style: TextStyle(color: textMuted, fontSize: 10),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoggedFoodsChips(List<dynamic> foods) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: foods.map((f) {
        final name = f['name'] ?? 'Unknown';
        final qty = f['quantity'] ?? 1;
        final unit = f['unit'] ?? '';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  size: 12, color: Colors.greenAccent),
              const SizedBox(width: 5),
              Text(
                '$qty $unit $name'.trim(),
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputArea(Color surf, Color surf2, Color border, Color accent, Color textPrimary, Color textMuted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surf,
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          // Mic Button
          GestureDetector(
            onTap: _speechAvailable
                ? (_isListening ? _stopListening : _startListening)
                : null,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening
                    ? AppTheme.accentRed.withOpacity(0.15)
                    : surf2,
                border: Border.all(
                  color: _isListening
                      ? AppTheme.accentRed.withOpacity(0.6)
                      : border,
                ),
              ),
              child: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _isListening ? AppTheme.accentRed : textMuted,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Text Field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: surf2,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: border),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _inputFocusNode,
                style: TextStyle(color: textPrimary, fontSize: 14),
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                decoration: InputDecoration(
                  hintText: _isListening
                      ? 'Listening…'
                      : 'Ask about nutrition, recipes…',
                  hintStyle: TextStyle(
                    color: textMuted,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send Button
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isAi;
  final List<dynamic>? suggestions;
  final List<dynamic>? recipes;
  final List<dynamic>? loggedFoods;

  const _ChatMessage({
    required this.text,
    required this.isAi,
    this.suggestions,
    this.recipes,
    this.loggedFoods,
  });
}
